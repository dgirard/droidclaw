---
status: pending
priority: p3
issue_id: "004"
tags: [code-review, simplicity, architecture]
dependencies: ["001", "002", "003"]
---

# Consider Removing Redundant Flush Layers

## Problem Statement

The implementation has 3 layers of flush protection:
1. `flush()` after every `save()` and `deleteSession()`
2. `AppLifecycleListener` on `paused`/`detached`
3. `ref.onDispose` in sessionManagerProvider

With layer 1 (flush-in-save), layers 2 and 3 are redundant — data is already durable the moment it's saved. The extra layers add ~31 LOC of defensive code that can never trigger meaningfully.

## Findings

- **code-simplicity-reviewer**: ~31 LOC removable. AppLifecycleListener and ref.onDispose are belt-and-suspenders when flush-in-save already guarantees durability.
- **architecture-strategist**: Defense-in-depth is reasonable for a data-loss bug fix. Recommend keeping for now, revisiting later.

## Proposed Solutions

### Option A: Keep all 3 layers (Current)
- **Pros**: Maximum safety, defense-in-depth
- **Cons**: 31 LOC of code that never fires meaningfully
- **Effort**: None
- **Risk**: None

### Option B: Remove layers 2 and 3
- **Pros**: Simpler code, less to maintain
- **Cons**: Removes safety nets (even if theoretically unnecessary)
- **Effort**: Small
- **Risk**: Very low

## Recommended Action

Keep for now (Option A). Revisit after confirming session loss is fully resolved in production.

## Technical Details

**Affected files:**
- `lib/app.dart` — AppLifecycleListener (~15 LOC)
- `lib/providers/app_providers.dart` — ref.onDispose (~3 LOC)

## Acceptance Criteria

- [ ] Decision documented
- [ ] If removing: no regression in session persistence

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-03-13 | Created from code review | Defense-in-depth acceptable for data-loss bugs |
