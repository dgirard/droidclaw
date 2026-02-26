import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'knowledge_graph_db.g.dart';

@DriftDatabase(include: {'schema.drift'})
class KnowledgeGraphDB extends _$KnowledgeGraphDB {
  KnowledgeGraphDB(String dbPath)
      : super(_openConnection(dbPath));

  @override
  int get schemaVersion => 1;

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
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA busy_timeout = 5000');
        },
      );

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

  /// Expire a relation bi-temporally.
  Future<void> expireRelation(int relationId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await customStatement(
      'UPDATE relations SET expired_at = ? WHERE id = ?',
      [now, relationId],
    );
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
  /// Returns the number of deactivated entities.
  Future<int> purgeColdEntities(int olderThanEpoch) async {
    return await transaction(() async {
      await customStatement(
        'UPDATE entities SET is_active = 0 '
        'WHERE temperature = \'cold\' AND last_accessed < ? AND is_active = 1',
        [olderThanEpoch],
      );
      final result = await customSelect('SELECT changes() AS cnt').getSingle();
      final count = result.read<int>('cnt');
      // Also deactivate orphaned relations
      if (count > 0) {
        await customStatement(
          'UPDATE relations SET is_active = 0 '
          'WHERE is_active = 1 AND ('
          '  source_id IN (SELECT id FROM entities WHERE is_active = 0) OR '
          '  target_id IN (SELECT id FROM entities WHERE is_active = 0))',
        );
      }
      return count;
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

  /// Soft-delete an entity and its relations (set is_active = 0).
  Future<void> deactivateEntity(int entityId) async {
    await transaction(() async {
      await customStatement(
        'UPDATE entities SET is_active = 0 WHERE id = ?',
        [entityId],
      );
      await customStatement(
        'UPDATE relations SET is_active = 0 WHERE source_id = ? OR target_id = ?',
        [entityId, entityId],
      );
    });
  }

  /// Delete all data (forget everything).
  Future<void> deleteAllData() async {
    await transaction(() async {
      await customStatement('DELETE FROM facts');
      await customStatement('DELETE FROM relations');
      await customStatement('DELETE FROM aliases');
      await customStatement('DELETE FROM summary_nodes');
      await customStatement('DELETE FROM entities');
    });
  }
}
