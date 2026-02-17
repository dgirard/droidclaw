---
title: "refactor: Decouple cron scheduling from Telegram bot"
type: refactor
date: 2026-02-17
---

# Decouple Cron Scheduling from Telegram Bot

## Overview

The cron scheduler and Telegram bot are two independent features that are accidentally coupled through `TelegramNotifier` and `TelegramTaskHandler`. The cron config screen must import `telegram_provider.dart` just to call `ensureServiceRunning()`, and all cron execution logic lives inside the Telegram notifier.

This refactor separates them into:
- **`BackgroundServiceNotifier`** — owns the foreground service lifecycle, cron execution, and AgentLoop init
- **`TelegramNotifier`** — only manages the Telegram bot (enable/disable/messages), delegates service lifecycle to `BackgroundServiceNotifier`

## Current Coupling Points

| Where | What | Should belong to |
|-------|------|-----------------|
| `TelegramNotifier.ensureServiceRunning()` | Start/reload foreground service | BackgroundService |
| `TelegramNotifier._cacheSecretsForService()` | Cache API keys for service isolate | BackgroundService |
| `TelegramNotifier._processPendingCronTriggers()` | Replay queued cron triggers | BackgroundService |
| `TelegramNotifier._handleCronTrigger()` | Execute cron via AgentLoop | BackgroundService |
| `TelegramNotifier._removePendingTrigger()` | Queue management | BackgroundService |
| `TelegramNotifier._onReceiveTaskData()` cases `cron_trigger`/`cron_completed` | Route cron events | BackgroundService |
| `TelegramNotifier.enable()` → `FlutterForegroundTask.startService()` | Service start | BackgroundService (delegated) |
| `TelegramNotifier.disable()` → checks `hasActiveCrons` | Cross-concern stop logic | BackgroundService |
| `cron_config_screen.dart` → imports `telegram_provider.dart` | UI coupling | Should import BackgroundService |
| `telegramServiceCallback` name | Misleading name | Rename to `backgroundServiceCallback` |

## Implementation

### 1. Create BackgroundServiceNotifier

**NEW: `lib/providers/background_service_provider.dart`**

Owns the foreground service lifecycle and cron execution:

```dart
class BackgroundServiceState {
  final bool isRunning;
  final String? error;

  const BackgroundServiceState({
    this.isRunning = false,
    this.error,
  });
}

class BackgroundServiceNotifier extends Notifier<BackgroundServiceState> {
  @override
  BackgroundServiceState build() {
    ref.onDispose(() {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    });
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _checkInitialState();
    return const BackgroundServiceState();
  }

  // --- Moved from TelegramNotifier ---
  Future<void> ensureServiceRunning() async { ... }
  Future<void> stopServiceIfIdle() async { ... }
  Future<void> _cacheSecretsForService() async { ... }
  Future<void> _processPendingCronTriggers() async { ... }
  Future<void> _handleCronTrigger(Map<String, dynamic> data) async { ... }
  void _removePendingTrigger(String cronId) { ... }
}
```

- [x] Create `lib/providers/background_service_provider.dart`
- [x] Move service lifecycle methods from `TelegramNotifier`
- [x] Move cron execution methods from `TelegramNotifier`
- [x] Move `_cacheSecretsForService()` from `TelegramNotifier`
- [x] Add `stopServiceIfIdle()` — checks both Telegram enabled AND active crons before stopping
- [x] Register for `cron_trigger`, `cron_completed`, `cron_done` in `_onReceiveTaskData()`

### 2. Rename callback

**`lib/features/telegram/telegram_task_handler.dart`**:

The file stays in `telegram/` for now (it handles both concerns in the service isolate), but rename the entry point:

```dart
@pragma('vm:entry-point')
void backgroundServiceCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundTaskHandler());
}
```

Also rename `TelegramTaskHandler` → `BackgroundTaskHandler` since it handles both Telegram polling AND cron scheduling.

- [x] Rename `telegramServiceCallback` → `backgroundServiceCallback`
- [x] Rename `TelegramTaskHandler` → `BackgroundTaskHandler`
- [x] Move file from `lib/features/telegram/` to `lib/core/services/background_task_handler.dart`

### 3. Simplify TelegramNotifier

**`lib/providers/telegram_provider.dart`**:

Remove all cron/service lifecycle code. Delegate to `BackgroundServiceNotifier`:

```dart
class TelegramNotifier extends Notifier<TelegramState> {
  @override
  TelegramState build() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _checkInitialState();
    return const TelegramState();
  }

  Future<void> enable(String token) async {
    // ... validate token, save to storage ...
    // Delegate service start to BackgroundServiceNotifier
    final bgService = ref.read(backgroundServiceProvider.notifier);
    await bgService.ensureServiceRunning();
    await _initBotManager();
    // ...
  }

  Future<void> disable() async {
    // ... disable bot, dispose manager ...
    // Ask BackgroundService to stop if nothing else needs it
    final bgService = ref.read(backgroundServiceProvider.notifier);
    await bgService.stopServiceIfIdle();
    // ...
  }

  // _onReceiveTaskData only handles: message, started, stopped, error,
  //   stop_requested, send_error — NO cron cases
}
```

- [x] Remove `ensureServiceRunning()` (moved to BackgroundService)
- [x] Remove `_cacheSecretsForService()` (moved to BackgroundService)
- [x] Remove `_processPendingCronTriggers()` (moved to BackgroundService)
- [x] Remove `_handleCronTrigger()` (moved to BackgroundService)
- [x] Remove `_removePendingTrigger()` (moved to BackgroundService)
- [x] Remove `cron_trigger`/`cron_completed` from `_onReceiveTaskData()`
- [x] `enable()` delegates to `backgroundServiceProvider.notifier.ensureServiceRunning()`
- [x] `disable()` delegates to `backgroundServiceProvider.notifier.stopServiceIfIdle()`

### 4. Update cron config screen

**`lib/features/settings/cron_config_screen.dart`**:

Change the import and provider reference:

```dart
// Before:
import '../../providers/telegram_provider.dart';
final telegramNotifier = ref.read(telegramProvider.notifier);
await telegramNotifier.ensureServiceRunning();

// After:
import '../../providers/background_service_provider.dart';
final bgService = ref.read(backgroundServiceProvider.notifier);
await bgService.ensureServiceRunning();
```

- [x] Replace import `telegram_provider.dart` → `background_service_provider.dart`
- [x] Replace `telegramProvider.notifier` → `backgroundServiceProvider.notifier`

### 5. Handle dual callback registration

Both `BackgroundServiceNotifier` and `TelegramNotifier` need to receive data from the task handler via `FlutterForegroundTask.addTaskDataCallback()`. They each register their own callback and ignore irrelevant messages:

- `BackgroundServiceNotifier` handles: `cron_trigger`, `cron_completed`, `started`, `stopped`
- `TelegramNotifier` handles: `message`, `error`, `stop_requested`, `send_error`
- `started`/`stopped` may be handled by both (BackgroundService for state, Telegram for UI)

- [x] Verify `addTaskDataCallback` supports multiple listeners (it does — it's a list)
- [x] Each notifier ignores message types it doesn't handle

### 6. Update notification channel

In `BackgroundServiceNotifier.ensureServiceRunning()`:

```dart
channelId: 'droidclaw_background_service',
channelName: 'DroidClaw Background Service',
```

- [x] Update notification channel ID and name

## Acceptance Criteria

- [x] `cron_config_screen.dart` no longer imports `telegram_provider.dart`
- [x] `TelegramNotifier` has no cron-related code
- [x] Crons work with Telegram disabled (service starts independently)
- [x] Telegram works without crons (service starts independently)
- [x] Both together — service shared, stop only when neither needs it
- [x] `flutter analyze` passes
- [x] APK builds and installs

## Files Changed

| File | Change |
|------|--------|
| `lib/providers/background_service_provider.dart` | **NEW** — Service lifecycle + cron execution |
| `lib/core/services/background_task_handler.dart` | **MOVED** from `telegram_task_handler.dart`, renamed class |
| `lib/providers/telegram_provider.dart` | Remove cron/service code, delegate to BackgroundService |
| `lib/features/settings/cron_config_screen.dart` | Import BackgroundService instead of Telegram |
| `lib/providers/app_providers.dart` | No change (new provider is self-contained in its own file) |
| `lib/main.dart` | Update import if callback name changed |

## References

- `lib/providers/telegram_provider.dart` — current mixed provider
- `lib/features/settings/cron_config_screen.dart:47-48` — the coupling point
- `lib/features/telegram/telegram_task_handler.dart` — shared service handler
