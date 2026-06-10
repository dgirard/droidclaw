---
status: resolved
priority: p3
issue_id: "006"
tags: [code-review, data-integrity, edge-case]
dependencies: []
---

# truncateHistory Edge Case: All Messages Have toolCalls

## Problem Statement

`truncateHistory()` increases `effectiveKeep` until it finds at least one user/assistant message without `toolCalls`. If ALL remaining messages have toolCalls (unlikely but possible with heavy tool-use sessions), the loop will keep ALL messages, effectively preventing summarization entirely. The session will grow unbounded.

## Findings

- **data-integrity-guardian**: The guard loop has no upper bound. In a pathological case where every message is either a tool result or an assistant message with toolCalls, `effectiveKeep` reaches `_messages.length` and nothing is truncated.

## Proposed Solutions

### Option A: Add a fallback after the loop
If `effectiveKeep == _messages.length`, fall back to keeping the original `keepLast` messages anyway.
- **Pros**: Guarantees summarization always works
- **Cons**: Could discard all messages in edge case (mitigated by summary text)
- **Effort**: Small (3 lines)
- **Risk**: Low

### Option B: Accept the edge case
Tool-heavy sessions without any plain user/assistant messages are extremely rare in practice.
- **Pros**: No code change
- **Cons**: Theoretical unbounded growth
- **Effort**: None
- **Risk**: Very low

## Technical Details

**Affected files:**
- `lib/core/session/session.dart` — `truncateHistory()`

## Acceptance Criteria

- [ ] truncateHistory always truncates (never returns empty when messages > keepLast)
- [ ] Summary is generated even for tool-heavy sessions

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-03-13 | Created from code review | Guard loops need upper bounds |

## Resolution (2026-06-10, U13)

Fixed via Option A in `lib/core/session/session.dart`: after the guard loop,
if no standalone user/assistant message exists anywhere in the history
(all-tool-calls pathology), `effectiveKeep` falls back to the requested
`keepLast`, so truncation/summarization always proceeds. When a standalone
message DOES exist, the original guard behavior is preserved (the window
grows to retain it) — pinned by the existing characterization test. The
LLM view stays valid because `getMessages()` strips leading orphaned tool
messages on a copy. Regression tests:
`test/session/lazy_load_and_flush_policy_test.dart`
("truncateHistory all-tool-calls edge case (todos/006)").
