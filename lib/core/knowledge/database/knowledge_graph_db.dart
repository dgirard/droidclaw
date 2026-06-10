import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../shared/constants.dart';

part 'knowledge_graph_db.g.dart';

/// One edge from a batched neighbor lookup ([KnowledgeGraphDB.findNeighborsBatch]).
/// [anchorId] is the queried entity; [neighborId] the connected entity.
typedef NeighborEdge = ({
  int anchorId,
  int neighborId,
  String predicate,
  double weight,
  double relConfidence,
});

/// One active fact row from a batched fact lookup
/// ([KnowledgeGraphDB.getActiveFactRowsBatch]).
typedef FactRow = ({int id, String key, String value, String type});

@DriftDatabase(include: {'schema.drift'})
class KnowledgeGraphDB extends _$KnowledgeGraphDB {
  KnowledgeGraphDB(String dbPath)
      : super(_openConnection(dbPath));

  /// Test-only: construct against a caller-provided executor (e.g. an
  /// in-memory database) so the knowledge graph can be exercised without a
  /// real file or device.
  KnowledgeGraphDB.forExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  static QueryExecutor _openConnection(String dbPath) {
    return driftDatabase(
      name: dbPath,
      native: DriftNativeOptions(
        databasePath: () async => dbPath,
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            // v1→3 or v2→3: drop all FTS5 triggers and tables, recreate cleanly.
            // Fixes: v1 triggers lacked is_active/expired_at awareness,
            //        v2 'rebuild' command corrupted FTS5 indexes.
            await _dropFts5TablesAndTriggers();
            await _createFts5Tables();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA busy_timeout = 5000');
        },
      );

  /// Drop FTS5 triggers and virtual tables (inverse of [_createFts5Tables]).
  Future<void> _dropFts5TablesAndTriggers() async {
    await customStatement('DROP TRIGGER IF EXISTS entities_ai');
    await customStatement('DROP TRIGGER IF EXISTS entities_ad');
    await customStatement('DROP TRIGGER IF EXISTS entities_au');
    await customStatement('DROP TRIGGER IF EXISTS facts_ai');
    await customStatement('DROP TRIGGER IF EXISTS facts_ad');
    await customStatement('DROP TRIGGER IF EXISTS facts_au');
    await customStatement('DROP TABLE IF EXISTS entities_fts');
    await customStatement('DROP TABLE IF EXISTS facts_fts');
  }

  /// Create FTS5 virtual tables and sync triggers.
  /// Must stay in sync with schema.drift FTS5 definitions.
  Future<void> _createFts5Tables() async {
    await customStatement('''
      CREATE VIRTUAL TABLE entities_fts USING fts5(
        name, summary, entity_type,
        content=entities, content_rowid=id,
        prefix='2 3', tokenize='unicode61'
      )
    ''');
    await customStatement('''
      CREATE VIRTUAL TABLE facts_fts USING fts5(
        fact_key, fact_value,
        content=facts, content_rowid=id,
        prefix='2 3', tokenize='unicode61'
      )
    ''');
    // Triggers for entities
    await customStatement('''
      CREATE TRIGGER entities_ai AFTER INSERT ON entities BEGIN
        INSERT INTO entities_fts(rowid, name, summary, entity_type)
        VALUES (new.id, new.name, new.summary, new.entity_type);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER entities_ad AFTER DELETE ON entities BEGIN
        INSERT INTO entities_fts(entities_fts, rowid, name, summary, entity_type)
        VALUES('delete', old.id, old.name, old.summary, old.entity_type);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER entities_au AFTER UPDATE ON entities BEGIN
        INSERT INTO entities_fts(entities_fts, rowid, name, summary, entity_type)
        VALUES('delete', old.id, old.name, old.summary, old.entity_type);
        INSERT INTO entities_fts(rowid, name, summary, entity_type)
        SELECT new.id, new.name, new.summary, new.entity_type
        WHERE new.is_active = 1;
      END
    ''');
    // Triggers for facts
    await customStatement('''
      CREATE TRIGGER facts_ai AFTER INSERT ON facts BEGIN
        INSERT INTO facts_fts(rowid, fact_key, fact_value)
        VALUES (new.id, new.fact_key, new.fact_value);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER facts_ad AFTER DELETE ON facts BEGIN
        INSERT INTO facts_fts(facts_fts, rowid, fact_key, fact_value)
        VALUES('delete', old.id, old.fact_key, old.fact_value);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER facts_au AFTER UPDATE ON facts BEGIN
        INSERT INTO facts_fts(facts_fts, rowid, fact_key, fact_value)
        VALUES('delete', old.id, old.fact_key, old.fact_value);
        INSERT INTO facts_fts(rowid, fact_key, fact_value)
        SELECT new.id, new.fact_key, new.fact_value
        WHERE new.expired_at IS NULL;
      END
    ''');
    // Populate FTS5 from existing active data
    await customStatement('''
      INSERT INTO entities_fts(rowid, name, summary, entity_type)
      SELECT id, name, summary, entity_type FROM entities WHERE is_active = 1
    ''');
    await customStatement('''
      INSERT INTO facts_fts(rowid, fact_key, fact_value)
      SELECT id, fact_key, fact_value FROM facts WHERE expired_at IS NULL
    ''');
  }

  /// Touch entities: update last_accessed and increment access_count.
  Future<void> touchEntities(List<int> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await batch((b) {
      for (final id in ids) {
        b.customStatement(
          'UPDATE entities SET last_accessed = ?, access_count = access_count + 1 WHERE id = ?',
          [now, id],
        );
      }
    });
  }

  /// Update a fact bi-temporally: close the old, insert the new.
  Future<void> updateFactBiTemporal({
    required int entityId,
    required String key,
    required String newValue,
    String valueType = 'string',
    int? newValidAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await transaction(() async {
      await customStatement(
        'UPDATE facts SET expired_at = ?, invalid_at = ? '
        'WHERE entity_id = ? AND fact_key = ? AND expired_at IS NULL',
        [now, newValidAt ?? now, entityId, key],
      );
      await customStatement(
        'INSERT INTO facts (entity_id, fact_key, fact_value, value_type, valid_at, ingested_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [entityId, key, newValue, valueType, newValidAt, now],
      );
    });
  }

  /// Expire a relation bi-temporally: set expired_at AND is_active = 0.
  Future<void> expireRelation(int relationId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await customStatement(
      'UPDATE relations SET expired_at = ?, is_active = 0 WHERE id = ?',
      [now, relationId],
    );
  }

  /// Get all aliases for all active entities in a single batch query.
  Future<Map<int, List<String>>> getAllActiveAliases() async {
    final results = await customSelect(
      'SELECT a.entity_id, a.alias_name FROM aliases a '
      'JOIN entities e ON e.id = a.entity_id '
      'WHERE e.is_active = 1',
    ).get();
    final map = <int, List<String>>{};
    for (final r in results) {
      final entityId = r.read<int>('entity_id');
      final aliasName = r.read<String>('alias_name');
      (map[entityId] ??= []).add(aliasName);
    }
    return map;
  }

  /// Batch-load entities by id in a single `IN (...)` query.
  ///
  /// Replaces per-id [getEntityById] loops in hot retrieval paths (U12).
  /// Unchunked on purpose: callers pass top-K-sized id lists.
  Future<List<Entity>> getEntitiesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    return (select(entities)..where((e) => e.id.isIn(ids))).get();
  }

  /// Batch-load active (non-expired) facts for a set of entities in a single
  /// `IN (...)` query, ordered by entity then fact key (mirrors
  /// [getEntityFacts] per-entity ordering).
  /// Unchunked on purpose: callers pass top-K-sized id lists.
  Future<List<Fact>> getFactsForEntityIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    return (select(facts)
          ..where((f) => f.entityId.isIn(ids) & f.expiredAt.isNull())
          ..orderBy([
            (f) => OrderingTerm.asc(f.entityId),
            (f) => OrderingTerm.asc(f.factKey),
          ]))
        .get();
  }

  /// Batch [findNeighbors] for a set of entity ids in a single query.
  ///
  /// Returns edges grouped by the queried (anchor) entity id, preserving the
  /// per-id semantics: active, non-expired relations to active entities,
  /// weight-descending within each anchor. Anchors with no neighbors are
  /// absent from the map.
  /// Unchunked on purpose: callers pass top-K-sized id lists.
  Future<Map<int, List<NeighborEdge>>> findNeighborsBatch(
      List<int> ids) async {
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(', ');
    final vars = [for (final id in ids) Variable.withInt(id)];
    final rows = await customSelect(
      'SELECT r.source_id AS anchor_id, e.id AS neighbor_id, '
      'r.predicate AS predicate, r.weight AS weight, '
      'r.confidence AS rel_confidence '
      'FROM relations r JOIN entities e ON e.id = r.target_id '
      'WHERE r.source_id IN ($placeholders) '
      'AND r.is_active = 1 AND r.expired_at IS NULL AND e.is_active = 1 '
      'UNION ALL '
      'SELECT r.target_id AS anchor_id, e.id AS neighbor_id, '
      'r.predicate AS predicate, r.weight AS weight, '
      'r.confidence AS rel_confidence '
      'FROM relations r JOIN entities e ON e.id = r.source_id '
      'WHERE r.target_id IN ($placeholders) '
      'AND r.is_active = 1 AND r.expired_at IS NULL AND e.is_active = 1 '
      'ORDER BY anchor_id, weight DESC',
      variables: [...vars, ...vars],
    ).get();

    final map = <int, List<NeighborEdge>>{};
    for (final r in rows) {
      final edge = (
        anchorId: r.read<int>('anchor_id'),
        neighborId: r.read<int>('neighbor_id'),
        predicate: r.read<String>('predicate'),
        weight: r.read<double>('weight'),
        relConfidence: r.read<double>('rel_confidence'),
      );
      (map[edge.anchorId] ??= []).add(edge);
    }
    return map;
  }

  /// Batch-load relation-neighbor ids for a set of entities (U14).
  ///
  /// Replaces the per-entity [getEntityRelationsWithNames] loop in
  /// `KbMaintenanceService.findCandidates` (the dream-run N+1). Preserves the
  /// loop's exact semantics: active, non-expired relations, neighbor = the
  /// other endpoint, no is_active filter on the neighbor entity. Every
  /// requested id gets a (possibly empty) entry. Ids are chunked into
  /// `IN (...)` lists of [chunkSize] to bound bind variables per statement.
  Future<Map<int, Set<int>>> getRelationNeighborIdsBatch(
    List<int> ids, {
    int chunkSize = AppConstants.knowledgeSqlInChunkSize,
  }) async {
    final map = {for (final id in ids) id: <int>{}};
    await _forEachIdChunk(ids, chunkSize, (chunk, placeholders, vars) async {
      final rows = await customSelect(
        'SELECT source_id, target_id FROM relations '
        'WHERE (source_id IN ($placeholders) OR target_id IN ($placeholders)) '
        'AND is_active = 1 AND expired_at IS NULL',
        variables: [...vars, ...vars],
      ).get();
      final inChunk = chunk.toSet();
      for (final r in rows) {
        final src = r.read<int>('source_id');
        final tgt = r.read<int>('target_id');
        if (inChunk.contains(src)) map[src]!.add(tgt);
        if (inChunk.contains(tgt)) map[tgt]!.add(src);
      }
    });
    return map;
  }

  /// Batch-load active facts per entity (U14).
  ///
  /// Replaces the per-entity fact SELECT loops in the dedup pipeline. Rows
  /// are ordered by fact id within each entity (insertion order — same rows
  /// the old per-entity queries returned in practice) and, when
  /// [perEntityLimit] is non-null, truncated per entity in Dart. Ids are
  /// chunked like [getRelationNeighborIdsBatch].
  Future<Map<int, List<FactRow>>> getActiveFactRowsBatch(
    List<int> ids, {
    int? perEntityLimit,
    int chunkSize = AppConstants.knowledgeSqlInChunkSize,
  }) async {
    final map = <int, List<FactRow>>{};
    await _forEachIdChunk(ids, chunkSize, (chunk, placeholders, vars) async {
      final rows = await customSelect(
        'SELECT id, entity_id, fact_key, fact_value, value_type FROM facts '
        'WHERE entity_id IN ($placeholders) AND expired_at IS NULL '
        'ORDER BY entity_id, id',
        variables: vars,
      ).get();
      for (final r in rows) {
        final entityId = r.read<int>('entity_id');
        final list = map[entityId] ??= [];
        if (perEntityLimit != null && list.length >= perEntityLimit) continue;
        list.add((
          id: r.read<int>('id'),
          key: r.read<String>('fact_key'),
          value: r.read<String>('fact_value'),
          type: r.read<String>('value_type'),
        ));
      }
    });
    return map;
  }

  /// Run [body] once per `IN (...)` chunk of [ids], bounding bind variables
  /// per statement (U14 idiom shared by [getRelationNeighborIdsBatch] and
  /// [getActiveFactRowsBatch]). [body] receives the chunk plus ready-made
  /// `?` placeholders and bound [Variable]s for it.
  Future<void> _forEachIdChunk(
    List<int> ids,
    int chunkSize,
    Future<void> Function(
      List<int> chunk,
      String placeholders,
      List<Variable<Object>> vars,
    ) body,
  ) async {
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, min(i + chunkSize, ids.length));
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final vars = <Variable<Object>>[
        for (final id in chunk) Variable.withInt(id),
      ];
      await body(chunk, placeholders, vars);
    }
  }

  /// Max access_count among active cold entities (0 when there are none).
  ///
  /// Feeds the decay-candidate cutoff: combined with
  /// [MemoryDecay.maxAgeForRetention] it bounds how recently a cold entity
  /// must have been accessed to possibly leave 'cold'.
  Future<int> maxColdAccessCount() async {
    final row = await customSelect(
      "SELECT COALESCE(MAX(access_count), 0) AS m FROM entities "
      "WHERE is_active = 1 AND temperature = 'cold'",
    ).getSingle();
    return row.read<int>('m');
  }

  /// Active entities whose temperature could cross a threshold (U15).
  ///
  /// Non-cold rows are always candidates (they can still decay downward).
  /// Cold rows can only leave 'cold' if a recent access pushed retention
  /// back above the cool threshold, i.e. last_accessed >= [coldCutoffEpoch]
  /// (computed by the caller from the decay formula). Cold rows older than
  /// the cutoff provably stay cold and are skipped entirely.
  Future<List<({int id, int lastAccessed, int accessCount, String temperature})>>
      getDecayCandidates(int coldCutoffEpoch) async {
    final rows = await customSelect(
      "SELECT id, last_accessed, access_count, temperature FROM entities "
      "WHERE is_active = 1 AND (temperature != 'cold' OR last_accessed >= ?)",
      variables: [Variable.withInt(coldCutoffEpoch)],
    ).get();
    return [
      for (final r in rows)
        (
          id: r.read<int>('id'),
          lastAccessed: r.read<int>('last_accessed'),
          accessCount: r.read<int>('access_count'),
          temperature: r.read<String>('temperature'),
        ),
    ];
  }

  /// Update temperature for a batch of entities.
  Future<void> batchUpdateTemperatures(List<({int id, String temp})> updates) async {
    await batch((b) {
      for (final u in updates) {
        b.customStatement(
          'UPDATE entities SET temperature = ? WHERE id = ?',
          [u.temp, u.id],
        );
      }
    });
  }

  /// Deactivate cold entities older than a given epoch.
  /// Full cleanup: expire facts, clear embeddings, delete aliases, deactivate relations.
  /// Returns the number of deactivated entities.
  Future<int> purgeColdEntities(int olderThanEpoch) async {
    return await transaction(() async {
      // Identify candidates
      final rows = await customSelect(
        'SELECT id FROM entities '
        'WHERE temperature = \'cold\' AND last_accessed < ? AND is_active = 1',
        variables: [Variable.withInt(olderThanEpoch)],
      ).get();

      if (rows.isEmpty) return 0;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final row in rows) {
        await _deactivateSingleEntity(row.read<int>('id'), now);
      }

      // Deactivate any remaining orphaned relations
      await customStatement(
        'UPDATE relations SET is_active = 0 '
        'WHERE is_active = 1 AND ('
        '  source_id NOT IN (SELECT id FROM entities WHERE is_active = 1) OR'
        '  target_id NOT IN (SELECT id FROM entities WHERE is_active = 1))',
      );

      return rows.length;
    });
  }

  /// Get database size on disk.
  Future<int> getDatabaseSize(String dbPath) async {
    final file = File(dbPath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// List entities paged, ordered by last_accessed DESC, with fact count.
  Future<List<Map<String, dynamic>>> listEntitiesPaged(int limit, int offset) async {
    final results = await customSelect(
      'SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count '
      'FROM entities e WHERE e.is_active = 1 '
      'ORDER BY e.last_accessed DESC LIMIT ? OFFSET ?',
      variables: [Variable.withInt(limit), Variable.withInt(offset)],
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// List entities filtered by type, paged.
  Future<List<Map<String, dynamic>>> listEntitiesByType(String type, int limit, int offset) async {
    final results = await customSelect(
      'SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count '
      'FROM entities e WHERE e.is_active = 1 AND e.entity_type = ? '
      'ORDER BY e.last_accessed DESC LIMIT ? OFFSET ?',
      variables: [Variable.withString(type), Variable.withInt(limit), Variable.withInt(offset)],
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// List entities filtered by temperature, paged.
  Future<List<Map<String, dynamic>>> listEntitiesByTemperature(String temp, int limit, int offset) async {
    final results = await customSelect(
      'SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count '
      'FROM entities e WHERE e.is_active = 1 AND e.temperature = ? '
      'ORDER BY e.last_accessed DESC LIMIT ? OFFSET ?',
      variables: [Variable.withString(temp), Variable.withInt(limit), Variable.withInt(offset)],
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Search entities via FTS5 for browse mode.
  Future<List<Map<String, dynamic>>> searchEntitiesBrowse(String ftsQuery, int limit) async {
    final results = await customSelect(
      'SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count '
      'FROM entities_fts '
      'JOIN entities e ON e.id = entities_fts.rowid '
      'WHERE entities_fts MATCH ? AND e.is_active = 1 '
      'ORDER BY bm25(entities_fts) LIMIT ?',
      variables: [Variable.withString(ftsQuery), Variable.withInt(limit)],
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Get aliases for one entity.
  Future<List<Map<String, dynamic>>> getEntityAliases(int entityId) async {
    final results = await customSelect(
      'SELECT * FROM aliases WHERE entity_id = ?',
      variables: [Variable.withInt(entityId)],
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Get relations with source and target entity names.
  Future<List<Map<String, dynamic>>> getEntityRelationsWithNames(int entityId) async {
    final results = await customSelect(
      'SELECT r.*, '
      'src.name AS source_name, tgt.name AS target_name '
      'FROM relations r '
      'JOIN entities src ON src.id = r.source_id '
      'JOIN entities tgt ON tgt.id = r.target_id '
      'WHERE (r.source_id = ? OR r.target_id = ?) '
      'AND r.is_active = 1 AND r.expired_at IS NULL '
      'ORDER BY r.weight DESC',
      variables: [Variable.withInt(entityId), Variable.withInt(entityId)],
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Count entities with optional type/temperature filters.
  Future<int> countEntitiesFiltered({String? type, String? temp}) async {
    final conditions = <String>['is_active = 1'];
    final vars = <Variable>[];
    if (type != null) {
      conditions.add('entity_type = ?');
      vars.add(Variable.withString(type));
    }
    if (temp != null) {
      conditions.add('temperature = ?');
      vars.add(Variable.withString(temp));
    }
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM entities WHERE ${conditions.join(' AND ')}',
      variables: vars,
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// List entities with combined AND filters (type + temperature + date range),
  /// paged, ordered by last_accessed DESC.
  Future<List<Map<String, dynamic>>> listEntitiesFiltered({
    String? type,
    String? temperature,
    int? createdAfterEpoch,
    int? createdBeforeEpoch,
    int? accessedAfterEpoch,
    required int limit,
    required int offset,
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
    if (createdAfterEpoch != null) {
      conditions.add('e.created_at >= ?');
      vars.add(Variable.withInt(createdAfterEpoch));
    }
    if (createdBeforeEpoch != null) {
      conditions.add('e.created_at < ?');
      vars.add(Variable.withInt(createdBeforeEpoch));
    }
    if (accessedAfterEpoch != null) {
      conditions.add('e.last_accessed >= ?');
      vars.add(Variable.withInt(accessedAfterEpoch));
    }
    vars.add(Variable.withInt(limit));
    vars.add(Variable.withInt(offset));
    final results = await customSelect(
      'SELECT e.*, (SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count '
      'FROM entities e WHERE ${conditions.join(' AND ')} '
      'ORDER BY e.last_accessed DESC LIMIT ? OFFSET ?',
      variables: vars,
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Count entities grouped by entity_type.
  Future<List<Map<String, dynamic>>> countByType() async {
    final results = await customSelect(
      'SELECT entity_type, COUNT(*) AS cnt FROM entities '
      'WHERE is_active = 1 GROUP BY entity_type ORDER BY cnt DESC',
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Count entities grouped by temperature.
  Future<List<Map<String, dynamic>>> countByTemperature() async {
    final results = await customSelect(
      'SELECT temperature, COUNT(*) AS cnt FROM entities '
      'WHERE is_active = 1 GROUP BY temperature ORDER BY cnt DESC',
    ).get();
    return results.map((r) => r.data).toList();
  }

  /// Count active facts.
  Future<int> countActiveFacts() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM facts WHERE expired_at IS NULL',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Count active relations.
  Future<int> countActiveRelations() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM relations WHERE is_active = 1 AND expired_at IS NULL',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Soft-delete an entity: deactivate, expire facts, clear embedding,
  /// delete aliases, deactivate relations. FTS5 triggers handle index cleanup.
  Future<void> deactivateEntity(int entityId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await transaction(() async {
      await _deactivateSingleEntity(entityId, now);
    });
  }

  /// Shared cleanup for a single entity. Must be called inside a transaction.
  /// Expires facts, deactivates entity + clears embedding, deactivates
  /// relations, and deletes aliases. FTS5 triggers handle index cleanup.
  Future<void> _deactivateSingleEntity(int entityId, int nowEpoch) async {
    await customStatement(
      'UPDATE facts SET expired_at = ? WHERE entity_id = ? AND expired_at IS NULL',
      [nowEpoch, entityId],
    );
    await customStatement(
      'UPDATE entities SET is_active = 0, embedding = NULL WHERE id = ?',
      [entityId],
    );
    await customStatement(
      'UPDATE relations SET is_active = 0 WHERE source_id = ? OR target_id = ?',
      [entityId, entityId],
    );
    await customStatement(
      'DELETE FROM aliases WHERE entity_id = ?',
      [entityId],
    );
  }

  /// Merge [secondaryId] into [primaryId] within a single transaction.
  ///
  /// Safe 12-step order: validate, expire self-referential relations,
  /// two-pass conflict handling, re-point remaining, transfer aliases,
  /// merge metadata, deactivate secondary, nullify primary embedding.
  ///
  /// Returns a [MergeResult] with counts of transferred items.
  Future<MergeResult> mergeEntities(int primaryId, int secondaryId) async {
    return await transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 1. Validate both entities exist and are active
      final primary = await customSelect(
        'SELECT * FROM entities WHERE id = ? AND is_active = 1',
        variables: [Variable.withInt(primaryId)],
      ).getSingleOrNull();
      final secondary = await customSelect(
        'SELECT * FROM entities WHERE id = ? AND is_active = 1',
        variables: [Variable.withInt(secondaryId)],
      ).getSingleOrNull();
      if (primary == null || secondary == null) {
        throw StateError('Both entities must exist and be active');
      }

      final primaryName = primary.read<String>('name');
      final secondaryName = secondary.read<String>('name');

      // 2. Expire self-referential relations (secondary↔primary)
      await customStatement(
        'UPDATE relations SET expired_at = ?, is_active = 0 '
        'WHERE is_active = 1 AND expired_at IS NULL AND ('
        '  (source_id = ? AND target_id = ?) OR '
        '  (source_id = ? AND target_id = ?)'
        ')',
        [now, secondaryId, primaryId, primaryId, secondaryId],
      );

      // 3. Identify and expire conflicting relations (source side)
      // A conflict: re-pointing source_id from secondary→primary would
      // duplicate an existing (primary, predicate, target_id) triplet.
      await customStatement(
        'UPDATE relations SET expired_at = ?, is_active = 0 '
        'WHERE source_id = ? AND is_active = 1 AND expired_at IS NULL '
        'AND EXISTS ('
        '  SELECT 1 FROM relations r2 '
        '  WHERE r2.source_id = ? AND r2.predicate = relations.predicate '
        '  AND r2.target_id = relations.target_id '
        '  AND r2.is_active = 1 AND r2.expired_at IS NULL'
        ')',
        [now, secondaryId, primaryId],
      );
      // Conflicts on target side
      await customStatement(
        'UPDATE relations SET expired_at = ?, is_active = 0 '
        'WHERE target_id = ? AND is_active = 1 AND expired_at IS NULL '
        'AND EXISTS ('
        '  SELECT 1 FROM relations r2 '
        '  WHERE r2.target_id = ? AND r2.predicate = relations.predicate '
        '  AND r2.source_id = relations.source_id '
        '  AND r2.is_active = 1 AND r2.expired_at IS NULL'
        ')',
        [now, secondaryId, primaryId],
      );

      // 4. Re-point remaining relations from secondary to primary
      // Source side
      await customStatement(
        'UPDATE relations SET source_id = ? '
        'WHERE source_id = ? AND is_active = 1 AND expired_at IS NULL',
        [primaryId, secondaryId],
      );
      final srcChanged = await customSelect('SELECT changes() AS cnt').getSingle();
      final relationsTransferred1 = srcChanged.read<int>('cnt');
      // Target side
      await customStatement(
        'UPDATE relations SET target_id = ? '
        'WHERE target_id = ? AND is_active = 1 AND expired_at IS NULL',
        [primaryId, secondaryId],
      );
      final tgtChanged = await customSelect('SELECT changes() AS cnt').getSingle();
      final relationsTransferred2 = tgtChanged.read<int>('cnt');

      // 5. Identify and expire conflicting facts
      await customStatement(
        'UPDATE facts SET expired_at = ? '
        'WHERE entity_id = ? AND expired_at IS NULL '
        'AND fact_key IN ('
        '  SELECT fact_key FROM facts '
        '  WHERE entity_id = ? AND expired_at IS NULL'
        ')',
        [now, secondaryId, primaryId],
      );
      final factsExpiredResult = await customSelect('SELECT changes() AS cnt').getSingle();
      final factsExpired = factsExpiredResult.read<int>('cnt');

      // 6. Re-point remaining facts from secondary to primary
      await customStatement(
        'UPDATE facts SET entity_id = ? '
        'WHERE entity_id = ? AND expired_at IS NULL',
        [primaryId, secondaryId],
      );
      final factsTransResult = await customSelect('SELECT changes() AS cnt').getSingle();
      final factsTransferred = factsTransResult.read<int>('cnt');

      // 7. Transfer aliases (INSERT OR IGNORE handles duplicates)
      final secondaryAliases = await customSelect(
        'SELECT alias_name, alias_type, confidence FROM aliases WHERE entity_id = ?',
        variables: [Variable.withInt(secondaryId)],
      ).get();
      var aliasesTransferred = 0;
      for (final alias in secondaryAliases) {
        try {
          await customStatement(
            'INSERT OR IGNORE INTO aliases (entity_id, alias_name, alias_type, confidence) '
            'VALUES (?, ?, ?, ?)',
            [
              primaryId,
              alias.read<String>('alias_name'),
              alias.read<String>('alias_type'),
              alias.read<double>('confidence'),
            ],
          );
          final inserted = await customSelect('SELECT changes() AS cnt').getSingle();
          aliasesTransferred += inserted.read<int>('cnt');
        } catch (_) {
          // Ignore duplicate alias errors
        }
      }

      // 8. Add secondary's name as alias of primary
      try {
        await customStatement(
          'INSERT OR IGNORE INTO aliases (entity_id, alias_name, alias_type, confidence) '
          'VALUES (?, ?, \'name\', 1.0)',
          [primaryId, secondaryName],
        );
      } catch (_) {
        // Best-effort: the alias is a redundant lookup aid. A constraint
        // failure here must not abort the surrounding merge transaction.
      }

      // Delete secondary's aliases (they've been transferred)
      await customStatement(
        'DELETE FROM aliases WHERE entity_id = ?',
        [secondaryId],
      );

      // 9. Merge entity metadata
      final secAccessCount = secondary.read<int>('access_count');
      final secCreatedAt = secondary.read<int>('created_at');
      final secBaseScore = secondary.read<double>('base_score');
      final secSummary = secondary.readNullable<String>('summary');
      final secProperties = secondary.read<String>('properties');
      final secValidAt = secondary.readNullable<int>('valid_at');
      final secIngestedAt = secondary.read<int>('ingested_at');

      final priCreatedAt = primary.read<int>('created_at');
      final priBaseScore = primary.read<double>('base_score');
      final priSummary = primary.readNullable<String>('summary');
      final priProperties = primary.read<String>('properties');
      final priValidAt = primary.readNullable<int>('valid_at');
      final priIngestedAt = primary.read<int>('ingested_at');

      // Merge properties JSON
      String mergedProperties;
      try {
        final priMap = Map<String, dynamic>.from(
            jsonDecode(priProperties) as Map<String, dynamic>);
        final secMap = Map<String, dynamic>.from(
            jsonDecode(secProperties) as Map<String, dynamic>);
        // Secondary fills in missing keys, primary wins on conflicts
        secMap.addAll(priMap);
        mergedProperties = jsonEncode(secMap);
      } catch (_) {
        mergedProperties = priProperties;
      }

      // Merge summary
      String? mergedSummary;
      if (priSummary != null && secSummary != null) {
        mergedSummary = '$priSummary. $secSummary';
      } else {
        mergedSummary = priSummary ?? secSummary;
      }

      // Merge temporal fields
      final mergedCreatedAt = min(priCreatedAt, secCreatedAt);
      final mergedIngestedAt = min(priIngestedAt, secIngestedAt);
      int? mergedValidAt;
      if (priValidAt != null && secValidAt != null) {
        mergedValidAt = min(priValidAt, secValidAt);
      } else {
        mergedValidAt = priValidAt ?? secValidAt;
      }

      await customStatement(
        'UPDATE entities SET '
        'access_count = access_count + ?, '
        'base_score = ?, '
        'last_accessed = ?, '
        'created_at = ?, '
        'ingested_at = ?, '
        'valid_at = ?, '
        'summary = ?, '
        'properties = ? '
        'WHERE id = ?',
        [
          secAccessCount,
          max(priBaseScore, secBaseScore),
          now, // merge itself counts as access
          mergedCreatedAt,
          mergedIngestedAt,
          mergedValidAt,
          mergedSummary,
          mergedProperties,
          primaryId,
        ],
      );

      // 10. Deactivate secondary entity
      await customStatement(
        'UPDATE entities SET is_active = 0, expired_at = ? WHERE id = ?',
        [now, secondaryId],
      );

      // 11. Nullify primary's embedding (stale after merge)
      await customStatement(
        'UPDATE entities SET embedding = NULL WHERE id = ?',
        [primaryId],
      );

      // 12. Update summary_nodes.member_ids if applicable
      final summaryNodes = await customSelect(
        'SELECT id, member_ids FROM summary_nodes '
        'WHERE member_ids LIKE ?',
        variables: [Variable.withString('%$secondaryId%')],
      ).get();
      for (final node in summaryNodes) {
        try {
          final memberIds = List<dynamic>.from(
              jsonDecode(node.read<String>('member_ids')) as List);
          final updated = memberIds.map((id) {
            return id == secondaryId ? primaryId : id;
          }).toSet().toList(); // deduplicate
          await customStatement(
            'UPDATE summary_nodes SET member_ids = ? WHERE id = ?',
            [jsonEncode(updated), node.read<int>('id')],
          );
        } catch (_) {
          // Skip summary nodes with malformed member_ids JSON: a stale
          // member reference is cosmetic and must not abort the merge.
        }
      }

      // Count expired relations (step 2 + 3)
      final expiredRels = await customSelect(
        'SELECT COUNT(*) AS cnt FROM relations '
        'WHERE (source_id = ? OR target_id = ?) '
        'AND is_active = 0 AND expired_at = ?',
        variables: [
          Variable.withInt(secondaryId),
          Variable.withInt(secondaryId),
          Variable.withInt(now),
        ],
      ).getSingle();

      return MergeResult(
        primaryId: primaryId,
        secondaryId: secondaryId,
        primaryName: primaryName,
        secondaryName: secondaryName,
        relationsTransferred: relationsTransferred1 + relationsTransferred2,
        factsTransferred: factsTransferred,
        aliasesTransferred: aliasesTransferred,
        relationsExpired: expiredRels.read<int>('cnt'),
        factsExpired: factsExpired,
      );
    });
  }

  /// Update embedding BLOB for an entity.
  Future<void> updateEntityEmbedding(int entityId, Uint8List embedding) async {
    await customStatement(
      'UPDATE entities SET embedding = ? WHERE id = ?',
      [embedding, entityId],
    );
  }

  /// One keyset page of active entity embeddings, ordered by id, strictly
  /// after [afterId] (U14). Drives the paged cosine scan in
  /// `KnowledgeService.queryRelevant` (every active embedding, at most
  /// [pageSize] BLOBs in memory at a time — no silent cap, no fully
  /// materialized embedding list) and the bounded dedup pre-filter scan in
  /// `CandidateGenerator.findCandidates`.
  Future<List<({int id, Uint8List embedding})>> getActiveEntityEmbeddingsPage({
    required int afterId,
    required int pageSize,
  }) async {
    final results = await customSelect(
      'SELECT id, embedding FROM entities '
      'WHERE is_active = 1 AND embedding IS NOT NULL AND id > ? '
      'ORDER BY id LIMIT ?',
      variables: [Variable.withInt(afterId), Variable.withInt(pageSize)],
    ).get();

    return results.map((r) {
      return (
        id: r.read<int>('id'),
        embedding: r.read<Uint8List>('embedding'),
      );
    }).toList();
  }

  /// Delete all data (forget everything).
  ///
  /// Drops FTS5 triggers before deleting to avoid corruption when
  /// DELETE triggers try to remove entries that were never indexed
  /// (expired facts, inactive entities).
  Future<void> deleteAllData() async {
    // 1. Drop FTS5 triggers + tables to prevent sync errors during mass DELETE
    await _dropFts5TablesAndTriggers();
    // 2. Delete all content rows
    await transaction(() async {
      await customStatement('DELETE FROM facts');
      await customStatement('DELETE FROM relations');
      await customStatement('DELETE FROM aliases');
      await customStatement('DELETE FROM summary_nodes');
      await customStatement('DELETE FROM entities');
    });
    // 4. Recreate empty FTS5 tables + triggers
    await _createFts5Tables();
  }
}

/// Result of merging two entities.
class MergeResult {
  final int primaryId;
  final int secondaryId;
  final String primaryName;
  final String secondaryName;
  final int relationsTransferred;
  final int factsTransferred;
  final int aliasesTransferred;
  final int relationsExpired;
  final int factsExpired;

  const MergeResult({
    required this.primaryId,
    required this.secondaryId,
    required this.primaryName,
    required this.secondaryName,
    required this.relationsTransferred,
    required this.factsTransferred,
    required this.aliasesTransferred,
    required this.relationsExpired,
    required this.factsExpired,
  });

  @override
  String toString() =>
      'Merged "$secondaryName" (#$secondaryId) → "$primaryName" (#$primaryId): '
      '$relationsTransferred relations transferred, $factsTransferred facts transferred, '
      '$aliasesTransferred aliases transferred, $relationsExpired relations expired, '
      '$factsExpired facts expired';
}
