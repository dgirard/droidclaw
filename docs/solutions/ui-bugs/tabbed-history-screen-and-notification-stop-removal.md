---
title: "Tabbed history screen, manual cron trigger, and notification stop removal"
date: 2026-03-09
category: ui-bugs
tags:
  - history-screen
  - tabs
  - cron
  - run-now
  - async
  - foreground-service
  - notification
  - ux
  - i18n
  - code-review
severity: medium
components:
  - lib/features/chat/history_screen.dart
  - lib/features/settings/cron_config_screen.dart
  - lib/providers/background_service_provider.dart
  - lib/core/services/background_task_handler.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_fr.arb
  - lib/l10n/app_es.arb
  - lib/l10n/app_de.arb
  - lib/l10n/app_it.arb
---

# Tabbed History Screen, Manual Cron Trigger, and Notification Stop Removal

## Problem

Three UX issues in conversation history and cron management:

1. **Cluttered history list**: Chat, Telegram, and cron sessions mixed in a single `ListView`. Scheduled task executions buried below conversations were hard to find.

2. **No manual cron trigger**: To test a cron prompt, you had to wait for the next scheduled execution or copy-paste the prompt into chat.

3. **Dangerous notification button**: The foreground service notification had a "Stop" button that could silently kill all crons and Telegram polling. Android notifications cannot show confirmation dialogs.

## Solution 1: Tabbed History Screen

Converted `HistoryScreen` from a flat list to `DefaultTabController` with 2 tabs.

### Widget Tree

```dart
DefaultTabController(
  length: 2,
  child: Scaffold(
    appBar: AppBar(
      title: Text(l.historyTitle),
      bottom: TabBar(
        tabs: [
          Tab(text: l.historyTabConversations),
          Tab(text: l.historyTabScheduled),
        ],
      ),
    ),
    body: sessionManagerAsync.when(
      data: (sm) => TabBarView(
        children: [
          _buildConversationsTab(...),  // chat + telegram with section headers
          _buildScheduledTab(...),      // cron groups with drill-down
        ],
      ),
      // CRITICAL: loading/error must provide 2 children for TabBarView
      loading: () => TabBarView(children: [spinner, spinner]),
      error: (e, _) => TabBarView(children: [error, error]),
    ),
  ),
);
```

### Key Decisions

- **ConsumerWidget, not ConsumerStatefulWidget**: `DefaultTabController` manages tab state internally. Flutter widget reconciliation preserves its `State` across Riverpod rebuilds.
- **Loading/error inside TabBarView**: If `TabBar` is in `AppBar.bottom` but body returns a plain widget (not `TabBarView`), tabs are visible but non-functional.
- **Per-tab empty states**: Parameterized `_buildEmptyState(icon, message)` for each tab.
- **Dead `historySectionCron` key removed**: No longer needed since cron sessions have their own tab.

## Solution 2: Manual Cron Trigger (Run Now)

Added play buttons on cron tiles in both `CronConfigScreen` and the `HistoryScreen` scheduled tab.

### Shared Function

```dart
/// Start a new chat session with the given prompt and navigate to chat.
/// Shared by CronConfigScreen and HistoryScreen "Run Now" buttons.
Future<void> runCronNow(
    BuildContext context, WidgetRef ref, String prompt) async {
  final navigator = Navigator.of(context);  // capture BEFORE await
  final chatNotifier = ref.read(chatProvider.notifier);
  await chatNotifier.newSession();           // MUST await
  chatNotifier.sendMessage(prompt);
  navigator.pushNamedAndRemoveUntil('/chat', (route) => false);
}
```

### Critical Bug: Async Race Condition

**Symptom**: Tapping "Run Now" opened a new chat session, but the response had nothing to do with the cron prompt.

**Root cause**: `newSession()` returns `Future<void>` but was called without `await`. `sendMessage()` fired before the session switch completed, sending the prompt to the *old* session. The new session opened empty.

**Fix**: `await chatNotifier.newSession()` — plus capture `Navigator.of(context)` before the `await` to avoid `use_build_context_synchronously` lint.

**Lesson**: Any async method that mutates shared state must be awaited before acting on the new state. Ask: "If this takes 500ms, does the next line still work?"

### Design Choices

- Manual cron runs create regular chat sessions (no `cron_` prefix) — they appear in Conversations tab, not Scheduled Tasks. This is intentional: the user triggered them interactively.
- `pushNamedAndRemoveUntil('/chat', (route) => false)` clears the navigation stack. Back button goes to home, not settings.

## Solution 3: Notification Stop Button Removal

```dart
// notificationButtons emptied — service managed from app UI only
notificationButtons: [],
```

Removed dead code:
- `_stopAll()` method in `BackgroundServiceNotifier`
- `stop_requested` case in `_onReceiveTaskData()`
- `btn_stop` handler body in `BackgroundTaskHandler.onNotificationButtonPressed()` (override kept — required by `TaskHandler` interface)

## Code Review Fixes

### P2: Consolidated `_CronGroup` with Prompt

`getCronDefinitions()` was called twice per build in `history_screen.dart` — once in `_groupCronSessions()` for names and once to build a separate `cronPromptMap` for Run Now buttons.

**Fix**: Added `prompt` field to `_CronGroup`, populated during grouping:

```dart
class _CronGroup {
  final String name;
  final String? prompt;  // added — eliminates second getCronDefinitions() call
  final List<Session> sessions;
}
```

### P3: Extracted Shared `runCronNow`

Both `CronConfigScreen` (ConsumerStatefulWidget) and `HistoryScreen` (ConsumerWidget) had identical 5-line `_runCronNow` methods with different signatures due to widget type differences.

**Fix**: Extracted to a public top-level function in `history_screen.dart` that takes `WidgetRef` explicitly. Both screens import and call it.

## Prevention Strategies

### Async Race Conditions
- Enable `unawaited_futures` lint to catch unawaited `Future`-returning calls
- Capture `Navigator`/`ScaffoldMessenger` references before `await` in widget methods
- Sequential dependency test: "If A takes 500ms, does B still work?"

### Redundant Provider Reads
- "Fetch once at the top" rule: read each provider once in `build()`, pass to helpers
- Data classes for aggregated views: let `_CronGroup` carry everything the UI needs

### Notification Actions
- Never put destructive actions as notification buttons — no confirmation dialog possible
- Limit notification buttons to safe, reversible actions (pause/resume, mute)

### Code Duplication
- Duplicate once → extract immediately. Don't wait for a third occurrence.
- `WidgetRef` as parameter bridges `ConsumerWidget` vs `ConsumerStatefulWidget` differences

## i18n Keys Added (5 locales)

| Key | EN | FR |
|---|---|---|
| `historyTabConversations` | Conversations | Conversations |
| `historyTabScheduled` | Scheduled Tasks | Tâches planifiées |
| `historyEmptyScheduled` | No scheduled tasks yet | Aucune tâche planifiée |
| `cronRunNow` | Run now | Lancer maintenant |

## Related Documentation

- [`docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md`](../architecture/cron-sessions-hive-path-mismatch-between-isolates.md) — Cross-isolate session sync
- [`docs/solutions/architecture/decouple-cron-from-telegram-autonomous-service.md`](../architecture/decouple-cron-from-telegram-autonomous-service.md) — Dual-isolate service architecture
- [`docs/solutions/architecture/implement-i18n-with-dual-isolate-support.md`](../architecture/implement-i18n-with-dual-isolate-support.md) — i18n with dual isolate
- [`docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md`](../runtime-errors/cron-triggers-lost-when-main-isolate-dead.md) — Pending trigger queue
- [`docs/plans/2026-03-09-feat-tabbed-history-screen-plan.md`](../../plans/2026-03-09-feat-tabbed-history-screen-plan.md) — Tabbed history plan
- [`docs/plans/2026-03-09-feat-manual-cron-trigger-interactive-plan.md`](../../plans/2026-03-09-feat-manual-cron-trigger-interactive-plan.md) — Run Now plan
