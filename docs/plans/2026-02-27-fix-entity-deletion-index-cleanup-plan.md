---
title: "fix: Clean up FTS5 indexes and embeddings on entity deletion"
type: fix
date: 2026-02-27
---

# fix: Clean Up FTS5 Indexes and Embeddings on Entity Deletion

## Problem

When an entity is deactivated (soft-deleted), only `is_active` is set to 0 on the entity and its relations. Everything else is left behind:

- **FTS5 `entities_fts`**: Entry remains searchable (UPDATE trigger re-inserts it)
- **FTS5 `facts_fts`**: Facts are never expired, so they remain fully searchable
- **Embedding BLOB**: Not cleared (wasted storage on mobile)
- **Aliases**: Not deleted (orphaned rows)
- **`searchFacts` query**: Doesn't filter by `e.is_active = 1` — facts of deactivated entities leak into search results
- **`findNeighbors` query**: Doesn't filter neighbor `is_active` — deactivated entities can surface via graph traversal

Affected code paths: `deactivateEntity()` (UI delete), `purgeColdEntities()` (background purge).

`deleteAllData()` (forget everything) works correctly via DELETE triggers but lacks a safety net.

## Solution

### Change 1: Modify FTS5 triggers to respect soft-delete (`schema.drift`)

The `AFTER UPDATE` triggers currently always re-insert into FTS5. Add a `WHERE` clause to skip re-insert when the row is deactivated/expired:

```sql
-- entities_au: skip re-insert when is_active = 0
CREATE TRIGGER entities_au AFTER UPDATE ON entities BEGIN
  INSERT INTO entities_fts(entities_fts, rowid, name, summary, entity_type)
  VALUES('delete', old.id, old.name, old.summary, old.entity_type);
  INSERT INTO entities_fts(rowid, name, summary, entity_type)
  SELECT new.id, new.name, new.summary, new.entity_type
  WHERE new.is_active = 1;
END;

-- facts_au: skip re-insert when expired_at IS NOT NULL
CREATE TRIGGER facts_au AFTER UPDATE ON facts BEGIN
  INSERT INTO facts_fts(facts_fts, rowid, fact_key, fact_value)
  VALUES('delete', old.id, old.fact_key, old.fact_value);
  INSERT INTO facts_fts(rowid, fact_key, fact_value)
  SELECT new.id, new.fact_key, new.fact_value
  WHERE new.expired_at IS NULL;
END;
```

### Change 2: Schema version 2 migration (`knowledge_graph_db.dart`)

Bump `schemaVersion` from 1 to 2. In `migration`:

```dart
from1To2: (m) async {
  // Drop old triggers
  await customStatement('DROP TRIGGER IF EXISTS entities_au');
  await customStatement('DROP TRIGGER IF EXISTS facts_au');
  // Recreate with is_active/expired_at awareness
  await customStatement('''CREATE TRIGGER entities_au ...''');
  await customStatement('''CREATE TRIGGER facts_au ...''');
  // Rebuild FTS5 indexes to purge stale entries from past deactivations
  await customStatement("INSERT INTO entities_fts(entities_fts) VALUES('rebuild')");
  await customStatement("INSERT INTO facts_fts(facts_fts) VALUES('rebuild')");
},
```

The `rebuild` command re-reads the content tables and reconstructs the FTS5 index from scratch. Since the new triggers now respect `is_active`/`expired_at`, this automatically purges all stale entries.

### Change 3: Enhance `deactivateEntity()` (`knowledge_graph_db.dart`)

Add fact expiration, embedding cleanup, and alias deletion inside the existing transaction:

```dart
Future<void> deactivateEntity(int entityId) async {
  await transaction(() async {
    // Expire all active facts (triggers now clean facts_fts)
    await customStatement(
      'UPDATE facts SET expired_at = ? WHERE entity_id = ? AND expired_at IS NULL',
      [DateTime.now().millisecondsSinceEpoch, entityId],
    );
    // Deactivate entity + clear embedding (trigger now cleans entities_fts)
    await customStatement(
      'UPDATE entities SET is_active = 0, embedding = NULL WHERE id = ?',
      [entityId],
    );
    // Deactivate relations (already exists)
    await customStatement(
      'UPDATE relations SET is_active = 0 WHERE source_id = ? OR target_id = ?',
      [entityId, entityId],
    );
    // Delete orphaned aliases
    await customStatement(
      'DELETE FROM aliases WHERE entity_id = ?',
      [entityId],
    );
  });
}
```

### Change 4: Refactor `purgeColdEntities()` (`knowledge_graph_db.dart`)

Replace the batch UPDATE with a SELECT + per-entity deactivation to reuse the enhanced cleanup:

```dart
Future<int> purgeColdEntities(int olderThanEpoch) async {
  return await transaction(() async {
    // Identify candidates
    final rows = await customSelect(
      'SELECT id FROM entities WHERE temperature = \'cold\' AND last_accessed < ? AND is_active = 1',
      variables: [Variable.withInt(olderThanEpoch)],
    ).get();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      final id = row.read<int>('id');
      await customStatement(
        'UPDATE facts SET expired_at = ? WHERE entity_id = ? AND expired_at IS NULL',
        [now, id],
      );
      await customStatement(
        'UPDATE entities SET is_active = 0, embedding = NULL WHERE id = ?',
        [id],
      );
      await customStatement(
        'UPDATE relations SET is_active = 0 WHERE source_id = ? OR target_id = ?',
        [id, id],
      );
      await customStatement(
        'DELETE FROM aliases WHERE entity_id = ?',
        [id],
      );
    }

    // Deactivate orphaned relations
    await customStatement(
      'UPDATE relations SET is_active = 0 WHERE is_active = 1 AND ('
      '  source_id NOT IN (SELECT id FROM entities WHERE is_active = 1) OR'
      '  target_id NOT IN (SELECT id FROM entities WHERE is_active = 1))',
    );

    return rows.length;
  });
}
```

### Change 5: Fix `searchFacts` query (`schema.drift`)

Add entity `is_active` filter:

```sql
searchFacts:
  SELECT f.*, bm25(facts_fts, 2.0, 5.0) AS rank
  FROM facts_fts
  JOIN facts f ON f.id = facts_fts.rowid
  JOIN entities e ON e.id = f.entity_id
  WHERE facts_fts MATCH :query AND f.expired_at IS NULL AND e.is_active = 1
  ORDER BY rank LIMIT :lim;
```

### Change 6: Fix `findNeighbors` query (`schema.drift`)

Add neighbor entity `is_active` filter:

```sql
findNeighbors:
  SELECT e.id, e.name, e.entity_type, r.predicate, r.weight
  FROM relations r
  JOIN entities e ON e.id = CASE WHEN r.source_id = :entityId THEN r.target_id ELSE r.source_id END
  WHERE (r.source_id = :entityId OR r.target_id = :entityId)
    AND r.is_active = 1 AND r.expired_at IS NULL
    AND e.is_active = 1
  ORDER BY r.weight DESC;
```

### Change 7: Defense-in-depth in `queryRelevant()` (`knowledge_service.dart`)

Add `isActive` check at entity hydration (around line 201):

```dart
final entity = await db.getEntityById(s.entityId).getSingleOrNull();
if (entity == null || entity.isActive == false) continue;
```

### Change 8: Safety net in `deleteAllData()` (`knowledge_graph_db.dart`)

Add explicit FTS5 `delete-all` after the DELETE statements:

```dart
Future<void> deleteAllData() async {
  await transaction(() async {
    await customStatement('DELETE FROM facts');
    await customStatement('DELETE FROM relations');
    await customStatement('DELETE FROM aliases');
    await customStatement('DELETE FROM summary_nodes');
    await customStatement('DELETE FROM entities');
    // Safety net: ensure FTS5 indexes are definitively empty
    await customStatement("INSERT INTO entities_fts(entities_fts) VALUES('delete-all')");
    await customStatement("INSERT INTO facts_fts(facts_fts) VALUES('delete-all')");
  });
}
```

## Files to Modify

1. `lib/core/knowledge/database/schema.drift` — triggers + `searchFacts` + `findNeighbors`
2. `lib/core/knowledge/database/knowledge_graph_db.dart` — schema version, migration, `deactivateEntity()`, `purgeColdEntities()`, `deleteAllData()`
3. `lib/core/knowledge/services/knowledge_service.dart` — defense check in `queryRelevant()`

## Acceptance Criteria

- [x] FTS5 `entities_fts` entries removed when entity is deactivated (trigger skips re-insert when `is_active = 0`)
- [x] FTS5 `facts_fts` entries removed when facts are expired (trigger skips re-insert when `expired_at IS NOT NULL`)
- [x] `deactivateEntity()` also: expires facts, clears embedding BLOB, deletes aliases
- [x] `purgeColdEntities()` applies same cleanup per entity
- [x] `searchFacts` query filters by `e.is_active = 1`
- [x] `findNeighbors` query filters neighbor by `e.is_active = 1`
- [x] `queryRelevant()` skips inactive entities at hydration
- [x] `deleteAllData()` has explicit FTS5 `delete-all` safety net
- [x] Schema version bumped to 2 with migration (drop/recreate triggers + FTS5 rebuild)
- [x] Existing databases migrated cleanly (stale FTS5 entries purged by rebuild)
- [x] `flutter analyze` — 0 issues

## References

- `schema.drift` FTS5 triggers: `lib/core/knowledge/database/schema.drift:139-172`
- `deactivateEntity()`: `lib/core/knowledge/database/knowledge_graph_db.dart:216-227`
- `purgeColdEntities()`: `lib/core/knowledge/database/knowledge_graph_db.dart:94-114`
- `deleteAllData()`: `lib/core/knowledge/database/knowledge_graph_db.dart:258-266`
- `searchFacts` query: `lib/core/knowledge/database/schema.drift:185-190`
- `findNeighbors` query: `lib/core/knowledge/database/schema.drift:192-200`
- `queryRelevant()` hydration: `lib/core/knowledge/services/knowledge_service.dart:201`
- KG retrieval fix doc: `docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md`
