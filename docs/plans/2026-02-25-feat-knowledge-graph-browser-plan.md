---
title: "feat: Knowledge Graph Browser"
type: feat
date: 2026-02-25
---

# Knowledge Graph Browser

## Overview

Add a browsable Knowledge Graph viewer that lets the user inspect all stored entities, their facts, relations, aliases, and memory decay status. Currently, the KG config screen only shows aggregate stats (N entities, N relations, DB size) with no way to see what's actually stored.

## Problem Statement

The user suspects that information is being stored in the KG but not surfaced during conversations. Currently there is no way to:
1. See what entities exist in the Knowledge Graph
2. Inspect individual entity details (facts, relations, aliases)
3. Understand why an entity might not be surfaced (temperature, decay, last accessed)
4. Search within the KG for specific entities
5. Delete individual entities that are wrong or stale

The only visibility is 3 aggregate stats on the config screen + the opaque `knowledge_search` tool.

## Proposed Solution

Extend the existing Knowledge Config screen with a "Browse" button that opens a new KG Browser screen. The browser has two views:

1. **Entity List** — paginated list of all entities with type icons, temperature badges, fact counts, and FTS5 search
2. **Entity Detail** — full detail of a single entity: facts, relations (with target entity names), aliases, decay diagnostics

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Navigation | New screen from config, NOT tab | Config screen stays simple (toggles + stats + forget); browsing is a separate concern |
| Data access | Add methods to `KnowledgeService` | Service layer wraps DB queries; don't leak Drift rows to UI |
| Pagination | Limit/offset (50 per page) | SQLite offset is cheap for <100K rows; no cursor needed |
| Search | FTS5 via existing `searchEntities` | Already exists, just needs to be exposed through service |
| Entity deletion | Soft-delete (set `is_active = 0`) | Consistent with existing cascade delete pattern; no data loss |
| Relation display | Show target entity name, not just ID | Much more useful; requires a JOIN or secondary lookup |

## Technical Approach

### Phase 1: Service Layer — Browse Methods

Add to `KnowledgeService` (4 new methods):

```dart
/// List entities with pagination, optional type and temperature filters.
Future<List<KnowledgeEntity>> listEntities({
  int limit = 50,
  int offset = 0,
  EntityType? type,
  Temperature? temperature,
  String? search, // FTS5 search query
}) async;

/// Get a single entity with its facts, relations (with target names), and aliases.
Future<KnowledgeEntityDetail?> getEntityDetail(int entityId) async;

/// Soft-delete a single entity (set is_active = 0).
Future<void> deactivateEntity(int entityId) async;

/// Count entities matching filters (for pagination info).
Future<int> countFilteredEntities({
  EntityType? type,
  Temperature? temperature,
}) async;
```

New data class in `entity.dart`:

```dart
class KnowledgeEntityDetail {
  final KnowledgeEntity entity;
  final List<KnowledgeFact> facts;
  final List<KnowledgeRelationWithNames> relations; // enriched with source/target names
  final List<KnowledgeAlias> aliases;
  final double decayScore; // current Ebbinghaus retention
}

class KnowledgeRelationWithNames {
  final KnowledgeRelation relation;
  final String sourceName;
  final String targetName;
}
```

### Phase 2: Database Queries

Add named queries to `schema.drift`:

```sql
listEntitiesPaged:
  SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count
  FROM entities e
  WHERE e.is_active = 1
  ORDER BY e.last_accessed DESC
  LIMIT :lim OFFSET :off;

listEntitiesByType:
  SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count
  FROM entities e
  WHERE e.is_active = 1 AND e.entity_type = :entityType
  ORDER BY e.last_accessed DESC
  LIMIT :lim OFFSET :off;

listEntitiesByTemperature:
  SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count
  FROM entities e
  WHERE e.is_active = 1 AND e.temperature = :temp
  ORDER BY e.last_accessed DESC
  LIMIT :lim OFFSET :off;

getEntityAliases:
  SELECT * FROM aliases WHERE entity_id = :entityId ORDER BY confidence DESC;

getEntityRelationsWithNames:
  SELECT r.*,
    src.name AS source_name,
    tgt.name AS target_name
  FROM relations r
  JOIN entities src ON src.id = r.source_id
  JOIN entities tgt ON tgt.id = r.target_id
  WHERE (r.source_id = :entityId OR r.target_id = :entityId)
    AND r.is_active = 1 AND r.expired_at IS NULL
  ORDER BY r.weight DESC;

countEntitiesByType:
  SELECT COUNT(*) AS cnt FROM entities WHERE is_active = 1 AND entity_type = :entityType;

countEntitiesByTemperature:
  SELECT COUNT(*) AS cnt FROM entities WHERE is_active = 1 AND temperature = :temp;
```

Add method to `KnowledgeGraphDB`:

```dart
Future<void> deactivateEntity(int entityId) async {
  await customStatement(
    'UPDATE entities SET is_active = 0 WHERE id = ?',
    [entityId],
  );
}
```

After adding queries, regenerate: `dart run build_runner build --delete-conflicting-outputs`

### Phase 3: UI — Entity List Screen

New file: `lib/features/settings/knowledge_browser_screen.dart`

```
┌──────────────────────────────────────┐
│ ← Knowledge Browser                 │
├──────────────────────────────────────┤
│ 🔍 Search entities...               │ ← FTS5 search bar
├──────────────────────────────────────┤
│ [All] [Person] [Place] [Org] [Concept]│ ← Type filter chips
│ [🔴hot] [🟠warm] [🔵cool] [⚪cold]  │ ← Temperature filter chips
├──────────────────────────────────────┤
│ 👤 Didier Girard               🔴   │
│    PERSON · 3 facts · 2h ago        │
├──────────────────────────────────────┤
│ 🏢 Anthropic                   🟠   │
│    ORG · 5 facts · 1d ago           │
├──────────────────────────────────────┤
│ 📍 Paris                       🔵   │
│    PLACE · 2 facts · 3d ago         │
├──────────────────────────────────────┤
│ 💡 Knowledge Graph              ⚪   │
│    CONCEPT · 1 fact · 7d ago        │
└──────────────────────────────────────┘
```

- Type icons: 👤 PERSON, 📍 PLACE, 🏢 ORG, 📅 EVENT, 💡 CONCEPT, 📆 DATE (via `Icons.*`)
- Temperature badge: colored dot (same pattern as LLM traces)
- "N facts" count from the subquery
- "Xh/Xd ago" from `last_accessed` epoch
- Tap → Entity Detail screen
- Infinite scroll or "Load more" button (50 per page)
- Pull to refresh

### Phase 4: UI — Entity Detail Screen

New file: `lib/features/settings/knowledge_entity_detail_screen.dart`

```
┌──────────────────────────────────────┐
│ ← Didier Girard                [🗑️]│ ← Delete button
├──────────────────────────────────────┤
│ PERSON · ID #42                      │
│ Temperature: 🔴 hot (R=0.92)        │
│ Created: 2026-02-20 · Accessed: 2h  │
│ Access count: 15                     │
├──────────────────────────────────────┤
│ ▶ Facts (3)                          │ ← Expandable, open by default
│   role: "AI researcher"              │
│   location: "Paris, France"          │
│   company: "Anthropic"               │
├──────────────────────────────────────┤
│ ▶ Relations (2)                      │ ← Expandable
│   WORKS_AT → Anthropic               │
│   LIVES_IN → Paris                   │
├──────────────────────────────────────┤
│ ▶ Aliases (2)                        │ ← Expandable
│   "Didier Girard" (name, 1.0)        │
│   "Didier" (name, 0.9)              │
├──────────────────────────────────────┤
│ ▶ Decay Diagnostics                  │ ← Expandable
│   Retention score: 0.92              │
│   Half-life: 86400s × ln(1+1.5×16)  │
│   Last accessed: 2026-02-25 09:15    │
│   Temperature thresholds:            │
│     hot ≥ 0.70, warm ≥ 0.40         │
│     cool ≥ 0.10, cold < 0.10        │
└──────────────────────────────────────┘
```

- Delete button (soft-delete) with confirmation dialog
- Tapping a relation target name → navigate to that entity's detail
- Decay diagnostics section helps debug "why isn't this surfaced?" — shows the raw retention score, access count, temperature classification

### Phase 5: Navigation & i18n

- Route: `/settings/knowledge-browser`
- Route: `/settings/knowledge-entity` (receives entity ID as argument)
- "Browse" button added to `knowledge_config_screen.dart` (only when KG is enabled and entities > 0)
- ~25 new ARB keys across 5 locales

## Implementation Phases

### Phase 1: Data Model + Service Layer

**Tasks:**
- [ ] Add `KnowledgeEntityDetail` and `KnowledgeRelationWithNames` classes to `entity.dart`
- [ ] Add named queries to `schema.drift` (listEntitiesPaged, getEntityAliases, getEntityRelationsWithNames, count queries)
- [ ] Regenerate Drift code (`dart run build_runner build --delete-conflicting-outputs`)
- [ ] Add `deactivateEntity()` method to `KnowledgeGraphDB`
- [ ] Add `listEntities()`, `getEntityDetail()`, `deactivateEntity()`, `countFilteredEntities()` to `KnowledgeService`

### Phase 2: Entity List Screen

**Tasks:**
- [ ] Create `lib/features/settings/knowledge_browser_screen.dart`
- [ ] Add FTS5 search bar with debounced text input
- [ ] Add type filter chips (All, Person, Place, Org, Event, Concept, Date)
- [ ] Add temperature filter chips (hot, warm, cool, cold)
- [ ] Add entity list tiles with type icon, name, fact count, time ago, temperature dot
- [ ] Add pagination (load more / infinite scroll)
- [ ] Add pull-to-refresh

### Phase 3: Entity Detail Screen

**Tasks:**
- [ ] Create `lib/features/settings/knowledge_entity_detail_screen.dart`
- [ ] Add header card with entity type, ID, temperature, dates, access count
- [ ] Add expandable Facts section (key-value list)
- [ ] Add expandable Relations section (predicate → target name, tappable navigation)
- [ ] Add expandable Aliases section
- [ ] Add expandable Decay Diagnostics section (retention score, formula, thresholds)
- [ ] Add delete button with confirmation dialog (soft-delete)

### Phase 4: Navigation + i18n

**Tasks:**
- [ ] Add routes in `app.dart` (`/settings/knowledge-browser`, `/settings/knowledge-entity`)
- [ ] Add "Browse" ListTile in `knowledge_config_screen.dart`
- [ ] Add ~25 ARB keys across 5 locales (EN/FR/ES/DE/IT)

### Phase 5: Build & Test

**Tasks:**
- [ ] `flutter analyze` — 0 issues
- [ ] `flutter build apk --release --split-per-abi` — builds
- [ ] Test on device: browse entities, search, filter, view detail, delete entity, verify decay diagnostics

## Files Modified

### New Files (2)

| File | Description |
|------|-------------|
| `lib/features/settings/knowledge_browser_screen.dart` | Entity list with search, filters, pagination |
| `lib/features/settings/knowledge_entity_detail_screen.dart` | Entity detail with facts, relations, aliases, decay diagnostics |

### Modified Files (~10)

| File | Change |
|------|--------|
| `lib/core/knowledge/models/entity.dart` | Add `KnowledgeEntityDetail`, `KnowledgeRelationWithNames` |
| `lib/core/knowledge/database/schema.drift` | Add 7 named queries (list, count, aliases, relations with names) |
| `lib/core/knowledge/database/knowledge_graph_db.dart` | Add `deactivateEntity()` |
| `lib/core/knowledge/database/knowledge_graph_db.g.dart` | Regenerated |
| `lib/core/knowledge/services/knowledge_service.dart` | Add 4 browse methods |
| `lib/app.dart` | Add 2 routes |
| `lib/features/settings/knowledge_config_screen.dart` | Add "Browse" button |
| All 5 `lib/l10n/app_*.arb` files | ~25 new keys each |

## Acceptance Criteria

- [ ] Entity list shows all active entities with type, name, fact count, temperature
- [ ] FTS5 search filters entities in real-time (debounced)
- [ ] Type and temperature filter chips work correctly
- [ ] Entity detail shows all facts, relations (with entity names), aliases
- [ ] Decay diagnostics show retention score and explain temperature classification
- [ ] Tapping a relation target navigates to that entity's detail
- [ ] Soft-delete works (entity disappears from list, cascade cleans up)
- [ ] Pagination works for large KG (50 entities per page)
- [ ] All UI strings localized in 5 languages
- [ ] `flutter analyze` — 0 issues
- [ ] APK builds and runs correctly
