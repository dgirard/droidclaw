// ignore_for_file: depend_on_referenced_packages

// M3: callers (e.g. the background task handler's _runKgPurge) must not reach
// through KnowledgeService.db. KnowledgeService.purgeColdEntities is a thin
// delegate to KnowledgeGraphDB.purgeColdEntities — this pins that it forwards
// correctly (count + actual deactivation) on an in-memory KG.

import 'package:drift/drift.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/in_memory_kg.dart';

void main() {
  late KnowledgeGraphDB db;
  late KnowledgeService service;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  const day = 86400;

  setUp(() {
    db = inMemoryKnowledgeGraphDB();
    service = KnowledgeService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seed({
    required String name,
    required String temperature,
    required int lastAccessed,
  }) {
    return db.into(db.entities).insert(EntitiesCompanion.insert(
          name: name,
          entityType: const Value('CONCEPT'),
          temperature: Value(temperature),
          lastAccessed: Value(lastAccessed),
        ));
  }

  Future<bool> isActive(int id) async {
    final row = await db.customSelect(
      'SELECT is_active FROM entities WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).getSingle();
    return row.read<int>('is_active') == 1;
  }

  test('purgeColdEntities delegates: deactivates old cold rows, returns count',
      () async {
    final oldCold = await seed(
        name: 'OldCold', temperature: 'cold', lastAccessed: now - 30 * day);
    final recentCold = await seed(
        name: 'RecentCold', temperature: 'cold', lastAccessed: now - 1 * day);
    final warm = await seed(
        name: 'Warm', temperature: 'warm', lastAccessed: now - 30 * day);

    final cutoff = now - 7 * day;
    final purged = await service.purgeColdEntities(cutoff);

    // Only the old cold entity crosses the cutoff.
    expect(purged, 1);
    expect(await isActive(oldCold), isFalse);
    expect(await isActive(recentCold), isTrue);
    expect(await isActive(warm), isTrue);
  });

  test('purgeColdEntities returns 0 when nothing qualifies', () async {
    await seed(name: 'Warm', temperature: 'warm', lastAccessed: now);
    expect(await service.purgeColdEntities(now - 7 * day), 0);
  });
}
