---
title: "fix: Cron sessions not visible in Conversations screen"
type: fix
date: 2026-02-22
---

# fix: Cron sessions not visible in Conversations screen

## Overview

Cron executions complete successfully in the service isolate (confirmed by logs), but their sessions never appear in the Conversations/history screen. The screen shows only "Chat" sessions — the "Cron" section is missing entirely.

## Root Cause

The service isolate and the main isolate each have **their own `SessionManager` instance** with independent in-memory caches.

**Service isolate** (`ServiceAgentFactory.create()`):
```dart
Hive.init(hivePath);               // Opens Hive at shared path
final sessionManager = SessionManager();
await sessionManager.init();        // Loads from Hive → _cache
```

**Main isolate** (`sessionManagerProvider`):
```dart
final sessionManagerProvider = FutureProvider<SessionManager>((ref) async {
  final manager = SessionManager();
  await manager.init();  // Loads from Hive → _cache (once, at startup)
  return manager;
});
```

Both point to the same Hive files on disk. The service isolate saves cron sessions to Hive — the data is **on disk** but the main isolate's `SessionManager._cache` was populated at startup and **never reloads**. The `HistoryScreen` reads from `_cache`, so cron sessions are invisible.

## Fix

### Approach: Reload sessions from Hive on `cron_completed`

When the `BackgroundServiceNotifier` receives a `cron_completed` message, it should invalidate the `sessionManagerProvider` so it re-reads from Hive. This is the same approach we already use for `cronCompletionCount` — piggybacking on the same signal.

### File: `lib/core/session/session_manager.dart`

Add a `reload()` method that re-reads from the Hive box into the cache:

```dart
/// Reload sessions from Hive (picks up writes from other isolates).
Future<void> reload() async {
  if (_box == null) return;
  _cache.clear();
  for (final key in _box!.keys) {
    final raw = _box!.get(key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _cache[key as String] = Session.fromJson(json);
      } catch (_) {
        // Skip corrupted entries
      }
    }
  }
}
```

**Note:** Hive's `Box` uses a lazy file reader, but reads from an in-memory map after `openBox()`. To see writes from another isolate, we need to **close and re-open** the box, or use `box.get()` which reads from the in-memory backend. Since Hive is not designed for cross-isolate concurrent access, `_box.keys` and `_box.get()` will return stale data.

**Better approach:** Close the box and re-open it to force a disk re-read:

```dart
/// Reload sessions from Hive (picks up writes from other isolates).
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

### File: `lib/providers/background_service_provider.dart`

In `_reloadAfterCronCompletion()`, also reload the session manager:

```dart
Future<void> _reloadAfterCronCompletion() async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.reload();
  // Reload session manager to pick up cron sessions from service isolate
  final sm = await ref.read(sessionManagerProvider.future);
  await sm.reload();
  state = state.copyWith(
      cronCompletionCount: state.cronCompletionCount + 1);
}
```

### File: `lib/features/chat/history_screen.dart`

The `HistoryScreen` is a `ConsumerWidget` that already watches `sessionManagerProvider`. Since we're mutating the same `SessionManager` instance (not invalidating the provider), we need to trigger a rebuild. Two options:

**Option A:** Make `HistoryScreen` also listen to `backgroundServiceProvider.cronCompletionCount` to force rebuild.

**Option B:** Invalidate `sessionManagerProvider` instead of calling `sm.reload()`. This forces a fresh `FutureProvider` re-evaluation, which will re-init and rebuild all watchers.

**Option A is simpler** and doesn't disrupt the AgentLoop (which holds a reference to the session manager):

In `history_screen.dart`, add a watch on the background service state to trigger rebuilds:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final sessionManagerAsync = ref.watch(sessionManagerProvider);
  final currentSessionKey = ref.watch(chatProvider).sessionKey;
  // Rebuild when cron executions complete (sessions updated by service isolate)
  ref.watch(backgroundServiceProvider.select((s) => s.cronCompletionCount));
  // ...
```

## Files

| File | Change |
|------|--------|
| `lib/core/session/session_manager.dart` | Add `reload()` method (close + reopen Hive box + rebuild cache) |
| `lib/providers/background_service_provider.dart` | Call `sm.reload()` in `_reloadAfterCronCompletion()` |
| `lib/features/chat/history_screen.dart` | Watch `cronCompletionCount` to force rebuild after cron completion |

## Acceptance Criteria

- [ ] After a cron executes in the service isolate, the Conversations screen shows the cron session under the "Cron" section
- [ ] The session appears without requiring an app restart
- [ ] Existing chat sessions are unaffected
- [ ] `flutter analyze` passes with 0 issues

## Verification

1. Build and install APK
2. Set a cron to trigger in ~2 minutes
3. Open Conversations screen before trigger time
4. Wait for cron to fire
5. Verify "Cron" section appears with the execution
6. Also verify: kill app, let cron fire, reopen app → cron session visible
