---
title: "fix: Cron execution bugs - UTC time, silent failures, missing reload"
type: fix
date: 2026-02-16
---

# Fix Cron Execution Bugs

## Bugs Found via Logs

### Bug 1: UTC vs local time (FIXED)
`onRepeatEvent(timestamp)` provides UTC time, but crons are configured in local time.
Fixed: use `DateTime.now()` instead.

### Bug 2: onReceiveData blocked by null API check (FIXED)
`if (_api == null) return;` at top of `onReceiveData` blocked ALL messages including
`reload_crons` and `cron_done` when Telegram wasn't configured.
Fixed: moved the null check inside the `send` action only.

### Bug 3: Silent failure in _handleCronTrigger
`catch (e) {}` swallows all errors. If the AgentLoop fails (e.g., no API key, network error),
the cron appears to have "run" (lastRun updated) but produced no result.
Fix: add logging to `_handleCronTrigger`.

### Bug 4: Cron check interval too slow for timeOfDay
The cron check runs every 60 seconds. For `timeOfDay` crons, `_isDue()` compares exact
`hour:minute`. If the check happens at 22:31:02 → matches. But if service starts at 22:31:30
and first check is at 22:32:30 → misses 22:31 entirely.
Fix: reduce check interval to 15 seconds for more reliable time-of-day matching.

## Acceptance Criteria

- [ ] Cron checks use local time (DateTime.now())
- [ ] onReceiveData processes cron actions even without Telegram
- [ ] _handleCronTrigger logs start, success, and errors
- [ ] Cron check interval reduced to 15s for better time-of-day accuracy
- [ ] Counter starts at interval-1 to check immediately on service start
- [ ] `flutter analyze` passes, APK builds and installs

## Files Changed

| File | Change |
|------|--------|
| `lib/features/telegram/telegram_task_handler.dart` | Reduce interval to 15s, logging |
| `lib/providers/telegram_provider.dart` | Add logging to _handleCronTrigger |
