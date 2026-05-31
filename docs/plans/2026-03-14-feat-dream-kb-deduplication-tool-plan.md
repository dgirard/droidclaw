---
title: "feat: Add dream tool for LLM-powered KB entity deduplication"
type: feat
date: 2026-03-14
---

## Enhancement Summary

**Deepened on:** 2026-03-14
**Research agents used:** architecture-strategist, performance-oracle, data-integrity-guardian, agent-native-reviewer, code-simplicity-reviewer, security-sentinel, pattern-recognition-specialist, learnings-researcher, entity-resolution-researcher

### Key Improvements
1. **Service layer extraction**: LLM logic moves to `KbMaintenanceService` (pattern compliance — tools never call LLM directly)
2. **Local-first candidate generation**: Token blocking + embedding cosine pre-filter avoids sending full KB to LLM (security + performance)
3. **Safe 12-step merge order**: Handles self-referential relations, unique constraint conflicts, and properties merge (data integrity)
4. **Compact forLLM content**: Only pair IDs/names/scores — prevents summarization context loss between audit and merge calls
5. **Hybrid string similarity**: Jaro-Winkler 50% + token Jaccard 25% + character trigram 25% (multilingual support)

### New Considerations Discovered
- Summarization can eat the audit result between calls — merge must be self-contained with IDs
- Self-referential relations (A→B merged creates A→A) must be expired before re-pointing
- `properties` JSON field on entities must be merged (was missing)
- `summary_nodes.member_ids` contains entity IDs that become stale after merge
- Prompt injection via entity names is a real attack vector
- Missing `locale` constructor parameter for i18n of `forUser` strings

---

# feat: Add `dream` tool for KB entity deduplication

## Overview

Add a `dream` tool that identifies and merges duplicate entities in the knowledge base using a hybrid approach: local deterministic blocking + scoring for candidate generation, followed by LLM semantic verification for borderline cases. The metaphor: the KB "dreams" — consolidating and cleaning its memories like a brain during sleep.

## Problem Statement

The `EntityResolver` catches most duplicates at ingestion time (Jaro-Winkler >= 0.88), but duplicates still slip through when:
- Names differ significantly ("Dr. Martin Dupont" vs "Martin")
- Entities are created before shared relations exist to disambiguate
- Spelling variants or multilingual names ("Céline" vs "Celine")
- Fragmented ingestion (title, URL, and slug stored as separate entities for the same document)

There is currently **no post-hoc merge facility** — once duplicates exist, they persist forever, degrading retrieval quality and wasting context window tokens.

## Proposed Solution

### Architecture: Two-Operation Tool + Service Layer

Follow the `kb_query` tool's `operation` parameter pattern. The LLM orchestrates the multi-step flow naturally:

```
User: "Clean up my knowledge base"
  → LLM calls dream(operation: "audit")
  → Tool returns scored report with pair IDs
  → LLM presents report, asks user about Level 2 merges
  → User approves specific pairs
  → LLM calls dream(operation: "merge", pairs: [...])
  → Tool executes merges, returns summary
```

### Research Insights — Architecture

**Service layer extraction (pattern compliance):**
No existing tool calls `LLMProvider` directly — LLM calls belong in `lib/core/knowledge/services/`. Extract the LLM scoring logic into a `KbMaintenanceService` class, following the `EntityExtractor` precedent:

```
DreamTool (tool layer — thin dispatcher)
  └── KbMaintenanceService (service layer — orchestration + LLM)
        ├── KnowledgeService (reads: list entities, find duplicates)
        ├── KnowledgeGraphDB (writes: merge entities)
        └── LLMProvider + model (audit analysis prompts)
```

The tool constructor takes only `KbMaintenanceService` + `String? locale` + `String? kbLanguage`. This keeps the tool thin and the service responsible for orchestration, matching how `IngestionPipeline` composes `EntityExtractor` + `EntityResolver` + `KnowledgeGraphDB` today.

**Riverpod provider diamond is safe:** Adding `llmProviderProvider` as a dependency of `toolRegistryProvider` (via the service) creates a diamond, not a cycle. Riverpod handles diamonds correctly via `ref.watch`. Add a comment in `app_providers.dart` noting this is the first tool with indirect LLM provider dependency.

**Context-loss risk between audit and merge:** Summarization triggers at 20+ messages or 75% token budget. A large audit result accelerates token accumulation. Mitigations:
- Keep audit `forLLM` compact: only pair IDs, names, scores, justifications
- Do NOT include explicit merge instructions or full entity data in `forLLM`
- Merge call is self-contained with IDs — works even if audit is summarized away
- The LLM has the tool schema; it knows how to construct the merge call from the IDs

### Incremental Dedup (Last Dream Timestamp)

Store a `last_dream_at` timestamp in `SharedPreferences` (or `AppConfig`). On subsequent runs:
- **New entities** = entities with `created_at > last_dream_at`
- **Priority mode**: Compare new entities against ALL existing entities — O(M×N) where M is small
- **Full mode**: Compare all entities (fallback if never run or explicitly requested)
- Update `last_dream_at` after successful audit completion

This dramatically reduces work on subsequent runs. A KB with 500 entities that adds 10 new ones since last dream only needs ~10×500 = 5000 comparisons (with blocking, much less) instead of 500×499/2 = 124,750.

**Tool parameter addition:**

```json
"full_scan": {
  "type": "boolean",
  "default": false,
  "description": "If true, compare all entities. If false (default), only compare entities added since last dream."
}
```

When `full_scan: false` (default), the audit report should mention: "Analyzed N new entities (since last dream on YYYY-MM-DD). Use full_scan: true for a complete analysis."

### Hybrid Scoring Strategy (Local-First, LLM-Verified)

**Security rationale:** Sending the entire KB to the LLM exposes all PII (phone numbers, addresses, relationships). Local-first candidate generation minimizes data sent to the LLM.

**Performance rationale:** O(N²) pairwise comparison is too slow for >200 entities. Token blocking reduces to O(N×k).

**Pass 1 — Local candidate generation (Dart, no LLM):**

1. **Incremental filter**: If not full_scan, load only entities with `created_at > last_dream_at` as "new" set. Compare each new entity against all active entities (not just other new ones).
2. **Token blocking**: Build a token→entity_id index from all aliases. Only compare entities sharing at least one name token. This reduces pairs from O(N²) to O(N×k) where k ≈ 5-15.
3. **Embedding pre-filter** (when available): For entities with embeddings, compute cosine similarity. Skip pairs below 0.5. Leverage existing `MemoryClusterer.cosineSimilarity()`.
4. **Hybrid string similarity** per candidate pair:
   - Jaro-Winkler 50% (handles typos, prefix matches — reuse `EntityResolver.jaroWinkler()`)
   - Token Jaccard 25% (handles word reordering: "John Smith" vs "Smith, John")
   - Character trigram overlap 25% (language-agnostic fuzzy matching)
5. **Relation overlap**: Jaccard similarity of neighbor entity ID sets
6. **Combined score**: `0.5 × name_similarity + 0.35 × relation_overlap + 0.15 × fact_overlap`
7. **Filter**: keep pairs scoring **>= 0.55** with a **name-score floor of 0.70**
8. **Cap**: top 40 candidate pairs maximum

### Research Insights — Scoring

**Why 0.55 threshold (not 0.40):** A 0.40 threshold passes too many name-only matches without structural evidence. Example: two entities both named "Marie" with 0 shared relations → composite = 0.50 × 1.0 = 0.50, would pass 0.40 but not 0.55. The 0.55 threshold requires either strong name similarity with some structural overlap, or moderate name similarity with strong structural overlap.

**Why skip Soundex/Metaphone:** English-only, bad for multilingual app (FR/ES/DE/IT). Trigram overlap handles phonetic similarity across languages better.

**Why skip TF-IDF:** Requires maintaining a corpus-level document frequency matrix. Unnecessary overhead for on-device KB with < 100K entities.

**Pass 2 — LLM semantic verification (only for candidate pairs):**
- Send candidate pairs (not the full KB) to the LLM in batches (≤ 20 pairs per call, max 2 calls)
- LLM receives: entity names, aliases, fact summaries for each pair — **no raw PII values**
- LLM returns structured JSON: `{pairs: [{id_a, id_b, score, justification}]}`
- LLM can upgrade/downgrade the deterministic score based on semantic understanding

### Research Insights — LLM Prompt Engineering

From institutional learnings:
- **Recency bias**: Place JSON format instructions at the **end** of the prompt, after entity data
- **Imperative language**: "You MUST return only a JSON object" beats "Please return JSON"
- **Model-agnostic robustness**: Flash-class models (Gemini 2.0 Flash) have weaker instruction-following. Use multi-layer enforcement:
  1. System prompt with format spec
  2. Format instruction repeated in the user message
  3. Fallback JSON parser that strips markdown fences and trailing text
- **Sanitize entity content**: Truncate names to 100 chars, strip control characters, JSON-encode all user-derived content to prevent prompt injection via entity names

### Classification Levels

| Level | Score | Action | Color |
|---|---|---|---|
| 1 - Evident | > 85% | Auto-merge recommended | Green |
| 2 - Uncertain | 50-85% | Requires user approval | Orange |
| 3 - False Positive | < 50% | Don't merge, brief mention | Red |

### Research Insights — Simplification Consideration

The simplicity reviewer argues strongly for dropping deterministic scoring entirely and letting the LLM identify duplicates directly (single operation, ~65% less code). **Counter-arguments for keeping the hybrid approach:**
- **Security**: Sending the full KB to the LLM is a PII exfiltration risk
- **Cost**: Every entity comparison via LLM costs tokens; local scoring is free
- **Reliability**: Deterministic scores are reproducible; LLM scores vary across calls
- **Performance**: Local blocking + scoring handles 500 entities in <5s; LLM would need many calls

**Compromise**: Keep the hybrid approach but simplify the tool parameters. Drop `auto_merge_level1` (let the LLM decide what to merge via the two-call flow). Drop `entity_type` filter (let the LLM request it if needed). Keep `max_pairs` as an internal cap, not a parameter.

## Technical Approach

### Phase 1: String Similarity Algorithm

**New file: `lib/core/knowledge/algorithms/string_similarity.dart`**

Place the hybrid similarity function here, consistent with existing algorithm organization (`memory_decay.dart`, `spreading_activation.dart`, `hybrid_scorer.dart`, `memory_clusterer.dart`).

```dart
class StringSimilarity {
  /// Combined similarity score for entity name matching.
  /// Returns 0.0-1.0. Uses Jaro-Winkler (50%), token Jaccard (25%), trigram (25%).
  static double combined(String a, String b) {
    final aLow = a.toLowerCase();
    final bLow = b.toLowerCase();
    final jw = EntityResolver.jaroWinkler(aLow, bLow);
    final jaccard = _tokenJaccard(aLow, bLow);
    final trigram = _trigramSimilarity(aLow, bLow);
    return 0.5 * jw + 0.25 * jaccard + 0.25 * trigram;
  }

  static double _tokenJaccard(String a, String b) { /* ... */ }
  static Set<String> _trigrams(String s) { /* ... */ }
  static double _trigramSimilarity(String a, String b) { /* ... */ }
}
```

### Phase 2: Merge Infrastructure in `KnowledgeGraphDB`

Add `mergeEntities(int primaryId, int secondaryId)` to `KnowledgeGraphDB`.

**Safe 12-step operation order** (from data integrity review):

```
WITHIN A SINGLE SQLITE TRANSACTION:
 1. Validate both entities exist and are active
 2. Expire self-referential relations (secondary↔primary in both directions)
 3. Identify and expire conflicting relations (same triplet would exist on primary)
 4. Re-point remaining relations from secondary to primary (UPDATE OR IGNORE)
 5. Identify and expire conflicting facts (same fact_key exists on primary)
 6. Re-point remaining facts from secondary to primary
 7. Transfer aliases (INSERT OR IGNORE for duplicates)
 8. Add secondary's name as alias of primary (INSERT OR IGNORE)
 9. Merge entity metadata:
    - access_count: sum both
    - base_score: take max
    - last_accessed: take most recent (then update to now)
    - created_at: take earliest (preserve provenance)
    - valid_at: take earliest
    - ingested_at: take earliest
    - temperature: recalculate from merged last_accessed
    - summary: concatenate if both non-null
    - properties: parse both JSON, merge keys (primary wins on conflicts)
10. Deactivate secondary entity (is_active = 0, expired_at = now)
11. Nullify primary's embedding (stale after merge)
12. Update summary_nodes.member_ids if applicable (replace secondaryId with primaryId)
```

### Research Insights — Merge Safety

**CRITICAL: Self-referential relations.** If a relation `(secondaryId, "related_to", primaryId)` exists, re-pointing `source_id` creates `(primaryId, "related_to", primaryId)`. Must expire these BEFORE re-pointing.

**CRITICAL: Unique constraint violations.** A naive `UPDATE relations SET source_id = primaryId WHERE source_id = secondaryId` violates `idx_rel_triplet` if the triplet already exists on primary. Use two-pass: SELECT conflicts → expire them → UPDATE remaining.

**HIGH: Properties JSON merge.** Both entities have a `properties` TEXT field (JSON). Parse both, merge keys (primary wins), write merged result. Currently missing from the plan.

**HIGH: Relation metadata preservation.** When expiring a duplicate relation, compare `confidence` and `weight`. Take the higher values on the surviving relation.

**MEDIUM: Rollback capability.** Bi-temporal expiration preserves an audit trail but is NOT sufficient for automated rollback (no record of previous `source_id`/`target_id` on re-pointed relations). Consider adding a `merged_into_id INTEGER` column to `entities` (nullable, set on secondary). This creates a permanent, queryable trace.

**FTS5 consistency.** The existing triggers on `entities` and `facts` handle all UPDATE/deactivation operations correctly. No manual FTS5 rebuild needed.

**ON DELETE CASCADE.** Will NOT fire because merge uses UPDATE (not DELETE) on entities. Safe.

**Merge semantics for conflicts:**

| Data Type | Conflict Resolution |
|---|---|
| Relations (same triplet on both) | Keep primary's (take higher confidence/weight), expire secondary's |
| Relations (secondary↔primary) | Expire — would create self-referential |
| Facts (same `fact_key` on both) | Keep primary's value, expire secondary's (bi-temporal) |
| Aliases (same alias text) | INSERT OR IGNORE (unique constraint handles it) |
| Properties JSON | Parse both, merge keys (primary wins on conflicts) |
| Embeddings | Set primary's to null (triggers lazy recomputation) |
| `access_count` | Sum both |
| `base_score` | Take max of both |
| `last_accessed` | Take most recent, then set to now |
| `created_at` | Take **earliest** of both (preserve provenance) |
| `valid_at` | Take earliest of both |
| `ingested_at` | Take earliest of both |
| `temperature` | Recalculate from merged `last_accessed` using decay formula |
| `summary` | Concatenate if both non-null, separated by `. ` |
| `summary_nodes.member_ids` | Replace secondaryId with primaryId in JSON arrays |

### Phase 3: KbMaintenanceService

**New file: `lib/core/knowledge/services/kb_maintenance_service.dart`**

Encapsulates the LLM scoring logic, following the `EntityExtractor` pattern:

```dart
class KbMaintenanceService {
  final KnowledgeGraphDB _db;
  final KnowledgeService _knowledgeService;
  final LLMProvider _llmProvider;
  final String _model;

  /// Find duplicate candidates using token blocking + deterministic scoring.
  /// Returns scored pairs sorted by score descending, capped at maxPairs.
  Future<List<DuplicateCandidate>> findCandidates({int maxPairs = 40}) async { ... }

  /// Verify candidates via LLM semantic analysis.
  /// Sends only names/aliases/fact summaries (no raw PII values).
  /// Returns pairs with LLM-adjusted scores and justifications.
  Future<List<ScoredPair>> verifyWithLLM(List<DuplicateCandidate> candidates) async { ... }

  /// Execute merge of secondary into primary.
  Future<MergeResult> merge(int primaryId, int secondaryId) async { ... }
}
```

### Research Insights — LLM Call Safety

- **Validate response IDs**: Reject any entity ID from LLM response not in the set of IDs actually sent. Prevents hallucinated IDs from corrupting the DB.
- **Strict integer parsing**: Parse IDs as `int`. Reject floating-point or string IDs.
- **Fallback on malformed JSON**: Return deterministic-only scores (no LLM upgrade/downgrade). Log error via `AppLogger` with `LogSource.agent`.
- **PII-safe logging**: Log entity IDs and scores, not entity content (which may contain phone numbers, addresses).
- **Cap forUser output length**: Large merge results should be summarized, not dumped verbatim.

### Phase 4: Dream Tool Implementation

**New file: `lib/core/tools/dream_tool.dart`**

**Constructor dependencies** (thin tool, delegates to service):
- `KbMaintenanceService service`
- `String? locale` (for i18n of `forUser` — follows WeatherTool/TransitTool pattern)
- `String? kbLanguage`

**Tool parameters (simplified from original — dropped `auto_merge_level1` and `entity_type`):**

```json
{
  "type": "object",
  "properties": {
    "operation": {
      "type": "string",
      "enum": ["audit", "merge"],
      "description": "audit: analyze KB for duplicates. merge: execute approved merges."
    },
    "full_scan": {
      "type": "boolean",
      "default": false,
      "description": "If true, compare all entities. If false, only entities added since last dream."
    },
    "pairs": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "primary_id": {"type": "integer"},
          "secondary_id": {"type": "integer"}
        },
        "required": ["primary_id", "secondary_id"]
      },
      "description": "Pairs to merge (merge operation only)."
    }
  },
  "required": ["operation"]
}
```

**Audit operation:**
1. Call `service.findCandidates()` — token blocking + deterministic scoring
2. Call `service.verifyWithLLM(candidates)` — LLM semantic verification
3. Format results as `ToolResult.dual()`:
   - `forLLM`: Compact JSON — only `{pairs: [{primary_id, secondary_id, primary_name, secondary_name, score, justification}]}`. No full entity data, no explicit merge instructions.
   - `forUser`: Markdown tables grouped by Level 1/2/3

**Merge operation:**
1. Validate all IDs exist and are active
2. For each pair: call `service.merge(primaryId, secondaryId)`
3. Return `ToolResult.dual()`:
   - `forLLM`: JSON confirming what was merged (names, counts)
   - `forUser`: Summary of merges executed

### Phase 5: Registration & Configuration

**Files to modify:**

| File | Change |
|---|---|
| `lib/core/knowledge/algorithms/string_similarity.dart` | **NEW** — hybrid similarity function |
| `lib/core/knowledge/services/kb_maintenance_service.dart` | **NEW** — LLM scoring + merge orchestration |
| `lib/core/tools/dream_tool.dart` | **NEW** — thin tool dispatcher |
| `lib/providers/app_providers.dart` | Register `DreamTool` via `KbMaintenanceService` (gated on `kgDb != null && kgService != null`) |
| `lib/features/settings/tools_config_screen.dart` | Add toggle with bed/moon icon |
| `lib/core/config/app_config.dart` | Add to `_defaultDisabledTools` (opt-in, like `radio`) |
| `lib/l10n/app_en.arb` | Add `toolDreamName`, `toolDreamDescription` |
| `lib/l10n/app_fr.arb` | French translations |
| `lib/l10n/app_es.arb` | Spanish translations |
| `lib/l10n/app_de.arb` | German translations |
| `lib/l10n/app_it.arb` | Italian translations |
| `CLAUDE.md` | Add `dream` to tool list |
| `README.md` | Update tools table |

**NOT in service isolate**: `dream` requires LLM calls that could be long-running. Excluded from `ServiceAgentFactory` like `subagent`.

### Research Insights — Naming

Multiple reviewers suggest `kb_dream` or `kb_maintain` for consistency with `kb_query`. However, the user explicitly chose `dream` for the metaphor. **Keep `dream`** as the tool name — it is valid snake_case and the description field provides semantic clarity to the LLM. The name is evocative and memorable for the user.

## Performance Considerations

### Scaling Estimates

| Entities per type | Candidate pairs (with blocking) | Scoring time | LLM calls | Total time |
|---|---|---|---|---|
| 50 | ~50-100 | <1s | 1 | 5-15s |
| 100 | ~100-300 | 2-3s | 1-2 | 10-30s |
| 200 | ~200-500 | 5-10s | 2 (capped at 40 pairs) | 15-45s |
| 500 | ~500-1000 | 10-20s | 2 (capped at 40 pairs) | 20-60s |

### Memory Usage

| KB Size | Memory (no embed) | Memory (w/ embed, 768d) |
|---|---|---|
| 100 entities | ~50 KB | ~350 KB |
| 500 entities | ~250 KB | ~1.7 MB |
| 1000 entities | ~500 KB | ~3.4 MB |

Memory is not the bottleneck — fits comfortably in Android app heap.

### Optimizations

- **Batch SQL loads**: Load all aliases/facts in single `WHERE entity_id IN (...)` queries — avoid N+1.
- **Isolate for scoring**: Consider `Isolate.run()` for CPU-intensive pairwise comparison to avoid UI jank. Scoring is pure computation with no DB/channel deps.
- **Process types independently**: Run dedup for PERSON, then PLACE, etc. Naturally bounds per-type N.

## Edge Cases

| Case | Handling |
|---|---|
| Empty KB (0 entities) | Return early: "KB is empty, nothing to analyze" |
| 1 entity | Return early: "Only 1 entity, no pairs to compare" |
| No duplicates found | Return: "No potential duplicates detected" |
| Entities with 0 relations/facts | Name-only scoring. Can reach ~50% with very high string similarity |
| Large KB (>500 entities) | Warn about analysis time; blocking keeps it tractable |
| LLM returns malformed JSON | Log error, fall back to deterministic-only scores |
| LLM returns hallucinated IDs | Validate against sent set, reject unknown IDs |
| Prompt injection via entity name | Sanitize: truncate 100 chars, strip control chars, JSON-encode in prompt |
| Merge of already-merged entity | Check `is_active` before merge, skip with warning |
| Self-referential relation after merge | Expire before re-pointing (step 2 in merge order) |
| Duplicate triplet after merge | Two-pass: identify conflicts, expire, then re-point |
| Conflicting facts after merge | Keep primary's value, expire secondary's with bi-temporal trail |
| Properties JSON on both entities | Parse and merge (primary wins on key conflicts) |
| `summary_nodes.member_ids` stale | Replace secondaryId with primaryId in JSON arrays |
| Multilingual entity names | Trigram overlap handles cross-language; LLM handles semantics |

## Data Safety

1. **Bi-temporal preservation**: Merged entities are deactivated (`is_active = 0, expired_at = now`), not deleted. All expired facts/relations retain their history.
2. **Alias feedback loop**: Secondary entity's name and aliases become aliases of the primary, improving future `EntityResolver` accuracy.
3. **Embedding invalidation**: Primary's embedding set to null after merge, triggering lazy recomputation on next access.
4. **Transaction safety**: Each merge runs in a single SQLite transaction. Failure rolls back completely. Individual merge failures don't block others.
5. **Audit before merge**: The two-operation design ensures the user always sees the report before any data changes.
6. **ID validation**: All entity IDs from LLM response validated against the set of IDs actually sent. Hallucinated IDs rejected.
7. **PII minimization**: Only entity names/aliases sent to LLM for scoring, not raw fact values (phone numbers, addresses).
8. **Merge traceability**: Consider adding `merged_into_id INTEGER` column to entities table for permanent queryable trace (optional, can defer).

## Security Considerations

| Threat | Mitigation |
|---|---|
| Mass PII exfiltration to LLM | Local-first scoring; only names/aliases sent to LLM, not fact values |
| Prompt injection via entity names | Sanitize: truncate 100 chars, strip control chars, JSON-encode in prompt |
| LLM-directed data corruption | Validate IDs against sent set; require name-score floor of 0.70 |
| DoS via LLM call amplification | Cap at 40 pairs, max 2 LLM calls per invocation |
| JSON parsing vulnerabilities | Strict int parsing for IDs; fallback to deterministic on parse failure |
| PII in logs | Log entity IDs and scores only, never entity content |

## Acceptance Criteria

- [x] `StringSimilarity.combined()` in `lib/core/knowledge/algorithms/string_similarity.dart`
- [x] `KbMaintenanceService` in `lib/core/knowledge/services/` with `findCandidates()` and `verifyWithLLM()`
- [x] `KnowledgeGraphDB.mergeEntities()` follows safe 12-step order in a transaction
- [x] Self-referential relations expired before re-pointing
- [x] Unique constraint conflicts handled via two-pass (SELECT conflicts → expire → UPDATE)
- [x] Properties JSON merged (primary wins on key conflicts)
- [x] `dream(operation: "audit")` returns compact forLLM + markdown forUser
- [x] `dream(operation: "merge", pairs: [...])` executes merges and returns summary
- [x] LLM response IDs validated against sent set
- [x] Entity content sanitized before inclusion in LLM prompt
- [x] `forUser` output capped in length
- [x] Merged entities deactivated (not deleted), preserving bi-temporal history
- [x] Secondary entity's name/aliases become aliases of the primary
- [x] Tool is gated on KG being enabled (`kgDb != null`)
- [x] Tool is disabled by default (`_defaultDisabledTools`)
- [x] `locale` parameter for i18n of forUser strings
- [x] i18n: tool name/description in all 5 locales
- [x] Incremental dedup: `last_dream_at` timestamp stored, default mode compares only new entities
- [x] `full_scan: true` compares all entities; `full_scan: false` (default) only since last dream
- [x] Edge cases: empty KB, single entity, no duplicates, malformed LLM response, hallucinated IDs
- [x] `flutter analyze` passes with 0 issues

## Implementation Phases

### Phase 1: Algorithms + Merge Infrastructure (~40%)
- Create `lib/core/knowledge/algorithms/string_similarity.dart` (hybrid similarity)
- Add `mergeEntities()` to `KnowledgeGraphDB` with safe 12-step order
- Handle: self-referential relations, unique constraint two-pass, properties merge, alias INSERT OR IGNORE
- Handle: summary_nodes.member_ids update, relation metadata preservation

### Phase 2: Service + Tool (~45%)
- Create `lib/core/knowledge/services/kb_maintenance_service.dart`
  - Token blocking for candidate generation
  - Embedding pre-filter (when available)
  - Deterministic scoring with `StringSimilarity.combined()`
  - LLM semantic verification with sanitized prompts and ID validation
  - Robust JSON parsing with markdown fence stripping
- Create `lib/core/tools/dream_tool.dart` (thin dispatcher)
- Register in providers, settings, config

### Phase 3: Polish (~15%)
- i18n strings (5 locales)
- Tools config screen toggle
- CLAUDE.md / README updates
- Edge case handling and error messages

## References

### Internal
- Entity schema: `lib/core/knowledge/database/schema.drift`
- Entity resolver (Jaro-Winkler): `lib/core/knowledge/services/entity_resolver.dart`
- KB query tool (operation pattern): `lib/core/tools/knowledge_query_tool.dart`
- Entity extractor (LLM call pattern): `lib/core/knowledge/services/entity_extractor.dart`
- Existing algorithms: `lib/core/knowledge/algorithms/` (memory_decay, spreading_activation, hybrid_scorer, memory_clusterer)
- Tool interface: `lib/core/tools/tool.dart`
- Tool registration: `lib/providers/app_providers.dart`

### Institutional Learnings
- `docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md` — FTS5 tokenization contract, Unicode-aware regex, multilingual stopwords
- `docs/solutions/database-issues/session-data-loss-hive-flush-and-destructive-reads.md` — never mutate in-place during validation, flush after mutations, transaction safety
- `docs/solutions/logic-errors/llm-agent-locale-prompt-engineering.md` — recency bias in prompts, imperative language for format instructions
- `docs/solutions/runtime-errors/gemini-flash-ignores-system-prompt-language-instructions.md` — Flash-class models need multi-layer format enforcement
- `docs/solutions/security-issues/proof-editor-code-review-security-and-robustness-fixes.md` — bounded output, PII-safe logging, optimistic concurrency

### External Research
- [Blocking and Filtering Techniques for Entity Resolution (Survey)](https://arxiv.org/pdf/1905.06167)
- [Entity Resolved Knowledge Graphs (Neo4j)](https://neo4j.com/blog/developer/entity-resolved-knowledge-graphs/)
- [Jaro-Winkler vs Levenshtein for AML Screening](https://www.flagright.com/post/jaro-winkler-vs-levenshtein-choosing-the-right-algorithm-for-aml-screening)
- [String Comparators (Splink)](https://moj-analytical-services.github.io/splink/topic_guides/comparisons/comparators.html)
- [SQLite Atomic Commit](https://sqlite.org/atomiccommit.html)
