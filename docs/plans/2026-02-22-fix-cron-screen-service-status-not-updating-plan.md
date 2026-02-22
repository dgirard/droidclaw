---
title: "fix: Cron screen shows 'Background service not running' even when service is running"
type: fix
date: 2026-02-22
---

# fix: Cron screen shows "Background service not running" even when service is running

## Overview

After adding a cron and enabling it, the Scheduled Prompts screen shows a red error banner "Background service not running" — but `adb logcat` proves the service IS running and checking crons normally. This is a UI state refresh bug.

## Problem Statement

**Screenshot**: The cron "Meteo" is enabled (toggle on), scheduled "Daily at 15:03", but the red banner says "Background service not running".

**Logcat**: `[DroidClaw] Checking 1 crons at 14:09` — service is running fine.

### Root Cause

`CronConfigScreen` maintains a **local `_serviceRunning` boolean** that is checked once in `initState()` via `_checkServiceStatus()` (an async call to `FlutterForegroundTask.isRunningService`). It never watches the Riverpod `backgroundServiceProvider` state.

The flow when adding a cron:

1. User taps FAB → navigates to `CronEditScreen`
2. User saves → `Navigator.pop(context, cron)`
3. Back in `CronConfigScreen`: `_saveCrons()` calls `bgService.ensureServiceRunning()`
4. `ensureServiceRunning()` starts the service and sets `state = state.copyWith(isRunning: true)` (line 126 of `background_service_provider.dart`)
5. **But `CronConfigScreen` never reads this Riverpod state update** — it uses its own stale local `_serviceRunning = false`

The screen is a `ConsumerStatefulWidget` and already uses `ref.read(backgroundServiceProvider.notifier)` — it just doesn't `ref.watch()` the state.

## Proposed Solution

Replace the local `_serviceRunning` boolean with `ref.watch(backgroundServiceProvider).isRunning` directly in the `build()` method. This makes the banner reactive: it updates automatically when the service starts or stops.

## Acceptance Criteria

- [x] Red banner disappears when the background service starts after adding/enabling a cron
- [x] Red banner appears when the service stops (disable all crons + disable Telegram)
- [x] No local `_serviceRunning` state variable
- [x] `_checkServiceStatus()` method removed (no longer needed)
- [x] `flutter analyze` passes with 0 issues

## MVP

### `lib/features/settings/cron_config_screen.dart`

Remove:
- `bool _serviceRunning = false;` field
- `_checkServiceStatus()` method
- `_checkServiceStatus()` call in `initState()`

In `build()`, replace local variable with Riverpod watch:
```dart
@override
Widget build(BuildContext context) {
  final l = AppLocalizations.of(context);
  final serviceRunning = ref.watch(backgroundServiceProvider).isRunning;
  // ... use serviceRunning instead of _serviceRunning
}
```

Update `_buildServiceStatus()` to accept the `bool` parameter or read it the same way.

## Files

| File | Change |
|------|--------|
| `lib/features/settings/cron_config_screen.dart` | Remove local `_serviceRunning`, watch `backgroundServiceProvider` instead |
