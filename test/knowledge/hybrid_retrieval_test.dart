// ignore_for_file: depend_on_referenced_packages

import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';
import 'package:droidclaw/core/providers/embedding_provider.dart';

import '../support/in_memory_kg.dart';

/// Deterministic embedder: fixed vector per known input string, zero vector
/// otherwise (cosine similarity with the zero vector is 0 → never a match).
class FakeEmbeddingProvider implements EmbeddingProvider {
  final Map<String, List<double>> vectors;

  FakeEmbeddingProvider(this.vectors);

  @override
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  }) async =>
      EmbeddingResult(embeddings: [
        for (final t in texts) vectors[t] ?? const [0.0, 0.0, 0.0, 0.0],
      ]);

  @override
  String get providerName => 'fake';

  @override
  String get providerId => 'fake';

  @override
  int get outputDimensions => 4;

  @override
  Future<void> dispose() async {}
}

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

    await db.updateEntityEmbedding(didier, _blob([0.0, 1.0, 0.0, 0.0]));
    await db.updateEntityEmbedding(home, _blob([0.95, 0.05, 0.0, 0.0]));
    await db.updateEntityEmbedding(sfeir, _blob([0.0, 0.0, 1.0, 0.0]));
    await db.updateEntityEmbedding(eiffel, _blob([0.0, 0.0, 0.0, 1.0]));

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
        'CURRENT LIMITATION: zero lexical match short-circuits before the '
        'vector path runs (why AgentLoop._expandQueryForKG exists)', () async {
      // Characterization, not a requirement: today queryRelevant returns []
      // when FTS finds nothing at all, even though the embedder could bridge.
      // U12 may deliberately relax this — update this test if it does.
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
      expect(results, isEmpty);
    });
  });
}
