---
status: resolved
priority: p2
issue_id: "002"
tags: [code-review, performance, agent-loop]
dependencies: []
---

# Batch Tool Result Saves Instead of Per-Tool flush()

## Problem Statement

The agent loop now calls `sessions.save(session)` after **each individual tool result**. Since `save()` includes `flush()` (fsync), this adds 10-50ms per tool call on Android eMMC/UFS storage. A single LLM iteration with 3 tool calls adds 30-150ms of pure IO wait. Multi-iteration conversations compound this significantly.

## Findings

- **performance-oracle**: 50-250ms added latency per iteration with multiple tool calls. Recommended batching saves to once per iteration.
- **code-simplicity-reviewer**: Per-tool save is excessive given that flush-in-save already guarantees durability. One save after all tools in an iteration is sufficient.
- **architecture-strategist**: The original bug (session loss) is fixed by flush-in-save. Per-tool granularity is over-saving.

## Proposed Solutions

### Option A: Save once after tool loop (Recommended)
Move `sessions.save()` from inside the tool-call for-loop to after it completes.
- **Pros**: Reduces IO by N-1x (where N = tool calls per iteration), simpler
- **Cons**: If app is killed mid-tool-execution, last tool results are lost (but the LLM will re-request them)
- **Effort**: Small (move 1 line)
- **Risk**: Very low — tool results are reproducible

### Option B: Keep per-tool save but skip flush()
Save to Hive page cache per-tool but only flush() once per iteration.
- **Pros**: Data in page cache (survives normal exits), flush only once
- **Cons**: Requires splitting save() into save-without-flush + explicit flush
- **Effort**: Medium
- **Risk**: Low

## Recommended Action

Option A — move save after the tool for-loop.

## Technical Details

**Affected files:**
- `lib/core/agent/agent_loop.dart` — `processMessage()`, lines ~246-264

**Current code:**
```dart
for (final toolCall in response.toolCalls) {
  // ... execute tool ...
  session.addMessage(Message(...));
  await sessions.save(session);  // flush per tool
}
```

**Proposed:**
```dart
for (final toolCall in response.toolCalls) {
  // ... execute tool ...
  session.addMessage(Message(...));
}
await sessions.save(session);  // flush once after all tools
```

## Acceptance Criteria

- [ ] Only one `sessions.save()` call per agent loop iteration (after tool loop)
- [ ] No regression in session persistence (sessions survive app restart)
- [ ] Measurable latency improvement with multi-tool iterations

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-03-13 | Created from code review | fsync on Android eMMC costs 10-50ms per call |

## Resources

- PR: session-loss fix implementation

## Resolution (2026-06-10, U13)

Resolved in U13. The per-tool save had already been batched to one save per
tool-call iteration (Option A); U13 additionally removed the fsync from that
per-batch save: `agent_loop.dart` now calls `sessions.save(session,
flush: false)` after the tool loop. The write is still an awaited Hive `put`
(survives process kill via the OS page cache); only the fsync is deferred to
the turn-ending save (final response / error / max-iterations), which always
flushes. Policy documented on `SessionManager`; pinned by
`test/agent_loop_test.dart` ("flush cadence (U13)") and
`test/session/lazy_load_and_flush_policy_test.dart`.
