// ignore_for_file: depend_on_referenced_packages

import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/counting_interceptor.dart';
import '../support/fake_embedding_provider.dart';
import '../support/in_memory_kg.dart';

Uint8List _blob(List<double> v) =>
    Float32List.fromList(v).buffer.asUint8List();

void main() {
  late KnowledgeGraphDB db;

  setUp(() => db = inMemoryKnowledgeGraphDB());
  tearDown(() => db.close());

  // ── Seeded KG (the golden-baseline fixture — keep stable across refactors) ──
  //
  // Entities (4-dim embeddings; the paraphrased query maps to [1,0,0,0]):
  //   Didier Girard  PERSON  emb [0,1,0,0]      accessed 30 min ago
  //   Home           PLACE   emb [0.95,.05,0,0] accessed 30 min ago, fact address
  //   SFEIR          ORG     emb [0,0,1,0]      accessed 40 days ago, fact industry
  //   Eiffel Tower   PLACE   emb [0,0,0,1]      unrelated control entity
  // Relations:
  //   Didier —lives_at(0.9)→ Home
  //   Didier —works_at(0.8)→ SFEIR
  Future<({int didier, int home, int sfeir, int eiffel})> seedGraph() async {
    Future<int> entity(String name, String type, String summary) =>
        db.into(db.entities).insert(EntitiesCompanion.insert(
              name: name,
              entityType: Value(type),
              summary: Value(summary),
            ));

    final didier = await entity('Didier Girard', 'PERSON', 'the user');
    final home = await entity('Home', 'PLACE', 'primary residence');
    final sfeir = await entity('SFEIR', 'ORG', 'company where Didier works');
    final eiffel = await entity('Eiffel Tower', 'PLACE', 'landmark in Paris');

    await db.into(db.facts).insert(FactsCompanion.insert(
          entityId: home,
          factKey: 'address',
          factValue: '9 rue de la Paix, Paris',
        ));
    await db.into(db.facts).insert(FactsCompanion.insert(
          entityId: sfeir,
          factKey: 'industry',
          factValue: 'software consulting',
        ));

    await db.into(db.relations).insert(RelationsCompanion.insert(
          sourceId: didier,
          targetId: home,
          predicate: 'lives_at',
          weight: const Value(0.9),
        ));
    await db.into(db.relations).insert(RelationsCompanion.insert(
          sourceId: didier,
          targetId: sfeir,
          predicate: 'works_at',
          weight: const Value(0.8),
        ));

    // The fake embedder's space is ('fake', 4) — U3 stamps every vector.
    await db.updateEntityEmbedding(didier, _blob([0.0, 1.0, 0.0, 0.0]),
        model: 'fake', dim: 4);
    await db.updateEntityEmbedding(home, _blob([0.95, 0.05, 0.0, 0.0]),
        model: 'fake', dim: 4);
    await db.updateEntityEmbedding(sfeir, _blob([0.0, 0.0, 1.0, 0.0]),
        model: 'fake', dim: 4);
    await db.updateEntityEmbedding(eiffel, _blob([0.0, 0.0, 0.0, 1.0]),
        model: 'fake', dim: 4);

    // Deterministic decay: recent entities vs one long-cold entity.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Future<void> touch(int id, int epoch) => db.customStatement(
        'UPDATE entities SET last_accessed = ?, access_count = 1 WHERE id = ?',
        [epoch, id]);
    await touch(didier, now - 1800);
    await touch(home, now - 1800);
    await touch(sfeir, now - 40 * 86400);
    await touch(eiffel, now - 1800);

    return (didier: didier, home: home, sfeir: sfeir, eiffel: eiffel);
  }

  KnowledgeService serviceWithEmbedder() => KnowledgeService(
        db: db,
        embeddingProvider: FakeEmbeddingProvider({
          // Paraphrased query: no lexical overlap with "Home" or its address.
          'where does Didier live': [1.0, 0.0, 0.0, 0.0],
        }),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

  group('KnowledgeService.queryRelevant — hybrid fusion', () {
    test(
        'GOLDEN BASELINE: deterministic top-K for the seeded KG '
        '(U12/U14 must reproduce this exactly)', () async {
      await seedGraph();
      final results =
          await serviceWithEmbedder().queryRelevant('where does Didier live');

      // ════════════════════════════════════════════════════════════════
      // GOLDEN BASELINE — captured pre-U12 (FTS + vector + activation +
      // decay fusion, full-mode weights .30/.30/.25/.15):
      //
      //   1. Didier Girard  (best BM25: name match + activation + decay)
      //   2. Home           (vector-only bridge + decay; no BM25 match)
      //   3. SFEIR          (summary BM25 match + activation; decayed cold)
      //
      // "Eiffel Tower" is never a candidate (no lexical, vector, or graph
      // signal). A later refactor (U12) must reproduce names AND ordering.
      // ════════════════════════════════════════════════════════════════
      expect(
        results.map((r) => r.entity.name).toList(),
        ['Didier Girard', 'Home', 'SFEIR'],
      );

      // Fused scores strictly descending (sorted output).
      for (var i = 1; i < results.length; i++) {
        expect(results[i].score, lessThan(results[i - 1].score));
      }
    });

    test(
        'semantic gap: paraphrased query retrieves the address fact via the '
        'vector path (lexical FTS cannot match "Home")', () async {
      await seedGraph();
      final results =
          await serviceWithEmbedder().queryRelevant('where does Didier live');

      final home = results.firstWhere((r) => r.entity.name == 'Home');

      // The query shares no token with "Home"/"primary residence"/the address,
      // so the bridge MUST be the vector signal, not BM25.
      expect(home.vectorScore, greaterThan(0.0));
      expect(home.bm25Score, 0.0);

      // The documented regression: the address fact must come back attached.
      // (docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-
      //  tokenization-and-semantic-gap.md)
      expect(
        home.facts.map((f) => '${f.key}=${f.value}'),
        contains('address=9 rue de la Paix, Paris'),
      );
    });

    test('facts and relations are hydrated on results, not just entities',
        () async {
      await seedGraph();
      final results =
          await serviceWithEmbedder().queryRelevant('where does Didier live');

      final sfeir = results.firstWhere((r) => r.entity.name == 'SFEIR');
      expect(sfeir.facts.map((f) => f.key), contains('industry'));

      final didier =
          results.firstWhere((r) => r.entity.name == 'Didier Girard');
      expect(
        didier.relations.map((r) => r.predicate),
        containsAll(['lives_at', 'works_at']),
      );
    });

    test('unrelated entity never enters the candidate set', () async {
      await seedGraph();
      final results =
          await serviceWithEmbedder().queryRelevant('where does Didier live');
      expect(
        results.map((r) => r.entity.name),
        isNot(contains('Eiffel Tower')),
      );
    });
  });

  group('KnowledgeService.queryRelevant — facts-FTS path (degraded mode)', () {
    test('a stored fact value is retrievable lexically without any embedder',
        () async {
      // Pins the facts-FTS regression: searchFacts was once dead code, so
      // address facts were invisible to retrieval.
      await seedGraph();
      final service = KnowledgeService(db: db); // no embedder → degraded mode

      final results = await service.queryRelevant('rue Paix');

      expect(results, isNotEmpty);
      expect(results.first.entity.name, 'Home');
      expect(
        results.first.facts.map((f) => f.value),
        contains('9 rue de la Paix, Paris'),
      );
    });
  });

  group('KnowledgeService.queryRelevant — edge cases', () {
    test('empty query returns empty', () async {
      await seedGraph();
      expect(await serviceWithEmbedder().queryRelevant('   '), isEmpty);
    });

    test(
        'zero lexical match: the vector path still bridges (U12 removed the '
        'FTS short-circuit, so no LLM query expansion is needed)', () async {
      // Pre-U12 this returned [] because queryRelevant short-circuited when
      // FTS found nothing, even though the embedder could bridge. The
      // short-circuit was why AgentLoop._expandQueryForKG ran an extra LLM
      // call before every turn. Now the embedder alone retrieves the entity
      // and its facts.
      await seedGraph();
      final service = KnowledgeService(
        db: db,
        embeddingProvider: FakeEmbeddingProvider({
          'quantum banana smoothie': [0.95, 0.05, 0.0, 0.0], // ≈ Home
        }),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      final results = await service.queryRelevant('quantum banana smoothie');
      expect(results, isNotEmpty);
      expect(results.first.entity.name, 'Home');
      expect(results.first.bm25Score, 0.0); // vector-only bridge
      expect(
        results.first.facts.map((f) => '${f.key}=${f.value}'),
        contains('address=9 rue de la Paix, Paris'),
      );
    });

    test('no lexical and no vector match returns empty', () async {
      await seedGraph();
      final results =
          await serviceWithEmbedder().queryRelevant('quantum banana smoothie');
      expect(results, isEmpty); // unknown text embeds to the zero vector
    });
  });

  group('KnowledgeService.queryRelevant — vector candidate pool cap', () {
    test(
        'more than limit*3 entities above the threshold: only the top '
        'limit*3 by similarity become vector candidates', () async {
      // 10 entities whose names share no token with the query, all with
      // similarity to [1,0,0,0] above the 0.5 threshold, strictly
      // decreasing: VecOnly 0 is the closest, VecOnly 9 the farthest.
      const n = 10;
      for (var i = 0; i < n; i++) {
        final id = await db.into(db.entities).insert(
              EntitiesCompanion.insert(
                name: 'VecOnly $i',
                entityType: const Value('CONCEPT'),
                summary: const Value('semantic-only candidate'),
              ),
            );
        final theta = 0.1 + 0.08 * i; // cos: ~0.995 down to ~0.68, all > 0.5
        await db.updateEntityEmbedding(
            id, _blob([cos(theta), sin(theta), 0.0, 0.0]),
            model: 'fake', dim: 4);
      }

      final service = KnowledgeService(
        db: db,
        embeddingProvider: FakeEmbeddingProvider({
          'quantum banana smoothie': [1.0, 0.0, 0.0, 0.0],
        }),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      // limit=2 → vector pool capped at 6, though all 10 pass the threshold.
      final results =
          await service.queryRelevant('quantum banana smoothie', limit: 2);

      expect(service.lastVectorCandidateCount, 6,
          reason: 'the vector pool must mirror the FTS limit*3 cap');
      // The best-similarity entities still win the fused ranking.
      expect(results.map((r) => r.entity.name).toList(),
          ['VecOnly 0', 'VecOnly 1']);
    });
  });

  group('KnowledgeService.queryRelevant — embed failure observability', () {
    test(
        'query-time embed failure sets lastQueryVectorPathFailed and falls '
        'back to lexical-only; a healthy query resets it', () async {
      await seedGraph();
      final failing = KnowledgeService(
        db: db,
        embeddingProvider: FakeEmbeddingProvider(const {}, throwOnEmbed: true),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      final results = await failing.queryRelevant('rue Paix');

      expect(failing.lastQueryVectorPathFailed, isTrue,
          reason: 'the caller must be able to see the degraded vector path');
      // Lexical fallback still retrieves what FTS can match.
      expect(results, isNotEmpty);
      expect(results.first.entity.name, 'Home');

      final healthy = serviceWithEmbedder();
      await healthy.queryRelevant('where does Didier live');
      expect(healthy.lastQueryVectorPathFailed, isFalse);
    });
  });

  group('KnowledgeService.queryRelevant — bounded DB round-trips (U12)', () {
    // Seeds [n] entities, each with one fact and a relation chain
    // (Gadget i → Gadget i+1), all matching the FTS token "gadget".
    Future<void> seedChain(KnowledgeGraphDB cdb, int n) async {
      final ids = <int>[];
      for (var i = 0; i < n; i++) {
        final id = await cdb.into(cdb.entities).insert(
              EntitiesCompanion.insert(
                name: 'Gadget $i',
                entityType: const Value('CONCEPT'),
                summary: Value('test gadget number $i'),
              ),
            );
        ids.add(id);
        await cdb.into(cdb.facts).insert(FactsCompanion.insert(
              entityId: id,
              factKey: 'serial',
              factValue: 'gadget-sn-$i',
            ));
      }
      for (var i = 0; i + 1 < n; i++) {
        await cdb.into(cdb.relations).insert(RelationsCompanion.insert(
              sourceId: ids[i],
              targetId: ids[i + 1],
              predicate: 'next_to',
            ));
      }
    }

    Future<int> selectsForQuery(int entityCount) async {
      final counter = SelectCountingInterceptor();
      final cdb = KnowledgeGraphDB.forExecutor(
        NativeDatabase.memory().interceptWith(counter),
      );
      try {
        await seedChain(cdb, entityCount);
        counter.reset();
        final results =
            await KnowledgeService(db: cdb).queryRelevant('gadget serial');
        expect(results, isNotEmpty); // sanity: the query actually retrieves
        return counter.selectCount;
      } finally {
        await cdb.close();
      }
    }

    test(
        'SELECT count is constant in candidate count — batched loaders, '
        'no per-candidate N+1 loops', () async {
      final smallKg = await selectsForQuery(4);
      final largeKg = await selectsForQuery(16);

      // Pre-U12 this scaled with candidates: per-candidate findNeighbors
      // (2 hops), per-id getEntityById for decay, and per-result
      // entity+facts+neighbors re-fetches (30+ SELECTs at 16 entities).
      // Now: searchEntities, searchFacts, 2x findNeighborsBatch,
      // getEntitiesByIds, getFactsForEntityIds (+1 optional hop-2 top-K
      // neighbor batch) = at most 7 in degraded mode.
      expect(largeKg, equals(smallKg),
          reason: 'DB round-trips must not scale with candidate count');
      expect(largeKg, lessThanOrEqualTo(7));
    });
  });
}
