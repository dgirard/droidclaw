---
title: "Sessions disappearing from history after app restart"
category: database-issues
last_updated: 2026-06-10
tags: [hive, persistence, session-manager, data-integrity, app-lifecycle, flush, dual-isolate]
module: core/session
symptom: "Some conversation sessions vanish from the History screen after app restart, particularly those with heavy tool use or interrupted mid-conversation"
root_cause: "Four independent persistence bugs: Hive writes not flushed to disk, getMessages() destructively mutating _messages, summarization emptying sessions, no mid-iteration persistence in agent loop"
---

# Sessions Disappearing From History After App Restart

## Symptom

User reported intermittent session loss: "j'ai l'impression que des fois, je perds des threads de conversation." Sessions disappear from the History screen after app restart. Only some sessions affected — typically those with heavy tool use or those active when the app was killed.

## Root Cause Analysis

Four independent bugs conspired to lose session data:

### 1. Hive writes not flushed to disk

`SessionManager.save()` called `box.put()`, which writes to the OS page cache but does not issue `fsync`. When Android kills the process via SIGKILL (OOM, task swipe, battery optimization), unflushed pages are discarded. Sessions saved seconds before death vanish on next launch.

> **Correction (2026-06-10):** the SIGKILL claim overstates the exposure — an *awaited* `box.put()` survives process SIGKILL via kernel page-cache writeback; the actual unflushed-write exposure window is power loss / kernel panic. The flush layers below remain as defense-in-depth, and the cadence is now tiered: fsync on final response, app pause, deletes, and cross-isolate handoffs — NOT on mid-turn tool batches. See the flush-policy doc table in `lib/core/session/session_manager.dart` and `test/session/lazy_load_and_flush_policy_test.dart`.

### 2. `getMessages()` destructively mutating internal state

`Session.getMessages()` called `_stripOrphanedLeadingMessages()` directly on the `_messages` list. This method removed leading `tool` role messages that lacked a preceding `assistant` message with matching `toolCalls`. Because it mutated in-place, every call to `getMessages()` (which happens on every agent loop iteration) permanently destroyed those messages. Over a multi-tool conversation, content silently disappeared.

### 3. Summarization could empty sessions

`truncateHistory()` keeps the last N messages after inserting a summary. But if those last N messages are all tool results or assistant messages with `toolCalls` (no standalone user or assistant text), the session effectively becomes empty. The next agent loop iteration has no meaningful context.

### 4. No persistence between tool iterations

The agent loop only called `sessions.save()` after the final assistant response. If the process was killed mid-execution (between tool calls), all intermediate tool results accumulated during that turn were lost. Combined with bug #1, this created a wide window for data loss.

## Working Solution

### Fix 1: Flush after every write

```dart
// session_manager.dart
Future<void> save(Session session) async {
  _cache[session.key] = session;
  await _box?.put(session.key, jsonEncode(session.toJson()));
  await _box?.flush();  // fsync to disk
}

Future<void> deleteSession(String key) async {
  _cache.remove(key);
  await _box?.delete(key);
  await _box?.flush();
}

Future<void> flush() async {
  await _box?.flush();
}
```

### Fix 2: Strip orphans on a copy, not in-place

Changed `_stripOrphanedLeadingMessages()` from an instance method mutating `_messages` to a static function operating on a copy:

```dart
// session.dart
List<Message> getMessages() {
  _repairToolNames();
  final copy = List<Message>.of(_messages);
  _stripOrphanedLeading(copy);
  // ... return copy (with optional summary prepended)
}

static void _stripOrphanedLeading(List<Message> msgs) {
  while (msgs.isNotEmpty) {
    final first = msgs.first;
    if (first.role == 'tool') {
      msgs.removeAt(0);
    } else if (first.role == 'assistant' &&
        first.toolCalls != null && first.toolCalls!.isNotEmpty) {
      // Check if all toolCalls have matching results
      final tcIds = first.toolCalls!.map((tc) => tc.id).toSet();
      final hasAllResults = tcIds.every((id) =>
          msgs.any((m) => m.role == 'tool' && m.toolCallId == id));
      if (!hasAllResults) {
        msgs.removeAt(0);
      } else {
        break;
      }
    } else {
      break;
    }
  }
}
```

### Fix 3: Guard summarization against empty results

```dart
// session.dart
List<Message> truncateHistory(int keepLast) {
  if (_messages.length <= keepLast) return [];
  int effectiveKeep = keepLast;
  while (effectiveKeep < _messages.length) {
    final kept = _messages.sublist(_messages.length - effectiveKeep);
    if (kept.any((m) =>
        (m.role == 'user' || m.role == 'assistant') &&
        (m.toolCalls == null || m.toolCalls!.isEmpty))) {
      break;
    }
    effectiveKeep++;
  }
  final removed = _messages.sublist(0, _messages.length - effectiveKeep);
  _messages.removeRange(0, _messages.length - effectiveKeep);
  updated = DateTime.now();
  return removed;
}
```

### Fix 4: Save after each tool iteration

```dart
// agent_loop.dart — save once per iteration (after all tool calls)
for (final toolCall in response.toolCalls) {
  yield ToolCallEvent(name: toolCall.name, arguments: toolCall.arguments);
  final result = await tools.execute(toolCall.name, toolCall.arguments);
  yield ToolResultEvent(name: toolCall.name, result: result);
  session.addMessage(Message(
    role: 'tool', content: result.forLLM,
    toolCallId: toolCall.id, name: toolCall.name,
  ));
}
// Persist once after all tools (flush is ~10-50ms on Android)
await sessions.save(session);
```

### Defense-in-depth flush layers

Three layers ensure data reaches disk even if the normal save path is bypassed:

```dart
// Layer 1: flush() in save() and deleteSession() (see Fix 1)

// Layer 2: AppLifecycleListener in root widget (app.dart)
_lifecycleListener = AppLifecycleListener(
  onStateChange: (state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(sessionManagerProvider.future).then((sm) => sm.flush());
    }
  },
);

// Layer 3: ref.onDispose safety net (app_providers.dart)
ref.onDispose(() => manager.flush());  // fire-and-forget (Riverpod won't await)
```

## Code Review Refinements

Applied after initial implementation, based on 6-agent code review:

- **compact() guarded**: `_box!.compact()` on startup wrapped in try-catch — Hive compact is unsafe across isolates (advisory locks are per-process, not per-isolate). *Superseded (2026-06-10): the startup `compact()` was REMOVED entirely — both isolates hold the box open in one process, and compact's temp-file + inode-swap silently loses the other isolate's writes. See the doc comment in `lib/core/session/isolate_persistence/cache_reload.dart` and `todos/001-pending-p2-compact-cross-isolate-corruption-risk.md` (resolved).*
- **Per-tool save batched**: Moved `sessions.save()` from inside the tool-call for-loop to after it. Saves 10-50ms per tool call on Android eMMC/UFS.
- **ref.onDispose corrected**: Changed from `() async { await manager.flush(); }` to `() => manager.flush()` — `ref.onDispose` does not await async closures.
- **Exception logs sanitized**: `$e` replaced with `${e.runtimeType}` in catch blocks to prevent leaking corrupted session content into logcat.

## Prevention Strategies

### Write-through persistence
Treat `box.put()` without `flush()` as a bug. Every critical write must be durable before the method returns. On Android, the process can die at any line.

### Immutable return values
Never expose mutable internal state. `getMessages()`, `getAllSessions()`, and similar accessors must return copies or `UnmodifiableListView`. Read paths must never mutate the source.

### Bounded defensive loops
Any loop that removes elements needs an upper bound and a post-condition check. After stripping/truncating, assert that the collection meets minimum invariants (non-empty, has at least 1 user message).

### Intermediate persistence in long operations
The agent loop can execute multiple tool calls over seconds. Save after each complete iteration — the cost of an extra `flush()` (~10-50ms) is negligible compared to losing a multi-step interaction.

### Crash-oriented design
Ask "if the app is killed right after this line, what is lost?" If the answer is "user data," add a flush.

## Testing Recommendations

1. **Immutability test**: Call `getMessages()`, mutate the returned list, call `getMessages()` again — assert original data is intact.
2. **Truncation boundary**: Test `truncateHistory()` where all last N messages are tool results — should retain all, not delete all.
3. **Kill-recovery**: Start agent loop, trigger multi-step tool execution, `am force-stop` after first tool result, restart, verify session contains the completed steps.
4. **CI grep lint**: Flag `box.put(` not followed by `flush()` within the same method.

## Related Documentation

- [Hive reload race: empty-session overwrite](hive-reload-race-empty-session-overwrite.md) — later data-loss race in the cross-isolate reload path, and the serialized/lazy reload that replaced the original mechanism
- [Cron sessions Hive path mismatch between isolates](../architecture/cron-sessions-hive-path-mismatch-between-isolates.md) — prior fix for Hive path error, save-before-notify race, and cross-isolate reload
- [Cron triggers lost when main isolate dead](../runtime-errors/cron-triggers-lost-when-main-isolate-dead.md) — data loss from silent inter-isolate communication failures
- [Decouple cron from Telegram autonomous service](../architecture/decouple-cron-from-telegram-autonomous-service.md) — dual-isolate architecture context
- [Enable location tools in service isolate](../architecture/enable-location-tools-in-service-isolate.md) — FlutterEngine vs plain Dart isolate (Hive boxes not shared)

## Files Changed

- `lib/core/session/session_manager.dart` — flush after save/delete, compact try-catch, log sanitization
- `lib/core/session/session.dart` — non-destructive getMessages(), truncateHistory guard
- `lib/core/agent/agent_loop.dart` — save after summarization, on error, per tool iteration
- `lib/app.dart` — AppLifecycleListener for paused/detached flush
- `lib/providers/app_providers.dart` — ref.onDispose fire-and-forget flush
- `lib/features/chat/history_screen.dart` — _sessionTitle() fallback to summary
- `lib/providers/chat_provider.dart` — session reload support
