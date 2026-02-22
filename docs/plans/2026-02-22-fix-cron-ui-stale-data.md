---
title: "fix: Cron UI stale data — lastRun and sessions from service isolate"
type: fix
date: 2026-02-22
---

# fix: Cron UI stale data — lastRun and sessions from service isolate

## Overview

Two UI issues caused by the dual-isolate architecture:

1. **Scheduled Prompts screen** shows stale `lastRun` — service isolate updates SharedPreferences but main isolate's in-memory cache doesn't see the change
2. **History screen** doesn't show cron sessions — service isolate writes to Hive but main isolate's `SessionManager._cache` doesn't see them

## Root Cause Analysis

### Problem 1: Stale lastRun in CronConfigScreen

**Data flow**:
```
Service isolate: _updateCronLastRun() → prefs.setString(cronDefinitionsKey, ...)
                 ↓ (writes to disk)
Main isolate:    ConfigStorage.getCronDefinitions() → _storage.getString(cronDefinitionsKey)
                 ↓ (reads from SharedPreferences in-memory cache)
                 STALE — in-memory cache was populated at app startup
```

`SharedPreferences` caches all values in memory on first access. The service isolate writes to the same underlying XML file on disk, but the main isolate's `SharedPreferences` instance doesn't know about the change. Android's `SharedPreferences` DOES support cross-process reads if you call `reload()` first.

**Fix**: In `CronConfigScreen._loadCrons()`, call `prefs.reload()` before reading. Also reload when the screen receives a `cron_completed` notification.

### Problem 2: Cron sessions not visible in History

**Data flow**:
```
Service isolate: _agentLoop!.sessions.save(session) → Hive box write to disk
                 ↓ (writes to sessions.hive file)
Main isolate:    SessionManager.getAllSessions() → returns _cache.values
                 ↓ (_cache was populated at init() time)
                 STALE — _cache doesn't include sessions written after init()
```

Hive's `Box` has a `.keys` property that reads from its internal in-memory state. However, Hive boxes ARE backed by an append-only file. If we close and reopen the box, or read directly from the box (not the cache), we can pick up new entries.

**Fix**: Add a `refresh()` method to `SessionManager` that re-reads all keys from the Hive box into `_cache`. Call it when opening the History screen and after `cron_completed` notifications.

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/session/session_manager.dart` | Add `refresh()` method to reload from Hive box |
| `lib/features/settings/cron_config_screen.dart` | Reload SharedPreferences before reading crons; refresh on return from executions screen |
| `lib/providers/background_service_provider.dart` | On `cron_completed`, reload crons + refresh sessions |
| `lib/features/chat/history_screen.dart` | Trigger session refresh when screen opens |
| `lib/providers/app_providers.dart` | May need to expose a refresh mechanism for sessionManager |

## Implementation

### Step 1: SessionManager.refresh()

```dart
// lib/core/session/session_manager.dart
/// Re-read all sessions from the Hive box into cache.
/// Picks up sessions written by the service isolate.
Future<void> refresh() async {
  if (_box == null) return;
  // Close and reopen to pick up file changes from other isolate
  await _box!.close();
  _box = await Hive.openBox<String>(_boxName);
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

### Step 2: CronConfigScreen — reload SharedPreferences

```dart
// In _loadCrons(), reload prefs first:
Future<void> _loadCrons() async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.reload();  // Pick up service isolate changes
  final configStorage = ref.read(configStorageProvider);
  setState(() {
    _crons = configStorage.getCronDefinitions();
  });
}
```

Also call `_loadCrons()` when returning from the executions screen or when the screen becomes visible again.

### Step 3: BackgroundServiceNotifier — react to cron_completed

In `_onReceiveTaskData`, on `cron_completed`:
- Reload SharedPreferences (to get updated lastRun)
- Refresh SessionManager (to get new session)
- Force a state change so watchers (CronConfigScreen, HistoryScreen) rebuild

```dart
case 'cron_completed':
  AppLogger.instance.info(LogSource.cron, ...);
  // Refresh session cache to pick up service-written sessions
  _refreshAfterCronCompletion(map['cron_id'] as String?);
```

### Step 4: History screen — refresh sessions on open

In `HistoryScreen.build()`, trigger a session refresh. Since `sessionManagerProvider` is a `FutureProvider`, we need to add a refresh mechanism.

Option: Add a `sessionRefreshProvider` that the history screen can invalidate, or simply call `refresh()` on the SessionManager before displaying.

## Acceptance Criteria

- [ ] Scheduled Prompts screen shows accurate lastRun after cron executes
- [ ] History screen shows cron sessions written by the service isolate
- [ ] Both screens update when returning from sub-screens
- [ ] `flutter analyze` passes with 0 issues
- [ ] Build APK and verify on device
