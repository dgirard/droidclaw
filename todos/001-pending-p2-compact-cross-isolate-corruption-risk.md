---
status: pending
priority: p2
issue_id: "001"
tags: [code-review, data-integrity, hive, dual-isolate]
dependencies: []
---

# compact() Cross-Isolate Corruption Risk

## Problem Statement

`SessionManager.init()` calls `box.compact()` on startup. Hive's compact operation uses a temp-file + rename pattern that is safe against kills, but **not safe if two isolates compact simultaneously**. Since DroidClaw has a dual-isolate architecture (main + service), both could call `init()` and trigger `compact()` concurrently, risking box corruption.

Additionally, if the box file is already corrupted from a prior crash, `compact()` could throw and crash the app on startup before any recovery logic runs.

## Findings

- **data-integrity-guardian** (HIGH): Hive compact uses advisory locks that are per-process, not per-isolate. Two FlutterEngines in the same process can interleave compaction writes.
- **architecture-strategist**: Recommended wrapping in try-catch or removing entirely since flush-after-save already prevents unbounded box growth.
- **performance-oracle**: compact() on init adds startup latency with no clear benefit since flush-after-save keeps the box clean.

## Proposed Solutions

### Option A: Wrap compact() in try-catch (Recommended)
- **Pros**: Defensive, prevents startup crash, keeps compaction benefit
- **Cons**: Silently swallows corruption — could mask deeper issues
- **Effort**: Small (2 lines)
- **Risk**: Low

### Option B: Remove compact() from init entirely
- **Pros**: Eliminates cross-isolate risk completely, simpler code
- **Cons**: Box file may grow larger over time (mitigated by flush-after-save)
- **Effort**: Small (delete 1 line)
- **Risk**: Low

### Option C: Add isolate-aware guard (only compact in main isolate)
- **Pros**: Safe compaction when needed
- **Cons**: Requires passing isolate identity to SessionManager, more complex
- **Effort**: Medium
- **Risk**: Low

## Recommended Action

Option A — wrap in try-catch with AppLogger warning. Minimal change, maximum safety.

## Technical Details

**Affected files:**
- `lib/core/session/session_manager.dart` — `init()` method

## Acceptance Criteria

- [ ] compact() failure does not crash the app on startup
- [ ] Warning logged if compact() fails
- [ ] App remains functional with corrupted box file (graceful degradation)

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-03-13 | Created from code review | Cross-isolate Hive operations are unsafe |

## Resources

- PR: session-loss fix implementation
- Hive 2.x advisory lock limitation documentation
