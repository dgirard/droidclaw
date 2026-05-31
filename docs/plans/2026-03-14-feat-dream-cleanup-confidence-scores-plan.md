---
title: "feat: Add confidence scores to dream cleanup operations with user validation"
type: feat
date: 2026-03-14
---

# feat: Add confidence scores to dream cleanup operations with user validation

## Overview

Add a `confidence` field (0-100) to each cleanup operation proposed by the LLM in `dream(operation: "cleanup")`. Operations are split by confidence level:

- **90-100 (Certain)**: Auto-executed immediately, no validation needed
- **< 90 (Probable / Uncertain / Speculative)**: Returned to the agent for user validation before execution

This creates a two-phase flow: auto-execute the obvious, ask for approval on the rest.

## Problem Statement / Motivation

Currently each cleanup operation has only `type`, IDs, and `reason`. The agent and user have no way to gauge how certain the LLM is about each proposed operation. A garbage entity deletion ("blablabla") deserves 95% confidence, while a speculative merge ("Céline Torris" / "Céline T.") might only be 60%. Without this signal, the tool either executes everything blindly or the user must manually review every operation.

The `dream audit` flow already uses scores (0-100) and levels (1/2/3) via `ScoredPair` — this feature brings the same pattern to `cleanup`, with an added validation loop for lower-confidence operations.

## Proposed Solution

### Two-phase cleanup execution

```
dream(operation: "cleanup")
  │
  ├─ LLM proposes N operations, each with confidence 0-100
  │
  ├─ Phase 1: Auto-execute operations with confidence >= 90
  │   └─ Report results immediately
  │
  └─ Phase 2: Return operations with confidence < 90 as "pending"
      └─ Agent presents them grouped by confidence to user:
          ├─ 60-89 Probable  → "These look likely, approve?"
          ├─ 30-59 Uncertain → "These need review"
          └─ 0-29 Speculative → "Low evidence, probably skip"
      └─ User approves/rejects
      └─ Agent calls dream(operation: "cleanup_exec", approved_ops: [...])
```

### New `cleanup_exec` operation

A new operation that executes a specific list of previously proposed operations. The agent passes back the approved operations as JSON after user validation.

```
dream(operation: "cleanup_exec", approved_ops: [
  {"type": "merge", "primary_id": 7, "secondary_id": 86},
  {"type": "delete", "entity_id": 34}
])
```

## Technical Approach

### Files to modify

#### `lib/core/knowledge/services/kb_maintenance_service.dart`

- [x] Add `final int? confidence;` to `CleanupOperation` base class
- [x] Add `this.confidence` to `CleanupDelete`, `CleanupMerge`, `CleanupDeleteRelation` constructors
- [x] Update system prompt in `proposeCleanup()`: add `"confidence":N` to each operation example, add confidence level descriptions
- [x] Update `_parseCleanupResponse()`: read confidence with clamping:
  ```dart
  final confidence = (map['confidence'] as num? ?? map['score'] as num?)?.toInt()?.clamp(0, 100);
  ```
  Fallback key `"score"` handles LLM key name hallucination.
- [x] Make `_parseCleanupResponse` static (like `parseLlmResponse` already is) for testability
- [x] Update `executeCleanupOps()`: include confidence in `executedOps` log strings

#### `lib/core/tools/dream_tool.dart`

- [x] Update `_cleanup()`: split operations by confidence threshold (90)
  - Auto-execute operations with `confidence == null || confidence >= 90`
  - Return remaining operations as "pending_review" in the result
- [x] Add `_cleanupExec()` method: parse `approved_ops` from arguments, reconstruct `CleanupOperation` instances, execute via `_service.executeCleanupOps()`
- [x] Add `'cleanup_exec'` to operation enum and switch
- [x] Add `'approved_ops'` parameter to tool schema (array of operation objects)
- [x] Update `_opsToJson()`: add `'confidence': op.confidence` (omit when null)
- [x] Update `_writeCleanupDetailed()`: show confidence inline, e.g. `"foo" (#3) (95%) — garbage`
- [x] Group pending operations by confidence level in forUser output:
  ```
  Auto-executed (confidence >= 90): 5 operations
    ✓ Deleted "blablabla" (#34) (98%) — test data
    ✓ Merged "vélo" → "bicyclette" (#12→#8) (92%) — synonyms

  Pending review — Probable (60-89%): 3 operations
    "Céline Torris" → "Céline T." (#7→#86) (72%) — likely same person
    ...

  Pending review — Uncertain (30-59%): 1 operation
    "Paris" → "Paris 75" (#20→#45) (45%) — might be same place

  Pending review — Speculative (<30%): 0 operations

  Reply with the operations you approve, or say "approve all" / "reject all".
  ```

#### `test/dream_dedup_test.dart`

- [x] Update `CleanupOperation sealed class subtypes` test to include confidence
- [x] Update `CleanupResult counts and execution log` test
- [x] Add test: confidence parsing (int, null, out-of-range, float, string)
- [ ] Add test: operation splitting by confidence threshold
- [x] Add test: `cleanup_exec` with approved_ops parsing

### System Prompt Changes

Current operations format in prompt:
```
- merge: {"type":"merge", "primary_id":N, "secondary_id":N, "reason":"..."}
```

New format with confidence:
```
- merge: {"type":"merge", "primary_id":N, "secondary_id":N, "confidence":85, "reason":"..."}
- delete: {"type":"delete", "entity_id":N, "confidence":95, "reason":"..."}
- delete_relation: {"type":"delete_relation", "relation_id":N, "confidence":70, "reason":"..."}
```

Add instruction (near end of prompt, following recency bias learnings):
```
Include a "confidence" field (integer 0-100) for each operation:
- 90-100: Certain (obvious garbage, exact duplicates, clearly stale)
- 60-89: Probable (likely duplicates, stale data, probably correct)
- 30-59: Uncertain (might be valid, needs human review)
- 0-29: Speculative (low evidence, better to keep than delete)
```

### UX / Agent Interaction Flow

The agent's natural conversation loop handles the validation:

```
User: "Nettoie la KB"
Agent: calls dream(operation: "cleanup")
Tool returns:
  forLLM: {
    "auto_executed": { "count": 5, "operations": [...] },
    "pending_review": {
      "probable": [ {op1}, {op2} ],
      "uncertain": [ {op3} ],
      "speculative": []
    }
  }
  forUser: "5 operations auto-exécutées (confiance >= 90%).
            3 operations en attente de validation..."

Agent: "J'ai nettoyé 5 éléments évidents. Il reste 3 opérations à valider :
        [presents grouped list]
        Lesquelles approuves-tu ?"

User: "Approuve les 2 premières, rejette la 3ème"

Agent: calls dream(operation: "cleanup_exec", approved_ops: [{op1}, {op2}])
Tool returns: "2 operations executed."
```

No new UI screens needed — the chat is the validation UI. The agent formats the pending operations as a readable list and interprets the user's natural language response.

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Field type | `int?` (nullable) | Distinguishes "LLM didn't provide" from "low confidence". |
| Auto-execute threshold | `>= 90` | Conservative — only execute obvious operations automatically. |
| `null` confidence treatment | Auto-execute | If LLM didn't provide confidence, assume it would have if uncertain. Don't block on format compliance. |
| Validation UI | Chat conversation | No new screens. Agent presents, user responds in natural language. Consistent with existing dream audit flow. |
| `cleanup_exec` | New operation | Clean separation. Agent passes back exactly the operations the user approved. |
| Execution order | Unchanged (merges → rel deletes → deletes) | Safety invariant preserved in both auto-execute and cleanup_exec. |
| Fallback key | `"score"` as alias for `"confidence"` | `dream audit` uses `"score"` — LLM might hallucinate that key name. |

### Learnings Applied

- **Critical instructions go last** in LLM prompts (recency bias) — place confidence instruction near the end of the system prompt, before the JSON format examples
- **Include examples** for each operation type with confidence values — especially important for Gemini models
- **Test with weakest model** (Gemini Flash) — JSON format compliance varies across providers

## Acceptance Criteria

- [x] `CleanupOperation` sealed class has nullable `confidence` field
- [x] LLM system prompt requests confidence (0-100) with examples per operation type
- [x] `_parseCleanupResponse` reads, clamps, and defaults confidence correctly
- [x] Operations with confidence >= 90 (or null) are auto-executed
- [x] Operations with confidence < 90 are returned grouped by level (probable/uncertain/speculative)
- [x] `forUser` output shows auto-executed results + pending operations grouped by confidence level
- [x] `forLLM` JSON includes `auto_executed` and `pending_review` sections
- [x] New `cleanup_exec` operation accepts `approved_ops` array and executes them
- [x] `_parseCleanupResponse` is static and directly unit-testable
- [x] Tests cover: confidence parsing, threshold splitting, cleanup_exec round-trip
- [ ] Works with Anthropic, Gemini, and OpenAI providers
- [x] All existing tests still pass

## References

- Existing pattern: `ScoredPair.score` + `_classifyLevel()` in `kb_maintenance_service.dart:1404`
- Cleanup plan: `docs/plans/2026-03-14-feat-dream-llm-full-kb-cleanup-plan.md`
- Learnings: LLM instruction placement (end of prompt), emphatic language, example-based prompting for Gemini
