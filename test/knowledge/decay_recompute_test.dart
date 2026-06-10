// ignore_for_file: depend_on_referenced_packages

// U15: KnowledgeService.recalculateDecay must not load and recompute every
// active entity each hour. Non-cold rows are always candidates (they can
// still decay downward), but cold rows are only recomputed when a recent
// access could have pushed retention back above the cool threshold. The
// recompute then issues UPDATEs only for rows whose temperature actually
// crossed a threshold.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/algorithms/memory_decay.dart';
import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/counting_interceptor.dart';

void main() {
  late KnowledgeGraphDB db;
  late UpdateCountingInterceptor counter;
  late KnowledgeService service;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    counter = UpdateCountingInterceptor();
    db = KnowledgeGraphDB.forExecutor(
      NativeDatabase.memory().interceptWith(counter),
    );
    service = KnowledgeService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEntity({
    required String name,
    required String temperature,
    required int lastAccessed,
    int accessCount = 1,
  }) {
    return db.into(db.entities).insert(EntitiesCompanion.insert(
          name: name,
          entityType: const Value('CONCEPT'),
          temperature: Value(temperature),
          lastAccessed: Value(lastAccessed),
          accessCount: Value(accessCount),
        ));
  }

  Future<String> temperatureOf(int id) async {
    final row = await db.customSelect(
      'SELECT temperature FROM entities WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).getSingle();
    return row.read<String>('temperature');
  }

  test('recalculateDecay updates only threshold-crossing rows', () async {
    // Stays hot: just accessed → retention 1.0.
    final hotFresh = await seedEntity(
        name: 'hot fresh', temperature: 'hot', lastAccessed: now);
    // Crosses hot → cold: untouched for 30 days, accessCount 1.
    final hotStale = await seedEntity(
        name: 'hot stale',
        temperature: 'hot',
        lastAccessed: now - 30 * 86400);
    // Stays warm: t = 0.5 * stability(1) → retention exp(-0.5) ≈ 0.61.
    final warmMid = await seedEntity(
        name: 'warm mid',
        temperature: 'warm',
        lastAccessed: now - (0.5 * MemoryDecay.stability(1)).round());
    // Stays cold AND is excluded from the recompute entirely: 90 days stale.
    final coldStale = await seedEntity(
        name: 'cold stale',
        temperature: 'cold',
        lastAccessed: now - 90 * 86400);
    // Crosses cold → hot: cold label but just touched (access updates
    // last_accessed without reclassifying temperature).
    final coldFresh = await seedEntity(
        name: 'cold fresh', temperature: 'cold', lastAccessed: now);

    counter.reset();
    final changed = await service.recalculateDecay();

    expect(changed, 2, reason: 'exactly hotStale and coldFresh cross');
    expect(counter.updateCount, 2,
        reason: 'one UPDATE per crossing row, none for stable rows');

    expect(await temperatureOf(hotFresh), 'hot');
    expect(await temperatureOf(hotStale), 'cold');
    expect(await temperatureOf(warmMid), 'warm');
    expect(await temperatureOf(coldStale), 'cold');
    expect(await temperatureOf(coldFresh), 'hot');
  });

  test('all-stale-cold KB issues zero updates', () async {
    for (var i = 0; i < 20; i++) {
      await seedEntity(
          name: 'cold $i',
          temperature: 'cold',
          lastAccessed: now - (60 + i) * 86400);
    }

    counter.reset();
    final changed = await service.recalculateDecay();

    expect(changed, 0);
    expect(counter.updateCount, 0);
  });

  test('getDecayCandidates excludes cold rows older than the cutoff',
      () async {
    final coldStale = await seedEntity(
        name: 'cold stale',
        temperature: 'cold',
        lastAccessed: now - 90 * 86400);
    final coldFresh = await seedEntity(
        name: 'cold fresh', temperature: 'cold', lastAccessed: now - 100);
    final warm = await seedEntity(
        name: 'warm any',
        temperature: 'warm',
        lastAccessed: now - 365 * 86400);

    final candidates = await db.getDecayCandidates(now - 86400);
    final ids = candidates.map((c) => c.id).toSet();

    expect(ids, contains(coldFresh), reason: 'recently touched cold row');
    expect(ids, contains(warm), reason: 'non-cold rows are always candidates');
    expect(ids, isNot(contains(coldStale)),
        reason: 'stale cold rows provably stay cold');
  });

  test('high-access cold row recently touched is still recomputed '
      '(superset cutoff uses max cold access count)', () async {
    // stability(50) ≈ 6.9 days, so 3 days of age leaves retention ≈ 0.65
    // (warm) — well above the cool threshold, yet far older than the
    // cutoff an accessCount=1 row would get. The cutoff must widen to the
    // max access count among cold rows so this row is not missed.
    final coldHighAccess = await seedEntity(
        name: 'cold high access',
        temperature: 'cold',
        lastAccessed: now - 3 * 86400,
        accessCount: 50);

    final changed = await service.recalculateDecay();

    expect(changed, 1);
    expect(await temperatureOf(coldHighAccess), 'warm');
  });
}
