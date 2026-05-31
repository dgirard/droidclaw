---
title: "feat: Add LLM-based full KB cleanup operation to dream tool"
type: feat
date: 2026-03-14
---

# feat: Add LLM-based full KB cleanup operation to dream tool

## Overview

Add a `cleanup` operation to the existing `dream` tool that sends the full Knowledge Base (entities + relations) to the LLM as compact markdown tables, and asks it to return structured JSON operations (merge, delete, delete_relation). The tool parses the response, validates all IDs, and executes the operations on the KB in a single call.

Unlike the existing `audit`/`merge` operations (which use deterministic scoring + LLM verification on candidate pairs), `cleanup` gives the LLM a **global view** of the entire KB so it can spot issues that pairwise comparison misses: garbage entities, orphan relations, naming inconsistencies, etc.

## Problem Statement / Motivation

The current dream tool detects duplicates via token blocking + scoring + LLM verification. This works well for pairwise dedup but misses:

- **Garbage entities**: "blablabla", "nalnu92g", "qac995vi" — noise from test inputs or URL fragments
- **Orphaned concepts**: entities with no relations, no facts, no useful info (130+ entities with only empty facts)
- **Naming cleanup**: "Proof Editor.ai" vs "ProofEditor" vs "API de Proof Editor" — three entities for the same thing, hard to catch pairwise
- **Relation cleanup**: duplicate or stale relations pointing to deactivated entities
- **Ephemeral entities**: dates like "2026-03-13", "mercredi", "aujourd'hui" that shouldn't be permanent entities

A human looking at the full entity list would immediately spot these. The LLM can do the same.

## Proposed Solution

### Single-phase execution with dry_run option

```
dream(operation: "cleanup")                    → Propose AND execute operations
dream(operation: "cleanup", dry_run: true)     → Propose only (no execution)
```

The agent naturally reviews the LLM output before calling `cleanup` again. A separate `cleanup_exec` phase is unnecessary — the agent IS the review layer.

`dry_run: true` returns proposed operations without executing, for when the user wants to preview first.

### 3 Operation Types Only

Start simple — only the operations that matter most:

1. **`delete`** — Remove garbage/ephemeral entities (deactivate)
2. **`merge`** — Combine duplicate entities (keep primary, transfer relations/facts)
3. **`delete_relation`** — Remove duplicate or stale relations

`rename` and `set_type` are deferred — they can be added later if needed.

### KB Snapshot Format

Compact markdown tables, not JSON (more token-efficient, as proven in the audit verification table work):

**Entities table:**
```
| ID | Name | Type | Facts | Aliases | Relations |
|----|------|------|-------|---------|-----------|
| 7 | Céline Torris | PERSON | 0 | Céline Thoris, Céline Taurisse | →Famille, →Anca |
| 16 | Proof Editor.ai | CONCEPT | 0 | Proof Editor | →Mac, →éditeur de documents |
| 214 | Didier | PERSON | 0 | | →vélo, →bicyclette |
...
```

**Relations table:**
```
| ID | Source | → | Target | Type |
|----|--------|---|--------|------|
| 1 | Didier | → | vélo | RELATED_TO |
| 2 | Didier | → | bicyclette | RELATED_TO |
...
```

### Token Budget

- 218 entities × ~60 chars/row ≈ 13K chars ≈ 4K tokens
- ~150 relations × ~40 chars/row ≈ 6K chars ≈ 2K tokens
- System prompt ≈ 1K tokens
- **Total input: ~7K tokens** — well within any model's context window
- Response budget: `max_tokens: 4096` (operations JSON)

Even with 500 entities, this stays under 15K tokens — no batching needed.

### LLM Response Format

```json
{
  "operations": [
    {
      "type": "merge",
      "primary_id": 7,
      "secondary_id": 86,
      "reason": "Céline Torris et Céline Thooris sont la même personne"
    },
    {
      "type": "delete",
      "entity_id": 34,
      "reason": "blablabla — données de test sans signification"
    },
    {
      "type": "delete_relation",
      "relation_id": 42,
      "reason": "Relation en double"
    }
  ],
  "summary": "7 merges, 12 deletes, 2 relation fixes"
}
```

## Technical Approach

### Files to modify

#### `lib/core/tools/dream_tool.dart`

- [x] Add `'cleanup'` to operation enum
- [x] Add `'dry_run'` boolean parameter (default false)
- [x] Add `_cleanup()` method — calls `_service.buildKBSnapshot()` + `_service.proposeCleanup()` + optionally `_service.executeCleanupOps()`
- [x] `_cleanup()` returns `ToolResult.dual()` — forLLM: JSON ops + results, forUser: readable summary

#### `lib/core/knowledge/services/kb_maintenance_service.dart`

- [x] Add `Future<String> buildKBSnapshot()` — batch query all active entities + relations, builds markdown tables with StringBuffer
- [x] Add `Future<List<CleanupOperation>> proposeCleanup(String snapshot)` — sends to LLM, parses response
- [x] Add `Future<CleanupResult> executeCleanupOps(List<CleanupOperation> ops)` — validates + executes each op
- [x] Add `CleanupOperation` sealed class (CleanupDelete, CleanupMerge, CleanupDeleteRelation)
- [x] Add `CleanupResult` class (counts per operation type, errors list)
- [x] Add `_parseCleanupResponse(String response)` — JSON parsing with fallback

#### `lib/core/knowledge/database/knowledge_graph_db.dart`

- [x] No new methods needed — existing `mergeEntities()`, `deactivateEntity()`, `expireRelation()` cover all 3 ops

### System Prompt

```
You are a knowledge base maintenance specialist.

Analyze the entity and relation tables below and propose cleanup operations.

Look for:
1. DUPLICATE ENTITIES: Same real-world thing with different names → merge (keep the most descriptive name as primary)
2. GARBAGE ENTITIES: Test data, URL fragments, meaningless strings → delete
3. EPHEMERAL ENTITIES: Dates (2026-03-13), relative time (aujourd'hui, demain, mercredi) → delete
4. ORPHAN RELATIONS: Relations to/from deactivated or nonsensical entities → delete_relation
5. DUPLICATE RELATIONS: Multiple identical relations between same entities → delete_relation (keep one)

Rules:
- NEVER propose operations on PERSON entities — no delete, no merge where a PERSON is secondary_id
- Prefer merge over delete when two entities represent the same concept
- For phone numbers stored as entities: suggest deleting them (they should be facts on the owner)

Return ONLY valid JSON (no markdown fences):
{"operations":[...], "summary":"..."}

Operation types:
- merge: {"type":"merge", "primary_id":N, "secondary_id":N, "reason":"..."}
- delete: {"type":"delete", "entity_id":N, "reason":"..."}
- delete_relation: {"type":"delete_relation", "relation_id":N, "reason":"..."}
```

### Validation & Safety

Before executing each operation:
1. **Validate entity IDs exist and are active** — skip operations on non-existent/inactive entities
2. **No type-based protection** — all entity types (including PERSON) can be deleted, merged, etc. The LLM decides.
3. **Log each operation** to `AppLogger` before executing
4. **Count successes and failures** separately
5. **Wrap in transaction** per operation (not all-or-nothing — partial success is fine)
6. **Return errors list** in result so agent can report what failed

### Execution Order

Operations must be executed in this order to avoid conflicts:
1. Merges first (entities being merged might also appear in delete ops)
2. Delete relations
3. Delete entities last

### DB Query Optimization

Use batch queries instead of N+1:
- `buildKBSnapshot()`: single query for all active entities, single query for all active relations
- `executeCleanupOps()`: batch-load all referenced entity IDs upfront for validation

## Acceptance Criteria

- [x] `dream(operation: "cleanup")` sends KB snapshot to LLM, proposes AND executes operations
- [x] `dream(operation: "cleanup", dry_run: true)` proposes without executing
- [x] KB snapshot is compact markdown tables (entities + relations) built with StringBuffer
- [x] LLM response parsed as JSON with fallback on parse failure
- [x] Each operation validated (IDs exist, entity active) before execution
- [x] PERSON entities protected from ALL destructive ops (delete + merge as secondary)
- [x] Dual ToolResult: forLLM has JSON details, forUser has readable summary
- [x] Works with Anthropic, Gemini, and OpenAI providers
- [x] Operations logged via AppLogger
- [x] Unit tests for snapshot building, response parsing, validation

## Implementation Phases

### Phase 1: Snapshot + Propose + Execute
- `CleanupOperation` sealed class (3 subtypes)
- `buildKBSnapshot()` — batch queries + StringBuffer markdown tables
- `proposeCleanup()` — LLM call + JSON parsing
- `executeCleanupOps()` — ordered execution with PERSON protection
- `_cleanup()` in dream_tool — wire it all up
- Tests for snapshot format, response parsing, validation, PERSON protection

### Phase 2: Polish
- Tune system prompt based on real LLM responses
- Add `cleanup` to tool description
- Add to README tools table

## References

- Existing dream tool: `lib/core/tools/dream_tool.dart`
- KB maintenance service: `lib/core/knowledge/services/kb_maintenance_service.dart`
- KB database: `lib/core/knowledge/database/knowledge_graph_db.dart`
- KB export analysis: `/tmp/kb_summary.txt` (218 entities, many with empty facts)
- Learnings: LLM instruction placement (end of prompt), emphatic language, example-based prompting for Gemini
- Learnings: Persist after each operation (not all-or-nothing)
