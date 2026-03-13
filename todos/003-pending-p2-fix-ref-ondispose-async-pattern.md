---
status: pending
priority: p2
issue_id: "003"
tags: [code-review, riverpod, correctness]
dependencies: []
---

# Fix ref.onDispose Async Pattern

## Problem Statement

`ref.onDispose()` accepts `void Function()`, not `Future<void> Function()`. The current code uses an async closure:

```dart
ref.onDispose(() async {
  await manager.flush();
});
```

This compiles but the `await` is misleading — Riverpod will NOT await the future. The flush is fire-and-forget, which is fine functionally (AppLifecycleListener is the primary safety net), but the code reads as if it's awaited.

## Findings

- **pattern-recognition-specialist**: Inconsistent with other `ref.onDispose` closures in the codebase which use synchronous patterns
- **architecture-strategist**: Misleading async — should use `() => manager.flush()` to make fire-and-forget intent explicit

## Proposed Solutions

### Option A: Use synchronous closure (Recommended)
```dart
ref.onDispose(() => manager.flush());
```
- **Pros**: Honest about fire-and-forget nature, matches other dispose patterns
- **Cons**: None
- **Effort**: Trivial (1 line change)
- **Risk**: None

## Recommended Action

Option A.

## Technical Details

**Affected files:**
- `lib/providers/app_providers.dart` — `sessionManagerProvider`

## Acceptance Criteria

- [ ] `ref.onDispose` uses `() => manager.flush()` (not async)
- [ ] No behavior change (still fire-and-forget)

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-03-13 | Created from code review | ref.onDispose does not await async closures |

## Resources

- Riverpod 3.x documentation on ref.onDispose
