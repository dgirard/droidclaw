---
title: "Cron triggers lost when main app isolate is killed by Android"
category: runtime-errors
severity: high
date: 2026-02-17
tech_stack:
  - Flutter
  - Dart
  - Android
  - flutter_foreground_task
  - SharedPreferences
root_cause: "sendDataToMain() silently fails when main isolate is dead"
solution_type: "Queue-based persistence + app wake-up"
files_modified:
  - lib/features/telegram/telegram_task_handler.dart
  - lib/providers/telegram_provider.dart
  - lib/shared/constants.dart
related_plans:
  - docs/plans/2026-02-16-feat-scheduled-prompts-cron-plan.md
  - docs/plans/2026-02-16-fix-cron-execution-bugs-plan.md
---

# Cron Triggers Lost When Main App Isolate Is Killed by Android

## Symptom

Scheduled prompts (crons) configured to run at 7:00 and 7:15 appeared to have executed (`lastRun` timestamps were updated) but produced no results — no conversation history, no responses visible in the app.

Logs at 8:28 showed:
```
[DroidClaw] Cron "Meteo": due=false, times=7:00, lastRun=2026-02-17 07:00:02
[DroidClaw] Cron "lemonde": due=false, times=7:15, lastRun=2026-02-17 07:15:06
```

But `[DroidClaw:Cron]` logs (from main isolate execution) were completely absent — meaning `_handleCronTrigger` in the main isolate was never called.

## Root Cause

DroidClaw uses a **dual-isolate architecture**:

```
Foreground Service Isolate          Main App Isolate
(TelegramTaskHandler)               (TelegramNotifier + AgentLoop)
        │                                    │
        │  sendDataToMain()                  │
        ├───────────────────────────────────>│  _handleCronTrigger()
        │                                    │  → AgentLoop.processMessage()
        │  sendDataToTask('cron_done')       │
        │<───────────────────────────────────┤
```

The foreground service isolate survives Android killing the app (it's a foreground service). But the main Flutter isolate (activity) is destroyed overnight to free memory.

**`FlutterForegroundTask.sendDataToMain()` silently fails when the main isolate is dead.** No error, no exception — the message simply vanishes.

The critical bug: `lastRun` was updated **before** execution, in the task handler isolate, to prevent re-triggering. This made the cron appear to have run successfully when it hadn't.

```
1. Cron detected as due      → lastRun updated immediately  ✓
2. sendDataToMain() called   → message lost (no recipient)  ✗
3. Main isolate never called → no AgentLoop execution       ✗
4. Next check sees lastRun   → skips cron (already "ran")   ✗
```

## Solution

Three-part fix: **queue before sending, wake the app, replay on startup**.

### 1. Task Handler: Queue + Wake (`telegram_task_handler.dart`)

When a cron is due, save the trigger to a durable queue in SharedPreferences **before** attempting inter-isolate communication:

```dart
if (due) {
  final triggerData = {
    'type': 'cron_trigger',
    'cron_id': cron.id,
    'cron_name': cron.name,
    'prompt': cron.prompt,
    'session_strategy': cron.sessionStrategy.name,
  };

  // 1. Save to persistent queue (safety net)
  _addPendingTrigger(prefs, triggerData);

  // 2. Try direct delivery (works if app is alive)
  FlutterForegroundTask.sendDataToMain(triggerData);

  // 3. Wake up main app to process the trigger
  FlutterForegroundTask.launchApp();

  // 4. Update lastRun (prevent re-triggering)
  _updateCronLastRun(cron.id, now, prefs);
}
```

Queue management: deduplicate by `cron_id`, remove on `cron_done`:

```dart
void _addPendingTrigger(SharedPreferences prefs, Map<String, dynamic> trigger) {
  final raw = prefs.getString(AppConstants.cronPendingTriggersKey);
  final List<dynamic> pending = raw != null ? (jsonDecode(raw) as List) : [];
  pending.removeWhere((t) => t['cron_id'] == trigger['cron_id']);
  pending.add(trigger);
  prefs.setString(AppConstants.cronPendingTriggersKey, jsonEncode(pending));
}
```

### 2. Main Isolate: Check Pending on Startup (`telegram_provider.dart`)

When the main isolate starts (app opened or woken by `launchApp()`), check for queued triggers:

```dart
Future<void> _checkInitialState() async {
  // ... existing Telegram init ...

  // Check for pending cron triggers queued while main isolate was dead
  await _processPendingCronTriggers();
}

Future<void> _processPendingCronTriggers() async {
  final storage = ref.read(storageServiceProvider);
  final raw = storage.getString(AppConstants.cronPendingTriggersKey);
  if (raw == null) return;

  final pending = jsonDecode(raw) as List;
  _cronLog('Found ${pending.length} pending cron trigger(s), executing...');

  for (final trigger in pending) {
    await _handleCronTrigger(Map<String, dynamic>.from(trigger as Map));
  }

  storage.remove(AppConstants.cronPendingTriggersKey);
}
```

### 3. Prevent Double Execution

When the app IS alive and receives `sendDataToMain` directly, remove from pending queue immediately:

```dart
case 'cron_trigger':
  _removePendingTrigger(map['cron_id'] as String);  // Already handling it
  _handleCronTrigger(map);
```

## Prevention Strategies

### Pattern: Never Trust Silent IPC

`sendDataToMain()` / `sendDataToTask()` in `flutter_foreground_task` are fire-and-forget. Always assume they can fail:

- **Queue critical actions** in SharedPreferences before sending
- **Confirm execution** by removing from queue only after completion
- **Check queue on startup** for any actions that were queued but never confirmed

### Pattern: Don't Mark "Done" Before It's Done

The original `lastRun` update happened in the task handler (trigger side), not after execution. Any "completion marker" should be set only after confirmed execution:

- In this case, `lastRun` must still be set early (to prevent re-triggering within the same minute), but the pending queue serves as the true execution tracker.

### Android Lifecycle Awareness

- Foreground services survive app kill, but main Flutter isolate does not
- `autoRunOnBoot: true` restarts the SERVICE, not the main app
- `FlutterForegroundTask.launchApp()` can restart the main activity from the service isolate

## Related Documentation

- `docs/plans/2026-02-16-feat-scheduled-prompts-cron-plan.md` — original cron architecture
- `docs/plans/2026-02-16-fix-cron-execution-bugs-plan.md` — previous cron fixes (UTC time, null API checks)
- `docs/plans/2026-02-16-fix-cron-execution-visibility-plan.md` — cron status UI
