---
title: "Fix: Cron Sessions Not Visible in Conversations Screen"
date: 2026-02-22
category: architecture
component: "Dual-Isolate Session Management (Hive + FlutterForegroundTask)"
severity: high
symptoms:
  - "Cron executes successfully (logs confirm) but sessions never appear in Conversations"
  - "CronConfigScreen shows 'Never ran' despite service isolate completing execution"
  - "HistoryScreen shows only Chat section, no Cron section"
tags:
  - cron-execution
  - service-isolate
  - hive-persistence
  - race-condition
  - dual-isolate-sync
  - cross-isolate-cache
related_files:
  - lib/core/services/background_task_handler.dart
  - lib/core/session/session_manager.dart
  - lib/core/agent/service_agent_factory.dart
  - lib/providers/background_service_provider.dart
  - lib/features/chat/history_screen.dart
  - lib/features/settings/cron_config_screen.dart
  - lib/main.dart
---

# Fix: Cron Sessions Not Visible in Conversations Screen

## Problem

Cron executions completed successfully in the service isolate (confirmed by `adb logcat`), but their sessions never appeared in the main app's Conversations screen. The `CronConfigScreen` also showed "Never ran" despite successful execution.

## Root Causes (Three Independent Bugs)

### Bug 1: Hive Path Mismatch (PRIMARY)

The service isolate derived its Hive path incorrectly, resulting in sessions written to a **different directory** than the main isolate reads from.

**Main isolate** (`main.dart`):
```dart
await Hive.initFlutter();
// getApplicationDocumentsDirectory() → /data/data/com.droidclaw.app/app_flutter
// Hive path = /data/data/com.droidclaw.app/app_flutter
```

**Service isolate** (`background_task_handler.dart`):
```dart
final appDir = Directory(workspacePath).parent.path;
// workspacePath = .../app_flutter/droidclaw_workspace
// appDir = .../app_flutter  (correct so far)
final hivePath = '$appDir/app_flutter';  // BUG: .../app_flutter/app_flutter
```

The comment said "Hive.initFlutter() uses `<appDir>/app_flutter`" but `getApplicationDocumentsDirectory()` already **returns** the `app_flutter` directory. The extra `/app_flutter` created a nested path.

### Bug 2: Race Condition — Notify Before Save

In `_executeCronLocally()`, `sendDataToMain('cron_completed')` was called **inside** the `await for` loop, **before** `sessions.save()` which happened after the loop:

```
1. ResponseEvent received
2. sendDataToMain('cron_completed')  ← main isolate receives this
3. break (exits loop)
4. sessions.save(session)            ← session not yet on disk!
```

Main isolate tried to reload Hive before the session was flushed to disk.

### Bug 3: No Session Reload Mechanism

`SessionManager._cache` was populated once at `init()` and never refreshed. Even with correct paths and timing, the main isolate's in-memory cache couldn't see service isolate writes without an explicit reload (close + reopen Hive box).

## Fixes

### Fix 1: Correct Hive Path

**File**: `lib/core/services/background_task_handler.dart`

```dart
// Before (WRONG — double-nested):
final appDir = Directory(workspacePath).parent.path;
final hivePath = '$appDir/app_flutter';

// After (CORRECT — appDir IS already app_flutter):
final appDir = Directory(workspacePath).parent.path;
final hivePath = appDir;
```

Same fix for `AppLogger.init()` in the same file and in `main.dart`.

### Fix 2: Save Before Notify

**File**: `lib/core/services/background_task_handler.dart`

Moved `sendDataToMain` to **after** `sessions.save()`:

```dart
// 1. Save session FIRST
final session = _agentLoop!.sessions.get(sessionKey);
if (session != null) {
  await _agentLoop!.sessions.save(session);
}

// 2. THEN notify main isolate
FlutterForegroundTask.sendDataToMain({
  'type': 'cron_completed',
  'cron_id': cron.id,
  'cron_name': cron.name,
  'response_length': responseLength,
});
```

### Fix 3: SessionManager.reload() + Reactive UI

**File**: `lib/core/session/session_manager.dart` — added `reload()`:

```dart
Future<void> reload() async {
  final boxName = _box?.name;
  if (boxName == null) return;
  await _box!.close();
  _box = await Hive.openBox<String>(boxName);
  _cache.clear();
  for (final key in _box!.keys) {
    final raw = _box!.get(key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _cache[key as String] = Session.fromJson(json);
      } catch (_) {}
    }
  }
}
```

**File**: `lib/providers/background_service_provider.dart` — added `cronCompletionCount` to state and reload handler:

```dart
Future<void> _reloadAfterCronCompletion() async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.reload();
  final sm = await ref.read(sessionManagerProvider.future);
  await sm.reload();
  state = state.copyWith(
      cronCompletionCount: state.cronCompletionCount + 1);
}
```

**File**: `lib/features/chat/history_screen.dart` — watches counter:

```dart
ref.watch(backgroundServiceProvider.select((s) => s.cronCompletionCount));
```

**File**: `lib/features/settings/cron_config_screen.dart` — listens for reload:

```dart
ref.listen(backgroundServiceProvider.select((s) => s.cronCompletionCount),
    (prev, next) => _loadCrons());
```

## Key Insight

All three bugs had to be fixed together. Fixing any one or two alone would not make sessions visible:

| Path correct? | Save-before-notify? | Reload mechanism? | Sessions visible? |
|:---:|:---:|:---:|:---:|
| No | - | - | Never |
| Yes | No | Yes | Race: sometimes |
| Yes | Yes | No | Never (stale cache) |
| Yes | Yes | Yes | **Always** |

## Prevention Rules

1. **Never nest `getApplicationDocumentsDirectory()`**: It already returns `app_flutter`. Don't add `/app_flutter` again.
2. **Save-then-notify**: Always `await save()` before `sendDataToMain()`. The receiver will try to read immediately.
3. **Explicit reload for cross-isolate Hive**: Hive boxes are NOT shared between Dart engines. Close + reopen to re-read from disk.
4. **Use Riverpod signals for cache invalidation**: Bump a counter in state, watch it in UI widgets — don't rely on manual refresh.

## Debugging Technique

The Hive path mismatch was found by adding debug logging to `SessionManager.reload()`:

```
[DroidClaw] SessionManager.reload: 3 sessions loaded, keys=[]
[DroidClaw] Session reload done: 3 total, 0 cron sessions
```

This showed reload worked but found 0 cron sessions — proving the data was in a different directory. After fixing the path:

```
[DroidClaw] SessionManager.reload: 4 sessions loaded, keys=[cron_fb19556a-...]
[DroidClaw] Session reload done: 4 total, 1 cron sessions
```

## Related Documentation

- [Decouple Cron from Telegram](decouple-cron-from-telegram-autonomous-service.md) — architecture that created the dual-isolate pattern
- [Enable Location Tools in Service Isolate](enable-location-tools-in-service-isolate.md) — service isolate runs on FlutterEngine, not plain isolate
- [i18n with Dual-Isolate Support](implement-i18n-with-dual-isolate-support.md) — SharedPreferences caching pattern for cross-isolate state
- [Cron Triggers Lost When Main Isolate Dead](../runtime-errors/cron-triggers-lost-when-main-isolate-dead.md) — pending queue for when main isolate is unavailable
