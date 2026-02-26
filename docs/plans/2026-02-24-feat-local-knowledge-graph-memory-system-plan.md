---
title: "feat: Local Knowledge Graph Memory System"
type: feat
date: 2026-02-24
---

# Local Knowledge Graph Memory System

## Overview

Add a persistent, structured memory system to DroidClaw based on a local Knowledge Graph (KG). The KG stores entities (people, places, concepts), relations between them, and facts — extracted from conversations by the LLM. It provides cross-session recall, semantic search via on-device embeddings, and automatic memory decay modeling forgetting.

This transforms DroidClaw from a stateless-per-session assistant into one that truly remembers the user across all conversations.

## Problem Statement

Currently, DroidClaw's memory is fragmented across three disconnected systems:
1. **Session history** — per-conversation, lost to summarization after 20 messages
2. **MEMORY.md** — a single flat markdown file, no structure, no search
3. **Daily notes** — chronological entries, no relational querying

The user says "my dentist appointment is March 15" in session A. In session B, the assistant has no memory of this. The user must repeat context or manually maintain MEMORY.md. There is no structured way to answer "what do you know about my schedule?" across all conversations.

## Proposed Solution

A five-layer Knowledge Graph system, all running 100% on-device:

```
+-----------------------------------------------------------+
|                  AGENT / UI LAYER                          |
|  Pre-query: KG query -> inject context into system prompt  |
|  Post-response: LLM extracts entities -> store in KG       |
+-----------------------------------------------------------+
|                  QUERY PIPELINE                            |
|  FTS5 BM25 --+                                            |
|  Vector sim --+--> Score Fusion --> Re-rank --> Top-K      |
|  Graph SA  ---+    (weighted)      (decay)                |
+-----------------------------------------------------------+
|                 INGESTION PIPELINE                         |
|  Conversation text --> LLM extraction --> Entity resolution|
|  --> Relation extraction --> Embedding --> Bi-temporal store|
+-----------------------------------------------------------+
|               BACKGROUND MAINTENANCE                       |
|  Decay recalculation | RAPTOR consolidation | Purge cold   |
|  (via existing FlutterForegroundTask service isolate)      |
+-----------------------------------------------------------+
|                  STORAGE LAYER                             |
|  Drift/SQLite: entities + relations + facts + aliases      |
|  FTS5: entities_fts + facts_fts                            |
|  BLOB: embeddings 384D (Float32)                           |
|  summary_nodes: hierarchical RAPTOR tree                   |
+-----------------------------------------------------------+
```

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Entity extraction | **LLM (via API)** | ~90% accuracy, handles relations and multi-language. Runs async post-response. Cost: 1 extra API call per conversation turn. |
| Embeddings | **V1 with embeddings** | Full semantic search from day one. flutter_embedder for MiniLM L6 V2 (384D, ~33ms). Fallback to custom Kotlin MethodChannel if flutter_embedder proves unstable. |
| Existing memory | **Coexistence** | KG + MEMORY.md coexist. System prompt explains roles: MEMORY.md for user-curated notes, KG for auto-extracted structured knowledge. No migration. |
| Database | **Drift (exception)** | Documented exception to no-codegen policy. Type-safe, FTS5 native in .drift files, reactive queries, WAL multi-isolate. build_runner already in dev_dependencies. |
| Background tasks | **Existing FlutterForegroundTask** | No workmanager. Add KG maintenance as periodic tasks in onRepeatEvent() alongside cron and Telegram. Avoids third FlutterEngine. |
| Dual-isolate DB | **Independent Drift connections + WAL** | shareAcrossIsolates broken across FlutterEngines. Both isolates open DB independently. WAL handles concurrent reads, serialized writes. Manual reload signaling. |
| Embeddings in service isolate | **FTS5 + graph only (no embeddings)** | MethodChannel registered on Activity FlutterEngine is unavailable in service isolate. Service isolate degrades gracefully to BM25 + graph traversal. |

## Technical Approach

### Architecture

#### New Module: `lib/core/knowledge/`

```
lib/core/knowledge/
  database/
    knowledge_graph_db.dart       # Drift database class
    schema.drift                  # FTS5 tables, named queries
  models/
    entity.dart                   # Entity, Relation, Fact data classes
    ranked_result.dart            # Query result with score
  algorithms/
    memory_decay.dart             # Ebbinghaus decay + temperature classification
    spreading_activation.dart     # Graph spreading activation
    memory_clusterer.dart         # DBSCAN clustering for RAPTOR
    hybrid_scorer.dart            # Multi-signal score fusion
  services/
    knowledge_service.dart        # High-level API: query, ingest, maintain
    entity_extractor.dart         # LLM-based extraction (prompt + parsing)
    entity_resolver.dart          # Alias resolution, deduplication
    ingestion_pipeline.dart       # Full text -> KG pipeline
    consolidation_service.dart    # RAPTOR hierarchical summaries
  embeddings/
    embedder_channel.dart         # flutter_embedder wrapper (or Kotlin fallback)
    vector_store.dart             # Cosine similarity search on BLOB embeddings
```

#### Database Schema (Drift + SQLite)

Six tables in `schema.drift`:

1. **entities** — nodes: id, name, entity_type, summary, embedding (BLOB 384D Float32), bi-temporal timestamps (created_at, valid_at, invalid_at, ingested_at, expired_at), decay fields (last_accessed, access_count, temperature, base_score), RAPTOR parent link, is_active
2. **relations** — edges: source_id, target_id, predicate, weight, confidence, embedding, bi-temporal, source_text provenance
3. **facts** — key-value per entity: entity_id, key, value, value_type, bi-temporal, confidence
4. **aliases** — fuzzy entity resolution: entity_id, alias_name (NOCASE), alias_type, confidence
5. **summary_nodes** — RAPTOR hierarchy: parent_id, level, summary_text, embedding, member_ids (JSON array)
6. **entities_fts** / **facts_fts** — FTS5 virtual tables with `porter unicode61` tokenizer, content-synced via triggers

Key indexes: entity type, temperature, valid_at range, active+temperature composite, relation source/target (partial: is_active=1), unique triplet (source, predicate, target where active and not expired), unique fact (entity_id, key where not expired).

Drift configuration in `build.yaml`:
```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          sql:
            dialect: sqlite
            options:
              version: "3.50"
              modules:
                - fts5
                - json1
```

PRAGMA settings on open: `foreign_keys = ON`, `journal_mode = WAL`, `busy_timeout = 5000`.

#### Provider Integration

New providers in `app_providers.dart`:

```
appConfigProvider
  |
  +--> knowledgeGraphDbProvider (FutureProvider<KnowledgeGraphDB?>)
  |      |  null if KG disabled in config
  |      |
  |      +--> knowledgeServiceProvider (FutureProvider<KnowledgeService?>)
  |      |      |  wraps DB + embedder + algorithms
  |      |      |
  |      |      +--> contextBuilderProvider (modified: receives KnowledgeService)
  |      |      |
  |      |      +--> toolRegistryProvider (modified: registers KG tools)
  |      |
  |      +--> agentLoopProvider (modified: receives KnowledgeService for hooks)
```

#### Agent Loop Modifications

**Pre-query hook** — `AgentLoop.processMessage()`:
- Before building the LLM messages, if `knowledgeService != null`:
  - Call `knowledgeService.queryRelevant(userMessage, limit: 10)`
  - Build a `<knowledge_context>...</knowledge_context>` XML block
  - Inject into system prompt (new section in ContextBuilder)
  - Touch retrieved entities (reinforcement)
- **ContextBuilder change**: Add `buildKnowledgeContext(String userQuery, KnowledgeService kg)` method that returns formatted XML. Called from AgentLoop, result passed to `buildSystemPrompt(knowledgeContext:)` as an optional String parameter. This avoids coupling ContextBuilder directly to KnowledgeService.

**Post-response hook** — `AgentLoop.processMessage()`:
- After yielding the final `ResponseEvent` and saving session, if `knowledgeService != null`:
  - Fire-and-forget async: `knowledgeService.extractAndStore(userMessage, assistantResponse)`
  - Do NOT block the stream — extraction runs in background
  - On failure, log warning via AppLogger, do not surface to user

#### Extraction Pipeline (LLM-based)

`EntityExtractor` sends a structured extraction prompt to the same LLM provider:

```
Extract entities, relations, and facts from this conversation turn.
Return JSON: {
  "entities": [{"name": "...", "type": "PERSON|PLACE|ORG|EVENT|CONCEPT|DATE", "summary": "..."}],
  "relations": [{"source": "...", "predicate": "WORKS_AT|KNOWS|LIVES_IN|...", "target": "...", "confidence": 0.9}],
  "facts": [{"entity": "...", "key": "...", "value": "...", "type": "string|number|date"}]
}
Only extract clearly stated information. Do not infer or hallucinate.
```

The extractor:
1. Calls LLM with extraction prompt + conversation text
2. Parses JSON response
3. For each entity: runs `EntityResolver.resolve()` — checks aliases table (exact NOCASE), then FTS5 fuzzy search + Jaro-Winkler > 0.88, creates alias if matched
4. For each new entity: inserts with embedding, creates initial alias
5. For each relation: upserts bi-temporally (close old, insert new if changed)
6. For each fact: upserts bi-temporally

#### Hybrid Query Pipeline

`KnowledgeService.queryRelevant(query, limit)`:

1. **FTS5 BM25** — `SELECT e.*, -bm25(entities_fts, 5.0, 2.0, 1.0) AS rank` with MATCH, limit 3x
2. **Vector similarity** — embed query text, cosine similarity against entity embeddings (BLOB Float32), limit 3x. **Skip in service isolate** (no embedder).
3. **Union candidates** — merge IDs from both sources
4. **Load subgraph** — 2-hop neighbors from relations table
5. **Spreading activation** — seeds from top BM25 + top vector results, decay factor 0.85, max 4 iterations
6. **Score fusion** — `0.30 * bm25_norm + 0.30 * vector_norm + 0.25 * activation + 0.15 * decay_score`
7. **Sort + top-K** — return ranked entities with attached facts and relations

Result formatted as XML for system prompt injection (max 2000 characters):
```xml
<knowledge_context>
  <entity name="Marie" type="PERSON">
    <fact key="role">dentist</fact>
    <fact key="next_appointment">2026-03-15</fact>
    <relation predicate="WORKS_AT" target="Cabinet Dentaire République"/>
  </entity>
</knowledge_context>
```

#### Memory Decay (Ebbinghaus)

- Formula: `R = e^(-t/S)` where `S = baseStability * (1 + 1.5 * ln(accessCount + 1))`
- Base stability: 86400 seconds (1 day)
- Temperature classification: Hot >= 0.7, Warm >= 0.4, Cool >= 0.1, Cold < 0.1
- Batch recalculation: runs in service isolate every hour via `onRepeatEvent()`
- Cold entities: eligible for purge after 30 days
- Accessing an entity via query resets `last_accessed` and increments `access_count` (reinforcement)

SQLite doesn't have EXP/LN natively — calculation done in Dart batch: load all active entities, compute scores, batch update temperatures.

#### Background Maintenance (in existing service isolate)

Add to `BackgroundTaskHandler.onRepeatEvent()`:

| Task | Frequency | Conditions | Description |
|------|-----------|------------|-------------|
| Decay batch | Every hour (~3600 iterations) | Always | Recalculate all entity temperatures |
| RAPTOR consolidation | Every 6 hours (~21600 iterations) | > 50 warm/cool unclustered entities | DBSCAN cluster -> extractive summary -> summary_nodes |
| Purge | Every 24 hours (~86400 iterations) | Always | Delete cold entities > 30 days, cap at 100K entities |

The service isolate opens its own Drift connection (WAL mode). No embedder needed for maintenance — it operates on existing data.

#### Tools

**`knowledge_search`** — query the KG:
- Parameters: `{"query": "string", "limit": "int (optional, default 10)"}`
- Calls `knowledgeService.queryRelevant()`
- Returns `ToolResult.dual(forLLM: structured JSON, forUser: readable summary)`
- Registered in both main isolate and ServiceAgentFactory (degraded: no embeddings in service)

**`knowledge_store`** — explicitly store a fact:
- Parameters: `{"entity": "string", "key": "string", "value": "string", "type": "string (optional)"}`
- Creates/resolves entity, inserts fact bi-temporally
- Returns `ToolResult.dual(forLLM: "Stored: entity.key = value", forUser: localized confirmation)`
- Registered in both isolates

Both disabled by default (added to `_defaultDisabledTools`).

#### Embeddings Architecture

**Primary**: `flutter_embedder` v0.1.7 wrapping MiniLM L6 V2 (ONNX, 384D, ~90MB, ~33ms):
- Initialized lazily on first KG operation
- Model bundled as Flutter asset (lazy-loaded from assets to temp dir on first use)
- `EmbedderChannel` class wraps flutter_embedder API

**Fallback** (if flutter_embedder proves unstable): Custom Kotlin MethodChannel:
- `KnowledgeEmbedderPlugin.kt` registered in `MainActivity.configureFlutterEngine()`
- Wraps ONNX Runtime Java API + HuggingFace tokenizer
- Same pattern as `RadioPlayerPlugin.kt` / `AudioChannelPlugin.kt`

**Service isolate**: No embedder available (MethodChannel on Activity FlutterEngine only). Hybrid query falls back to FTS5 + graph traversal (BM25 * 0.55 + activation * 0.30 + decay * 0.15).

#### Settings & Configuration

New in `AppConfig`:
- `knowledge.enabled` (bool, default false — disabled by default)
- `knowledge.maxEntities` (int, default 100000)
- `knowledge.decayHalfLifeDays` (int, default 30)
- `knowledge.autoExtract` (bool, default true — auto post-response extraction)

New settings screen: `lib/features/settings/knowledge_config_screen.dart`
- Enable/disable toggle
- Stats display: entity count, relation count, DB size on disk
- "Forget Everything" button (with confirmation dialog)
- Route: `/settings/knowledge`
- ListTile in settings_screen.dart in Tools section

### Implementation Phases

#### Phase 1: Storage Layer + CRUD (Foundation)

**Tasks:**
- [x] Add Drift dependencies to `pubspec.yaml` (`drift`, `drift_dev`, `drift_flutter`, `sqlite3_flutter_libs`)
- [x] Create `lib/core/knowledge/database/schema.drift` with all 6 tables, indexes, triggers, named queries
- [x] Create `lib/core/knowledge/database/knowledge_graph_db.dart` — Drift database class with migration strategy, WAL pragma
- [x] Create entity/relation/fact model classes in `lib/core/knowledge/models/` (manual `fromJson`/`toJson` for non-Drift contexts)
- [x] Configure `build.yaml` for FTS5 + JSON1 modules
- [x] Run `dart run build_runner build` and commit generated files
- [x] Create `knowledgeGraphDbProvider` in `app_providers.dart` (null when disabled)
- [x] Add `knowledge.enabled` to `AppConfig`
- [x] Update `constants.dart` with KG constants (DB filename, default params)
- [ ] Verify Drift DB opens in both isolates independently (WAL mode test)

**Success criteria:** Can create, read, update, delete entities/relations/facts via Drift. FTS5 MATCH queries work. DB opens cleanly in both isolates.

#### Phase 2: Algorithms + Query Pipeline

**Tasks:**
- [x] Implement `MemoryDecay` class (`lib/core/knowledge/algorithms/memory_decay.dart`): retention formula, stability, activation score, temperature classification, batch decay
- [x] Implement `SpreadingActivation` class: BFS-like propagation with decay factor, firing threshold, max iterations
- [x] Implement `MemoryClusterer` class: DBSCAN on cosine distance of embeddings
- [x] Implement `HybridScorer` class: normalize + fuse BM25/vector/activation/decay scores
- [x] Implement `KnowledgeService.queryRelevant()` — full hybrid query pipeline (FTS5-only mode for now, vector added in Phase 4)
- [x] Implement `EntityResolver` — alias resolution + Jaro-Winkler fuzzy matching

**Success criteria:** Given seeded test data, hybrid query returns ranked entities. Decay batch correctly reclassifies temperatures.

#### Phase 3: Ingestion Pipeline + Agent Hooks

**Tasks:**
- [x] Implement `EntityExtractor` — LLM prompt for structured extraction, JSON parsing
- [x] Implement `IngestionPipeline` — full flow: extract -> resolve -> store bi-temporally
- [x] Modify `AgentLoop.processMessage()`:
  - Pre-query: if KnowledgeService available, query + inject context
  - Post-response: fire-and-forget async extraction
- [x] Modify `ContextBuilder`:
  - Add `buildSystemPrompt({String? knowledgeContext})` optional parameter
  - Add system prompt section explaining KG vs MEMORY.md coexistence
- [x] Create `knowledge_search` tool (`lib/core/tools/knowledge_search_tool.dart`)
- [x] Create `knowledge_store` tool (`lib/core/tools/knowledge_store_tool.dart`)
- [x] Register tools in `toolRegistryProvider` and `ServiceAgentFactory`
- [x] Add tool toggles in `tools_config_screen.dart`
- [x] Wire `KnowledgeService` into provider cascade

**Success criteria:** User chats, entities are extracted and stored. Next conversation turn shows relevant KG context in system prompt. LLM can call knowledge_search and knowledge_store tools.

#### Phase 4: On-Device Embeddings

**Tasks:**
- [ ] Add `flutter_embedder: ^0.1.7` to `pubspec.yaml`
- [ ] Bundle MiniLM L6 V2 ONNX model as Flutter asset (~90MB)
- [ ] Create `EmbedderChannel` wrapper (`lib/core/knowledge/embeddings/embedder_channel.dart`)
- [ ] Implement lazy initialization (first KG operation triggers model load)
- [ ] Implement `VectorStore` — cosine similarity search on BLOB embeddings
- [ ] Generate embeddings during ingestion (entity name + summary)
- [ ] Generate query embedding during hybrid query
- [ ] Enable vector similarity signal in `HybridScorer` (previously FTS5-only)
- [ ] Handle service isolate graceful degradation (no embedder -> skip vector signal, adjust weights)
- [ ] If flutter_embedder fails: implement Kotlin MethodChannel fallback (`KnowledgeEmbedderPlugin.kt`)

**Success criteria:** Semantic queries ("where do I need to go next week?") retrieve relevant entities even without exact keyword match.

#### Phase 5: Background Maintenance + Consolidation

**Tasks:**
- [x] Add KG maintenance tasks to `BackgroundTaskHandler.onRepeatEvent()`:
  - Decay batch (hourly counter)
  - Purge cold entities (24h counter)
- [ ] Implement `ConsolidationService.runRaptorConsolidation()` (deferred — RAPTOR consolidation is complex and premature at this stage)
- [x] Initialize KG DB in service isolate (`background_task_handler.dart`)
- [x] Cache KG enabled flag in SharedPreferences for service isolate (`_cacheSecretsForService()`)
- [x] Add service isolate KG path derivation (use workspace path, NOT nested app_flutter!)
- [x] Register KG tools in `ServiceAgentFactory` (degraded mode: FTS5 + graph only)
- [x] Wire KnowledgeService into service isolate AgentLoop

**Success criteria:** After 24h of use, cold entities are purged, temperatures reflect access patterns.

#### Phase 6: Settings UI + i18n

**Tasks:**
- [x] Create `lib/features/settings/knowledge_config_screen.dart`:
  - Enable/disable toggle
  - Auto-extract toggle
  - Stats: entity count, relation count, DB size
  - "Forget Everything" button with confirmation
- [x] Add route `/settings/knowledge` in `app.dart`
- [x] Add ListTile in `settings_screen.dart` (Tools section, with brain icon)
- [x] Add `knowledge_search` and `knowledge_store` to `_defaultDisabledTools` in `app_config.dart`
- [x] Add ~20 ARB keys across 5 locales (EN/FR/ES/DE/IT)
- [x] Add tool descriptions in all ARB files

**Success criteria:** User can enable/disable KG, see stats, forget all knowledge. All strings localized in 5 languages.

## Alternative Approaches Considered

1. **sqflite instead of Drift** — More consistent with no-codegen policy, but FTS5 support is weaker, no typed queries, no reactive `.watch()`. Drift's developer (Simon Binder) actively maintains FTS5 support in `.drift` files.

2. **No embeddings in v1** — Simpler, but the user chose full semantic search from day one. FTS5-only misses semantic matches ("my schedule" wouldn't match "dentist appointment March 15").

3. **workmanager for background tasks** — Would create a third FlutterEngine, conflicting with existing FlutterForegroundTask. Rejected.

4. **On-device NER extraction** — Faster and cheaper but ~60-70% accuracy. The user chose LLM extraction for quality.

5. **KG replaces MEMORY.md** — Cleaner long-term but requires migration and loses user-curated notes. The user chose coexistence.

## Acceptance Criteria

### Functional Requirements

- [ ] Entities, relations, and facts are automatically extracted from conversations via LLM
- [ ] KG context is injected into system prompt before each agent turn
- [ ] `knowledge_search` tool returns ranked results via hybrid query
- [ ] `knowledge_store` tool allows explicit fact storage
- [ ] Semantic search via embeddings finds entities without exact keyword match
- [ ] Memory decay correctly classifies entities as hot/warm/cool/cold
- [ ] Cross-session knowledge: facts from session A are available in session B
- [ ] Service isolate (cron) can query KG with degraded capabilities (no embeddings)
- [ ] KG can be enabled/disabled in settings without data loss
- [ ] "Forget Everything" deletes all KG data
- [ ] MEMORY.md and KG coexist — system prompt explains both

### Non-Functional Requirements

- [ ] Hybrid query returns results in < 200ms (FTS5 + graph, no embedding)
- [ ] Hybrid query returns results in < 500ms (with embedding similarity)
- [ ] Extraction does not block user response (async fire-and-forget)
- [ ] DB size stays under 50MB for 10K entities
- [ ] APK size increase < 100MB (MiniLM model + SQLite)
- [ ] Cold start: KG DB opens in < 500ms, embedding model loads lazily
- [ ] WAL mode handles concurrent access from two FlutterEngines without corruption

### Quality Gates

- [ ] `flutter analyze` — 0 issues
- [ ] `dart run build_runner build` succeeds with Drift code generation
- [ ] Manual test: chat 10 turns, verify entities extracted, query returns them
- [ ] Manual test: service isolate cron accesses KG (degraded mode)
- [ ] Manual test: disable KG, verify graceful degradation (no crashes, no context injection)

## Dependencies & Prerequisites

| Dependency | Version | Purpose | Risk |
|------------|---------|---------|------|
| drift | ^2.31.0 | ORM + FTS5 + typed queries | Low — production-proven |
| drift_dev | ^2.31.0 | Code generation | Low |
| drift_flutter | ^0.2.8 | Flutter integration + NativeDatabase | Low |
| sqlite3_flutter_libs | ^0.5.41 | Native SQLite with FTS5 | Low — NOT v0.6.0 (obsolete) |
| flutter_embedder | ^0.1.7 | On-device MiniLM embeddings | **High** — 1 GitHub star, unverified publisher |
| MiniLM L6 V2 model | ONNX | 384D embeddings, ~90MB | Medium — bundled as asset |

No new Android permissions. No new foreground service types. No API keys needed.

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| flutter_embedder unstable or breaks | High | High | Fallback: Kotlin MethodChannel wrapping ONNX Runtime Java (pattern: RadioPlayerPlugin.kt) |
| LLM extraction hallucinates facts | Medium | High | Extraction prompt demands "only clearly stated information". User can "Forget Everything". V2: confidence scoring + user review. |
| APK size > 130MB with model | Medium | Medium | Lazy-load model from assets to temp dir. Consider on-demand download in v2. |
| Drift shareAcrossIsolates broken for dual FlutterEngine | Known | Medium | Independent connections + WAL mode. Same pattern as Hive (already proven). |
| System prompt exceeds token budget with KG context | Medium | Medium | Hard cap: max 2000 chars for KG context. Summarize if needed. |
| SQLite DB path mismatch between isolates | Medium | High | Learned lesson: derive from workspacePath, never nest app_flutter. Test empirically. |
| Extraction doubles API cost | Certain | Low | One extra call per turn. Disable auto-extract if user wants to save costs. |

## Future Considerations

- **v2: User KG browser** — visual graph explorer showing entities and relations
- **v2: Confidence scoring** — flag low-confidence extractions for user review
- **v2: On-demand model download** — don't bundle 90MB in APK, download on first enable
- **v2: knowledge_forget tool** — LLM-initiated deletion of specific entities
- **v2: Conversation-aware extraction** — only extract from user messages (not cron/telegram)
- **v2: ObjectBox HNSW** — replace brute-force cosine with HNSW index for > 50K entities
- **v2: Multi-engine stream sync** — when Drift fixes cross-FlutterEngine shareAcrossIsolates

## Files Modified (Estimated)

### New Files (~20)

| File | Description |
|------|-------------|
| `lib/core/knowledge/database/schema.drift` | SQLite schema with FTS5, triggers, named queries |
| `lib/core/knowledge/database/knowledge_graph_db.dart` | Drift database class |
| `lib/core/knowledge/models/entity.dart` | Entity, Relation, Fact data classes |
| `lib/core/knowledge/models/ranked_result.dart` | Query result with composite score |
| `lib/core/knowledge/algorithms/memory_decay.dart` | Ebbinghaus decay + temperature |
| `lib/core/knowledge/algorithms/spreading_activation.dart` | Graph SA algorithm |
| `lib/core/knowledge/algorithms/memory_clusterer.dart` | DBSCAN for RAPTOR |
| `lib/core/knowledge/algorithms/hybrid_scorer.dart` | Score fusion |
| `lib/core/knowledge/services/knowledge_service.dart` | High-level KG API |
| `lib/core/knowledge/services/entity_extractor.dart` | LLM extraction |
| `lib/core/knowledge/services/entity_resolver.dart` | Alias + fuzzy matching |
| `lib/core/knowledge/services/ingestion_pipeline.dart` | Text -> KG flow |
| `lib/core/knowledge/services/consolidation_service.dart` | RAPTOR consolidation |
| `lib/core/knowledge/embeddings/embedder_channel.dart` | flutter_embedder wrapper |
| `lib/core/knowledge/embeddings/vector_store.dart` | Cosine similarity search |
| `lib/core/tools/knowledge_search_tool.dart` | knowledge_search tool |
| `lib/core/tools/knowledge_store_tool.dart` | knowledge_store tool |
| `lib/features/settings/knowledge_config_screen.dart` | KG settings UI |
| `build.yaml` | Drift FTS5 + JSON1 config |

### Modified Files (~12)

| File | Change |
|------|--------|
| `pubspec.yaml` | Add drift, sqlite3_flutter_libs, flutter_embedder |
| `lib/core/config/app_config.dart` | Add knowledge config block + _defaultDisabledTools |
| `lib/shared/constants.dart` | Add KG constants |
| `lib/core/agent/agent_loop.dart` | Pre-query hook + post-response extraction |
| `lib/core/agent/context_builder.dart` | Add knowledgeContext parameter to buildSystemPrompt() |
| `lib/core/agent/service_agent_factory.dart` | Initialize KG DB, register KG tools |
| `lib/core/services/background_task_handler.dart` | Add KG maintenance periodic tasks |
| `lib/providers/app_providers.dart` | Add KG providers, wire into cascade |
| `lib/providers/background_service_provider.dart` | Cache KG enabled flag |
| `lib/features/settings/settings_screen.dart` | Add KG ListTile |
| `lib/features/settings/tools_config_screen.dart` | Add KG tool entries |
| `lib/app.dart` | Add /settings/knowledge route |
| All 5 `lib/l10n/app_*.arb` files | ~25 new keys each |

## References & Research

### Internal References

- Agent loop: `lib/core/agent/agent_loop.dart` — processMessage() entry point
- Context builder: `lib/core/agent/context_builder.dart` — buildSystemPrompt()
- Memory manager: `lib/core/agent/memory_manager.dart` — getMemoryContext()
- Tool interface: `lib/core/tools/tool.dart` — Tool abstract class
- Tool registration: `lib/providers/app_providers.dart:95` — toolRegistryProvider
- Service agent: `lib/core/agent/service_agent_factory.dart` — ServiceAgentFactory.create()
- Background handler: `lib/core/services/background_task_handler.dart` — onRepeatEvent()
- MethodChannel pattern: `android/.../RadioPlayerPlugin.kt`, `AudioChannelPlugin.kt`

### Institutional Learnings

- `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md` — Never nest app_flutter path
- `docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md` — Queue before IPC
- `docs/solutions/architecture/enable-location-tools-in-service-isolate.md` — Service isolate capabilities

### External References

- Drift documentation: https://drift.simonbinder.eu/
- Drift FTS5 support: https://drift.simonbinder.eu/sql_api/extensions/
- Drift cross-isolate discussion: https://github.com/simolus3/drift/discussions/3249
- flutter_embedder: https://pub.dev/packages/flutter_embedder
- MiniLM L6 V2 model: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- Graphiti bi-temporal model: https://github.com/getzep/graphiti
- RAPTOR hierarchical summarization: https://arxiv.org/abs/2401.18059
