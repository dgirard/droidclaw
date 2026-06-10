---
title: "Hive reload() close-reopen race: getOrCreate could overwrite persisted history with an empty session"
date: 2026-06-10
category: database-issues
module: core/session
problem_type: database_issue
component: database
symptoms:
  - "During a cron-completion reload, a live agent turn calling getOrCreate(existingKey) received a fresh empty Session for a key with persisted history"
  - "A later save() of that fabricated session would overwrite the real on-disk record"
  - "In the degraded state (reload + recovery both failed), deleteAllSessions silently no-op'd while the data wiper reported success"
root_cause: async_timing
resolution_type: code_fix
severity: high
tags: [hive, dual-isolate, race-condition, reload, session-manager, data-loss, rehydration]
---

# Hive reload() close-reopen race: getOrCreate could overwrite persisted history with an empty session

## Problem

`SessionManager.reload()` — the documented cross-isolate visibility mechanism (close box → reopen → rebuild cache) — runs while the main isolate may be mid-agent-turn. During the close→reopen window the box is unreadable; `getOrCreate(existingKey)` then fabricated a brand-new empty `Session`, and the next `save()` would overwrite the persisted history. The fix that made cron sessions visible (close+reopen reload) had introduced a narrower data-loss race of its own. Found by adversarial code review, not in the field.

## Symptoms

- `get()` returns null during reload's window (isOpen guard), so `getOrCreate()` takes the "create" branch for keys that exist on disk.
- The same window made `save()`/`flush()`/`delete*` throw `HiveError: Box already closed` before guards were added — and after naive guards, made deletes silently no-op (a wipe reporting false success: a privacy bug, since "Erase all data" left conversations on disk).

## What Didn't Work

- **isOpen guards alone**: they stop the crash but convert destructive operations into silent no-ops (the wipe false-success) and still let `getOrCreate` fabricate empty sessions.
- **Making get/getOrCreate async to await the reload**: rejected — characterization tests pin the synchronous API (`identical(getOrCreate(k), getOrCreate(k))`), and an API break would ripple through every caller.

## Solution

Three cooperating mechanisms in `lib/core/session/session_manager.dart`:

1. **Serialize writes against reload**: the in-flight reload is stored as `Future<void>? _reloading` (reentrant `reload()` returns the same future); `save()`, `deleteSession()`, `deleteAllSessions()`, `flush()` await it before touching the box.
2. **Rehydration for the synchronous path**: when `getOrCreate(key)` runs while the box is unreadable but the metadata index proves a persisted record exists, the fresh instance is queued in `_awaitingRehydration`. `_rehydrateFabricated()` runs synchronously inside the reload (before its future resolves): it decodes the on-disk record and **prepends** its history into the same caller-held instance (`Session.absorbPersistedHistory`, summaries merged persisted-first) — so nothing typed mid-reload is lost and an empty session can never overwrite persisted history.
3. **Loud degraded state**: if reload fails, a plain `Hive.openBox` recovery is attempted; if that fails too, reads stay cache-only and `deleteAllSessions()` **throws** so callers (DataWiper) record a failure — and the wiper independently deletes the Hive box file set so the erase contract holds anyway.

## Why This Works

The race has two halves: async callers can simply wait (the shared future), while the synchronous cache API cannot — so instead of blocking it, the design makes fabrication *safe* by guaranteeing merge-on-reload. The invariant is stated in the code: **never overwrite persisted history with an empty session**. Rehydration runs before the reload future resolves, so any awaited `save()` observes the merged state.

## Prevention

- Any new cross-isolate store with a close→reopen reload must serialize mutations against the reload future from day one.
- Destructive operations must never silently no-op in degraded states — throw, or report a step failure the caller records.
- Pinned by tests: `test/session/isolate_persistence_test.dart` (concurrent reload+getOrCreate never yields an empty session; reentrant reload returns the same future; degraded-box no-throw guards), `test/session_characterization_test.dart` (summary-merge order), `test/security/secret_handling_test.dart` (wipe records the failure AND the box file is deleted).

## Related Issues

- `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md` — introduced the close+reopen `reload()` whose race this fixes; its Prevention rule needs the serialization caveat (flagged for refresh).
- `docs/solutions/database-issues/session-data-loss-hive-flush-and-destructive-reads.md` — same subsystem, different loss mechanisms; its SIGKILL/page-cache failure model is contradicted by the newer analysis (flagged for refresh).
- `docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md` — same "never trust silent no-ops" failure family; queue logic since extracted to `lib/core/session/isolate_persistence/durable_trigger_queue.dart`.
