---
title: "Decouple cron scheduling from Telegram + autonomous service isolate AgentLoop"
type: architecture-refactor
date: 2026-02-17
tags: [cron, telegram, foreground-service, isolate, riverpod, decoupling]
files:
  - lib/providers/background_service_provider.dart (NEW)
  - lib/core/services/background_task_handler.dart (NEW - moved)
  - lib/core/agent/service_agent_factory.dart (NEW)
  - lib/providers/telegram_provider.dart (REWRITTEN)
  - lib/features/settings/cron_config_screen.dart (MODIFIED)
  - lib/data/local/storage_service.dart (MODIFIED)
  - lib/shared/constants.dart (MODIFIED)
---

# Decouple Cron Scheduling from Telegram + Autonomous Service Isolate

## Problem

Two independent features — **cron scheduling** and **Telegram bot** — were accidentally coupled through `TelegramNotifier`. The cron config screen had to import `telegram_provider.dart` just to call `ensureServiceRunning()`, and all cron execution logic (pending triggers, `_handleCronTrigger`, `_cacheSecretsForService`) lived inside the Telegram notifier.

Additionally, crons could only execute when the main app was alive. If Android killed the app overnight, cron triggers were queued but never executed until the user re-opened the app.

## Solution

### 1. Architectural decoupling: BackgroundServiceNotifier

Extracted a new `BackgroundServiceNotifier` that owns the foreground service lifecycle and cron execution:

```
Before:
  CronConfigScreen → TelegramNotifier.ensureServiceRunning()
  TelegramNotifier → service start, cron exec, secret caching, pending triggers

After:
  CronConfigScreen → BackgroundServiceNotifier.ensureServiceRunning()
  TelegramNotifier → only Telegram (enable/disable/messages)
  BackgroundServiceNotifier → service lifecycle, cron exec, secret caching
```

**BackgroundServiceNotifier** (`lib/providers/background_service_provider.dart`) owns:
- `ensureServiceRunning()` — start/reload the foreground service
- `stopServiceIfIdle()` — stop only when neither Telegram nor crons need it
- `_cacheSecretsForService()` — cache API keys in SharedPreferences for service isolate
- `_processPendingCronTriggers()` — replay queued triggers from when app was dead
- `_handleCronTrigger()` — execute cron via main isolate's AgentLoop
- `_onReceiveTaskData()` — handles `cron_trigger`, `cron_completed`, `started`, `stopped`

**TelegramNotifier** (`lib/providers/telegram_provider.dart`) was stripped to:
- `enable()` / `disable()` — delegates service start/stop to `BackgroundServiceNotifier`
- `_onReceiveTaskData()` — only handles `message`, `error`, `send_error`
- Zero cron code

### 2. Autonomous cron execution in service isolate

The service isolate (`BackgroundTaskHandler`) now initializes its own `AgentLoop` via `ServiceAgentFactory`, so crons execute at the exact scheduled time — even when Android kills the main app overnight.

**ServiceAgentFactory** (`lib/core/agent/service_agent_factory.dart`):
- Creates a fully-initialized AgentLoop from plain Dart types (no Flutter engine)
- Initializes Hive (plain `Hive.init()`, not `Hive.initFlutter()`)
- Creates LLMProvider via ProviderFactory
- Registers service-safe tools only: `web_search`, `web_scrape`, `file`
- Excludes platform-channel tools: `web_scrape_js` (WebView), `get_location` (GPS), `get_address` (geocoder), `subagent`, `message`

**Secret caching pattern**:
```
Main isolate                          Service isolate
FlutterSecureStorage                  SharedPreferences (read-only)
      │                                      ↑
      └── _cacheSecretsForService() ────────→│
          writes: cachedApiKey,              │
          cachedProviderName,                │
          cachedBraveApiKey,                 │
          cachedWorkspacePath         ServiceAgentFactory reads these
```

**Execution priority**:
1. Service isolate has AgentLoop → execute locally (autonomous)
2. AgentLoop unavailable or busy → queue in SharedPreferences + `sendDataToMain()` + `launchApp()`
3. Main isolate processes pending queue on next open

### 3. Renamed and relocated BackgroundTaskHandler

- `TelegramTaskHandler` → `BackgroundTaskHandler` (handles both Telegram + crons)
- `telegramServiceCallback` → `backgroundServiceCallback`
- Moved from `lib/features/telegram/` to `lib/core/services/`

### 4. Dual callback registration

Both notifiers register their own `addTaskDataCallback` and ignore irrelevant messages:
- `BackgroundServiceNotifier`: `cron_trigger`, `cron_completed`, `started`, `stopped`, `stop_requested`
- `TelegramNotifier`: `message`, `error`, `send_error`

## Key Constraints

### Service isolate limitations (no Flutter engine)
- No `FlutterSecureStorage` (platform channel) → must cache secrets in `SharedPreferences`
- No `rootBundle` (Flutter assets) → builtin skills not available
- No `getApplicationDocumentsDirectory()` → workspace path pre-resolved, passed via `StorageService.overrideWorkspacePath`
- No `WebView` → `WebScrapeJsTool` excluded
- No `geolocator` → `LocationTool`, `ReverseGeocodeTool` excluded
- Hive path derived as `workspacePath.parent.path + '/app_flutter'` to match `Hive.initFlutter()`

### Foreground service type
- Uses `remoteMessaging` (not `dataSync`) — no 6-hour time limit on Android 15+
- Notification channel: `droidclaw_background_service`

## Verification

- `cron_config_screen.dart` no longer imports `telegram_provider.dart`
- `TelegramNotifier` has zero cron-related code
- Crons work with Telegram disabled (service starts independently)
- Telegram works without crons (service starts independently)
- Both together — shared service, stops only when neither needs it
- `flutter analyze` passes with 0 issues
- APK builds and installs

## Commits

- `d7a51ed` — feat: autonomous cron execution + decouple cron from Telegram
- `9f2e898` — docs: update README with decoupled architecture and autonomous cron
