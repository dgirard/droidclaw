---
status: resolved
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
| 2026-06-10 | U10: removed startup `compact()` from `SessionManager.init()` entirely (Option B, escalated from the interim Option A try-catch) | try-catch prevented the crash but not the corruption: a compact rename in one isolate strands the other isolate's open file handle on the old inode, silently losing its writes. Both isolates compacted at boot — the worst moment. flush-after-save + Hive's own write-time auto-compaction keep the box bounded without it. |

## Resolution (U10, 2026-06-10)

The explicit `compact()` call this todo is about no longer exists; all
acceptance criteria are met trivially (nothing to crash, nothing to log,
corrupted records are skipped entry-by-entry by `CacheReload`).

**Residual, documented constraint**: Hive's built-in write-time
auto-compaction (default strategy: >60 deleted/overwritten frames AND >15% of
entries) can still fire in either isolate while the other holds the box open.
A real fix needs a cross-isolate lock that does not exist in Hive 2.x. The
constraint — including "do NOT add compact() calls in this subsystem" — is
documented in `lib/core/session/isolate_persistence/cache_reload.dart`. U13's
save batching will reduce the overwrite churn that feeds the auto-compaction
counter.

## Resources

- PR: session-loss fix implementation
- Hive 2.x advisory lock limitation documentation
