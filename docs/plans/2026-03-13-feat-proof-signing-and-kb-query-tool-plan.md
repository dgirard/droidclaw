---
title: "feat: Add ProofEditor HTTP signing header and kb_query tool"
type: feat
date: 2026-03-13
deepened: 2026-03-13
---

## Enhancement Summary

**Deepened on:** 2026-03-13
**Sections enhanced:** 6
**Research agents used:** agent-native-reviewer, security-sentinel, performance-oracle, Drift/SQLite explorer, ProofEditor code explorer

### Key Improvements
1. **CRITICAL: Entity type casing fix** — DB stores UPPERCASE (`PERSON`, `ORG`), plan had lowercase. Must use DB vocabulary.
2. **SQL bug fix** — Plan used `f.is_active = 1` but facts table uses `f.expired_at IS NULL`
3. **Rename `search` to `name_filter`** to avoid confusion with `knowledge_search` tool
4. **Max limit capped to 50** (was 100) to protect LLM context window
5. **Use correlated subquery** for fact_count (not LEFT JOIN + GROUP BY) — matches existing pattern
6. **FTS5 must drive scan** when search is provided — join direction matters
7. **Strip sourceText/embedding** from tool output for security

### Critical Bugs Found in Original Plan
- Entity type enum `"organization"` → DB stores `"ORG"` (would silently return 0 results)
- `f.is_active = 1` in SQL → facts table has no `is_active` column (would crash)

---

# Add ProofEditor HTTP Signing Header and kb_query Tool

## Overview

Two independent features:

1. **ProofEditor HTTP signing** — Add a consistent `X-DroidClaw-App: droidclaw` identification header to ALL ProofEditor API requests. Currently some endpoints have `X-Agent-Id` but `_create` has nothing.

2. **kb_query tool** — New dedicated tool for structured Knowledge Base browsing via natural language. Complements `knowledge_search` (semantic/FTS hybrid) with exact filters: list all entities, filter by type/temperature/date, get entity detail, get KB stats.

## Feature 1: ProofEditor HTTP Signing Header

### Problem Statement

ProofEditor HTTP requests lack consistent caller identification. The `_create` endpoint (`POST /share/markdown`) sends no headers at all. Other endpoints use `X-Agent-Id` but this isn't universal.

### Proposed Solution

Add a `_baseHeaders` map to the 3 HTTP helper methods (`_postJson`, `_putJson`, `_getWithRetry`) that always includes `X-DroidClaw-App: droidclaw`. This guarantees coverage of all current and future endpoints.

### Research Insights

**Security Assessment (security-sentinel):**
- Static header is **acceptable for identification** — not authentication. ProofEditor already uses per-document Bearer tokens for actual auth.
- HMAC signing would require embedding a secret in the APK (easily extractable via decompilation). Complexity-to-benefit ratio is poor.
- No changes needed to the plan approach.

**Pre-existing concern:** Token passed as URL query parameter on `/ops` endpoints (rewrite, comment, suggest, prepend). Query params can appear in server/proxy logs. Accepted risk (ProofEditor API design choice).

### Implementation

#### `lib/core/tools/proof_editor_tool.dart`

**Current code** (lines 1043-1096):
```dart
// _postJson — no base headers, only Content-Type + caller headers
Future<http.Response> _postJson(http.Client client, Uri uri,
    {Map<String, String>? headers, required Map<String, dynamic> body}) async {
  return client.post(uri,
    headers: {'Content-Type': 'application/json', ...?headers},
    body: jsonEncode(body));
}
// _putJson — same pattern
// _getWithRetry — passes headers directly to client.get
```

**After:**
```dart
// Add private getter for base headers (near line 1038)
Map<String, String> get _baseHeaders => {
  'X-DroidClaw-App': _agentId,  // 'droidclaw'
};

// _postJson — merge base headers first, then Content-Type, then caller headers
Future<http.Response> _postJson(http.Client client, Uri uri,
    {Map<String, String>? headers, required Map<String, dynamic> body}) async {
  return client.post(uri,
    headers: {..._baseHeaders, 'Content-Type': 'application/json', ...?headers},
    body: jsonEncode(body));
}

// _putJson — same merge pattern
Future<http.Response> _putJson(http.Client client, Uri uri,
    {Map<String, String>? headers, required Map<String, dynamic> body}) async {
  return client.put(uri,
    headers: {..._baseHeaders, 'Content-Type': 'application/json', ...?headers},
    body: jsonEncode(body));
}

// _getWithRetry — merge base headers with caller headers
Future<http.Response> _getWithRetry(http.Client client, Uri uri,
    {Map<String, String>? headers}) async {
  final mergedHeaders = {..._baseHeaders, ...?headers};
  for (var attempt = 0; attempt <= _maxRetries; attempt++) {
    final response = await client.get(uri, headers: mergedHeaders);
    // ... retry logic unchanged ...
  }
}
```

### Acceptance Criteria

- [x] All ProofEditor HTTP requests include `X-DroidClaw-App: droidclaw` header
- [x] `_create` endpoint now has identification (was missing)
- [x] Existing `X-Agent-Id` and `Authorization` headers preserved (caller headers override base)
- [ ] Unit tests verify header presence on all request types

---

## Feature 2: kb_query Tool

### Problem Statement

Users want to browse and inspect their Knowledge Base in natural language: "donne moi toutes les entités", "les entités créées aujourd'hui", "les entités chaudes", "les entités accédées récemment". The existing `knowledge_search` tool does semantic/FTS hybrid search — it finds relevant content but can't enumerate, filter, or inspect the KB structure.

### Tool Design

**Name:** `kb_query`
**Description:** "Browse and inspect the Knowledge Base. List entities with filters (type, temperature, date range), get entity details with facts and relations, get KB statistics. Use this for structured queries like 'show all people' or 'what's in my KB'. For finding relevant information by topic, use knowledge_search instead."

### Research Insights

**Agent-native review (CRITICAL findings):**

1. **Entity type enum must use UPPERCASE matching DB** — DB stores `PERSON`, `PLACE`, `ORG`, `EVENT`, `CONCEPT`, `DATE`. The `knowledge_store` tool also uses UPPERCASE. Using lowercase would cause silent zero-result filters.

2. **Rename `search` to `name_filter`** — A `search` parameter on `kb_query` overlaps confusingly with `knowledge_search`. Rename to `name_filter` and clarify it's a name/summary substring filter, not relevance search.

3. **`entity_name` lookup should include disambiguation** — When resolving by name, include match context in forLLM: "Resolved 'Martin' to entity 42: 'Dr. Martin' (PERSON). If wrong, use entity_id."

4. **`delete` operation gap** — UI can delete entities but agent cannot. Add note in tool description: "This tool is read-only. To delete entities, use the Knowledge settings screen."

**SQL bug fix:**
- Facts table has NO `is_active` column. Use `f.expired_at IS NULL` (existing pattern in all DB queries).

**Performance review:**
- At 50-2000 entities, ALL queries complete in <5ms. No indexes needed on `created_at`/`last_accessed`.
- Use **correlated subquery** for fact_count (existing pattern), NOT LEFT JOIN + GROUP BY.
- **FTS5 must drive the scan** when search is provided (`FROM entities_fts JOIN entities`, not reverse).
- Stats don't need caching — GROUP BY on 2000 rows is sub-millisecond.
- **Cap limit to 50** (not 100) — 100 entities x ~100 bytes each = 10KB+ in LLM context.

**Security review:**
- Clamp `limit` to hard max 50 in tool execute().
- Strip `sourceText` from facts and `embedding` from entities in tool output.
- Sanitize error messages: `ToolResult.error('Knowledge query failed.')`, log full error internally.
- Validate enum values (type, temperature) against known values before SQL.
- Add 500-char limit on `entity_name` parameter.

**Parameters (JSON Schema):**

```json
{
  "type": "object",
  "properties": {
    "operation": {
      "type": "string",
      "enum": ["list", "detail", "stats"],
      "description": "list: browse entities with filters. detail: full entity with facts/relations. stats: KB overview."
    },
    "entity_id": {
      "type": "integer",
      "description": "Entity ID for detail operation"
    },
    "entity_name": {
      "type": "string",
      "description": "Entity name for detail operation (alternative to entity_id, does best-match lookup). Max 500 chars."
    },
    "type": {
      "type": "string",
      "enum": ["PERSON", "PLACE", "ORG", "EVENT", "CONCEPT", "DATE"],
      "description": "Filter by entity type (UPPERCASE, matching knowledge_store)"
    },
    "temperature": {
      "type": "string",
      "enum": ["hot", "warm", "cool", "cold"],
      "description": "Filter by memory temperature (hot=frequently accessed, cold=rarely accessed)"
    },
    "name_filter": {
      "type": "string",
      "description": "Filter entities whose name or summary contains this text. For relevance-ranked search, use knowledge_search instead."
    },
    "created_after": {
      "type": "string",
      "description": "ISO 8601 date, e.g. 2026-03-01. Only entities created after this date."
    },
    "created_before": {
      "type": "string",
      "description": "ISO 8601 date, e.g. 2026-03-13. Only entities created before this date."
    },
    "accessed_after": {
      "type": "string",
      "description": "ISO 8601 date, e.g. 2026-03-01. Only entities accessed after this date."
    },
    "sort_by": {
      "type": "string",
      "enum": ["last_accessed", "created_at", "access_count", "name"],
      "description": "Sort order. Default: last_accessed"
    },
    "limit": {
      "type": "integer",
      "description": "Max results (default 20, max 50)"
    },
    "offset": {
      "type": "integer",
      "description": "Pagination offset"
    }
  },
  "required": ["operation"]
}
```

### Operations

#### `list` — Browse entities with filters

All filters use AND semantics. Returns compact entity summaries (no full summaries — save those for `detail`).

**forLLM format:**
```json
{
  "total": 347,
  "offset": 0,
  "limit": 20,
  "has_more": true,
  "entities": [
    {"id": 42, "name": "Dr. Martin", "type": "PERSON", "temperature": "hot", "fact_count": 12, "created": "2026-03-01", "last_accessed": "2026-03-13"}
  ]
}
```

**forUser format:** Readable table with counts.

#### `detail` — Full entity with facts, relations, aliases

Accepts `entity_id` (int) or `entity_name` (string, best-match via FTS).

When using `entity_name`, include disambiguation in forLLM: `"resolved": "Matched 'Martin' → entity 42: 'Dr. Martin' (PERSON)"`.

Calls `KnowledgeService.getEntityDetail(entityId)`. Touches the entity (updates last_accessed). Strips `sourceText` from facts and `embedding` from entity.

**forLLM format:**
```json
{
  "resolved": "Matched 'Martin' → entity 42: 'Dr. Martin' (PERSON)",
  "entity": {"id": 42, "name": "Dr. Martin", "type": "PERSON", "temperature": "hot", "summary": "..."},
  "facts": [{"key": "profession", "value": "doctor"}],
  "relations": [{"type": "works_at", "target": "Hôpital Saint-Louis", "target_id": 15}],
  "aliases": ["Martin", "Dr Martin"]
}
```

#### `stats` — KB overview

Returns entity/relation counts, breakdown by type and temperature. Uses the DB's UPPERCASE type labels.

**forLLM format:**
```json
{
  "entity_count": 347,
  "relation_count": 512,
  "by_type": {"PERSON": 42, "PLACE": 15, "CONCEPT": 290},
  "by_temperature": {"hot": 30, "warm": 100, "cool": 150, "cold": 67}
}
```

### Backend Changes Required

#### Phase 1: KnowledgeGraphDB — Combined filter query

**File:** `lib/core/knowledge/database/knowledge_graph_db.dart`

Add a single composable query method. Key patterns from codebase research:
- Use `customSelect()` with `Variable.withString()` / `Variable.withInt()` (Drift 2.31 API)
- Use **correlated subquery** for fact_count (existing pattern at line 227), NOT LEFT JOIN + GROUP BY
- FTS5 must be the driving table when `name_filter` is provided

```dart
/// List entities with combined AND filters.
Future<List<Map<String, dynamic>>> listEntitiesFiltered({
  String? type,
  String? temperature,
  String? search,        // FTS5 name_filter
  int? createdAfter,     // Unix epoch seconds
  int? createdBefore,
  int? accessedAfter,
  String sortBy = 'last_accessed',
  int limit = 20,
  int offset = 0,
}) async {
  final conditions = <String>['e.is_active = 1'];
  final vars = <Variable>[];
  if (type != null) {
    conditions.add('e.entity_type = ?');
    vars.add(Variable.withString(type));
  }
  if (temperature != null) {
    conditions.add('e.temperature = ?');
    vars.add(Variable.withString(temperature));
  }
  if (createdAfter != null) {
    conditions.add('e.created_at >= ?');
    vars.add(Variable.withInt(createdAfter));
  }
  if (createdBefore != null) {
    conditions.add('e.created_at <= ?');
    vars.add(Variable.withInt(createdBefore));
  }
  if (accessedAfter != null) {
    conditions.add('e.last_accessed >= ?');
    vars.add(Variable.withInt(accessedAfter));
  }

  final sortCol = switch (sortBy) {
    'created_at' => 'e.created_at DESC',
    'access_count' => 'e.access_count DESC',
    'name' => 'e.name ASC',
    _ => 'e.last_accessed DESC',
  };

  String sql;
  if (search != null && search.trim().isNotEmpty) {
    // FTS5 drives the scan — join direction matters for performance
    final ftsQuery = _buildFtsQuery(search);
    vars.add(Variable.withString(ftsQuery));
    sql = '''
      SELECT e.*,
        (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count
      FROM entities_fts
      JOIN entities e ON e.id = entities_fts.rowid
      WHERE entities_fts MATCH ? AND ${conditions.join(' AND ')}
      ORDER BY $sortCol LIMIT ? OFFSET ?
    ''';
  } else {
    sql = '''
      SELECT e.*,
        (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count
      FROM entities e
      WHERE ${conditions.join(' AND ')}
      ORDER BY $sortCol LIMIT ? OFFSET ?
    ''';
  }
  vars.addAll([Variable.withInt(limit), Variable.withInt(offset)]);

  final results = await customSelect(sql, variables: vars).get();
  return results.map((r) => r.data).toList();
}

/// Count with same filter logic (for pagination total).
Future<int> countEntitiesFiltered({
  String? type, String? temperature, String? search,
  int? createdAfter, int? createdBefore, int? accessedAfter,
}) async {
  // Same WHERE logic, SELECT COUNT(*) FROM entities e [JOIN entities_fts ...] WHERE ...
}

/// Stats: breakdown by type and temperature (two simple queries).
Future<Map<String, int>> countByType() async {
  final results = await customSelect(
    'SELECT entity_type, COUNT(*) as cnt FROM entities WHERE is_active = 1 GROUP BY entity_type',
  ).get();
  return {for (final r in results) r.read<String>('entity_type'): r.read<int>('cnt')};
}

Future<Map<String, int>> countByTemperature() async {
  final results = await customSelect(
    'SELECT temperature, COUNT(*) as cnt FROM entities WHERE is_active = 1 GROUP BY temperature',
  ).get();
  return {for (final r in results) r.read<String>('temperature'): r.read<int>('cnt')};
}
```

#### Phase 2: KnowledgeService — Unified listEntities

**File:** `lib/core/knowledge/services/knowledge_service.dart`

Replace the `if/else if` filter chain (lines 312-325) with delegation to `listEntitiesFiltered()`:

```dart
Future<List<(KnowledgeEntity, int)>> listEntities({
  int limit = 20, int offset = 0,
  String? type, String? temperature, String? search,
  int? createdAfter, int? createdBefore, int? accessedAfter,
  String sortBy = 'last_accessed',
}) async {
  final rows = await db.listEntitiesFiltered(
    type: type, temperature: temperature, search: search,
    createdAfter: createdAfter, createdBefore: createdBefore,
    accessedAfter: accessedAfter, sortBy: sortBy,
    limit: limit, offset: offset,
  );
  return rows.map((r) {
    final entity = KnowledgeEntity.fromJson(r);
    final factCount = (r['fact_count'] as int?) ?? 0;
    return (entity, factCount);
  }).toList();
}

/// Stats: entity/relation counts + breakdown by type and temperature.
Future<Map<String, dynamic>> getKbStats() async {
  final entityCount = await db.countEntities().getSingle();
  final relationCount = await db.countRelations().getSingle();
  final byType = await db.countByType();
  final byTemp = await db.countByTemperature();
  return {
    'entity_count': entityCount,
    'relation_count': relationCount,
    'by_type': byType,
    'by_temperature': byTemp,
  };
}

/// Resolve entity name to ID via FTS best-match.
Future<int?> resolveEntityByName(String name) async {
  final ftsQuery = _buildFtsQuery(name);
  final results = await db.searchEntitiesBrowse(ftsQuery, 1);
  return results.firstOrNull?['id'] as int?;
}
```

**Note:** The existing `knowledge_browser_screen.dart` also calls `listEntities()` — the refactored method must remain backwards-compatible (all new params are optional).

#### Phase 3: kb_query Tool

**File:** `lib/core/tools/knowledge_query_tool.dart` (new)

```dart
class KnowledgeQueryTool extends Tool {
  final KnowledgeService knowledgeService;
  final String? kbLanguage;

  KnowledgeQueryTool({required this.knowledgeService, this.kbLanguage});

  @override String get name => 'kb_query';
  @override String get description => /* see Tool Design section */;
  @override Map<String, dynamic> get parameters => { /* see JSON Schema above */ };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final operation = args['operation'] as String;
      return switch (operation) {
        'list' => _list(args),
        'detail' => _detail(args),
        'stats' => _stats(),
        _ => ToolResult.error('Unknown operation: $operation'),
      };
    } catch (e) {
      print('[kb_query] Operation failed: $e');
      return ToolResult.error('Knowledge query failed.');
    }
  }

  Future<ToolResult> _list(Map<String, dynamic> args) async {
    // 1. Validate & clamp limit (max 50)
    final limit = (args['limit'] as int? ?? 20).clamp(1, 50);
    // 2. Validate type enum (if provided) against known UPPERCASE values
    // 3. Validate temperature enum
    // 4. Parse ISO 8601 dates to Unix epoch
    // 5. Call knowledgeService.listEntities(...)
    // 6. Call knowledgeService.countEntitiesFiltered(...) for total
    // 7. Return ToolResult.dual(forLLM: compact JSON, forUser: readable table)
  }

  Future<ToolResult> _detail(Map<String, dynamic> args) async {
    // 1. Resolve entity: entity_id (direct) or entity_name (FTS lookup, 500 char limit)
    // 2. Call knowledgeService.getEntityDetail(entityId)
    // 3. Touch entity: db.touchEntities([entityId])
    // 4. Strip sourceText from facts, embedding from entity
    // 5. Include disambiguation context if resolved by name
    // 6. Return ToolResult.dual(...)
  }

  Future<ToolResult> _stats() async {
    // 1. Call knowledgeService.getKbStats()
    // 2. Return ToolResult.dual(forLLM: JSON, forUser: readable summary)
  }
}
```

#### Phase 4: Registration & Config

**Files:**
- [x] `lib/providers/app_providers.dart` — Register inside KG block:
  ```dart
  if (!disabled.contains('kb_query')) {
    registry.register(KnowledgeQueryTool(
      knowledgeService: kgService,
      kbLanguage: config.knowledge.kbLanguage,
    ));
  }
  ```
- [x] `lib/features/settings/tools_config_screen.dart` — Add toggle to `_tools` list
- [x] `lib/core/agent/service_agent_factory.dart` — Register if KG is available in service isolate
- [ ] CLAUDE.md tool name list — Add `kb_query`

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Entity type casing | **UPPERCASE** (`PERSON`, `ORG`, etc.) | Matches DB storage and `knowledge_store` tool |
| Touch entities on list? | **No** | Browsing shouldn't reset decay timers |
| Touch entities on detail? | **Yes** | Explicit inspection = genuine access |
| Filter semantics | **AND** | "hot people" = temperature=hot AND type=PERSON |
| Name-based lookup | **Yes, with disambiguation** | Avoids double tool calls; disambiguation prevents wrong-entity errors |
| Default limit | **20** | Balances context window vs completeness |
| Max limit | **50** | Protects context window (was 100, reduced per performance review) |
| Date format | **ISO 8601** with concrete examples | LLM-friendly, tolerant parsing |
| Deactivate operation | **Out of scope v1** | Read-only tool; note in description |
| `search` param name | **`name_filter`** | Avoids confusion with `knowledge_search` tool |
| Fact count query | **Correlated subquery** | Existing codebase pattern, better for paginated queries |
| FTS5 join direction | **FTS5 drives scan** | `FROM entities_fts JOIN entities`, not reverse |
| Stats caching | **No** | GROUP BY on ≤2000 rows is sub-millisecond |

### Acceptance Criteria

- [x] `kb_query` with `operation=list` returns paginated entities with `total`, `has_more`
- [x] Combined filters work: `type=PERSON` AND `temperature=hot` returns intersection
- [x] Date range filters work: `created_after=2026-03-01` filters correctly
- [ ] `sort_by` parameter changes result ordering
- [x] `operation=detail` with `entity_name` resolves name to ID via FTS with disambiguation
- [x] `operation=detail` with `entity_id` returns facts, relations, aliases (no sourceText/embedding)
- [x] `operation=stats` returns counts by type (UPPERCASE) and temperature
- [x] Empty KB returns helpful message, not error
- [ ] Invalid type/temperature values return clear error (not silent default)
- [x] Non-existent entity ID returns clear error
- [ ] `limit` clamped to max 50
- [ ] `entity_name` clamped to 500 chars
- [x] Error messages sanitized (generic to LLM, full detail in print log)
- [x] Tool registered in both main and service isolate (if KG available)
- [x] Toggle in tools config screen
- [x] `forLLM` is compact JSON, `forUser` is readable text
- [x] Existing `knowledge_browser_screen.dart` still works after `listEntities()` refactor

## References

- Similar tool: `lib/core/tools/knowledge_search_tool.dart` (semantic search)
- KG DB schema: `lib/core/knowledge/database/schema.drift`
- KG DB queries: `lib/core/knowledge/database/knowledge_graph_db.dart:226-300`
- KG Service API: `lib/core/knowledge/services/knowledge_service.dart:306-410`
- Tool registration: `lib/providers/app_providers.dart:247-266`
- ProofEditor HTTP helpers: `lib/core/tools/proof_editor_tool.dart:1038-1096`
- Doc: `docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md`
- Doc: `docs/solutions/security-issues/proof-editor-code-review-security-and-robustness-fixes.md`
