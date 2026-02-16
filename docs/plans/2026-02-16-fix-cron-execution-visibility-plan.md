---
title: "fix: Improve cron execution visibility"
type: fix
date: 2026-02-16
---

# Improve Cron Execution Visibility

## Problem

After configuring a scheduled prompt, the user has no clear way to know:
1. Whether the cron has actually run
2. Where to find the execution results
3. Whether the background service is even running

The execution results exist in the history screen under "Scheduled Prompts", but that's not discoverable from the cron config screen.

## Proposed Solution

Three improvements to make cron execution status clear:

### 1. Better status display in cron config screen

In `cron_config_screen.dart`, improve the subtitle for each cron:
- If `lastRun == null`: show **"Never ran"** in a muted/warning style
- If `lastRun != null`: show **"Last run: Feb 16, 14:30"** (already exists but format could be clearer)
- Show a status chip: "Service running" or "Service stopped" at the top of the screen

### 2. "View executions" button on each cron

Add a way to jump directly from a cron config to its execution history:
- Add an `IconButton(Icons.history)` in the trailing row of each cron tile
- On tap: navigate to history screen filtered to that cron's sessions (reuse `_CronExecutionsScreen` from `history_screen.dart`)

### 3. Notification snackbar after cron execution

In `telegram_provider.dart` `_handleCronTrigger()`, after successful execution:
- Show an in-app notification via a simple state update that the UI can react to

## Acceptance Criteria

- [ ] Cron config screen shows "Never ran" when `lastRun` is null
- [ ] Cron config screen shows service running status at the top
- [ ] Each cron has a history button that opens its executions
- [ ] `_CronExecutionsScreen` is extracted to be reusable (or navigates to history with a filter)
- [ ] `flutter analyze` passes with 0 issues
- [ ] APK builds and installs

## Implementation

### `lib/features/settings/cron_config_screen.dart`

1. Add service status indicator at top of list (check `FlutterForegroundTask.isRunningService`)
2. Improve subtitle: show "Never ran" when lastRun is null
3. Add history `IconButton` in trailing row (between Switch and delete)
4. On tap history: load sessions matching `cron_{cronId}` prefix and navigate to executions screen

### `lib/features/chat/history_screen.dart`

1. Make `_CronExecutionsScreen` public (rename to `CronExecutionsScreen`) so it can be navigated to from cron config

### `lib/providers/telegram_provider.dart`

1. No changes needed — lastRun already persisted by task handler

### Files Changed

| File | Change |
|------|--------|
| `lib/features/settings/cron_config_screen.dart` | Service status, "Never ran", history button |
| `lib/features/chat/history_screen.dart` | Make CronExecutionsScreen public |

## References

- `lib/features/settings/cron_config_screen.dart:88-132` — cron list tiles
- `lib/features/chat/history_screen.dart:204-241` — _CronExecutionsScreen
- `lib/features/telegram/telegram_task_handler.dart` — cron execution + lastRun persistence
- `lib/providers/telegram_provider.dart:332-363` — _handleCronTrigger
