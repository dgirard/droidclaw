// ignore_for_file: depend_on_referenced_packages

// U3: versioned re-embed backfill toward a target embedding space.
//
// - Full pass moves every embedded entity into the target space.
// - Resumable by construction: a re-instantiated service (simulated kill)
//   continues without re-processing finished rows.
// - The query guard refuses to flip to the target space before coverage is
//   complete ("refuse-flip-before-complete").
// - Golden cutover: the golden top-K of test/knowledge/hybrid_retrieval_test
//   holds in space A before/during the backfill and in space B after the
//   flip, with zero cross-space cosine throughout.

import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/embedding_backfill_service.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';
import 'package:droidclaw/core/services/background_task_handler.dart';

import '../support/fake_embedding_provider.dart';
import '../support/in_memory_kg.dart';

Uint8List _blob(List<double> v) =>
    Float32List.fromList(v).buffer.asUint8List();

void main() {
  late KnowledgeGraphDB db;

  setUp(() => db = inMemoryKnowledgeGraphDB());
  tearDown(() => db.close());

  Future<int> seedEntity(
    String name, {
    String type = 'CONCEPT',
    String? summary,
    List<double>? vecA,
  }) async {
    final id = await db.into(db.entities).insert(EntitiesCompanion.insert(
          name: name,
          entityType: Value(type),
          summary: Value(summary),
        ));
    if (vecA != null) {
      await db.updateEntityEmbedding(id, _blob(vecA),
          model: 'space-a', dim: vecA.length);
    }
    return id;
  }

  /// Target provider for space B: 3-dim (a different dimensionality than
  /// space A's 4 — the cloud-768 → local-256 shape).
  FakeEmbeddingProvider providerB([Map<String, List<double>>? vectors]) =>
      FakeEmbeddingProvider(vectors ?? const {},
          providerId: 'space-b', dimensions: 3);

  EmbeddingBackfillService backfill(FakeEmbeddingProvider provider,
          {int batchSize = 2}) =>
      EmbeddingBackfillService(
        db: db,
        provider: provider,
        embeddingModel: 'model-b',
        batchSize: batchSize,
      );

  group('EmbeddingBackfillService', () {
    test('full pass re-embeds every row into the target space, rebuilding '
        'the exact ingestion text', () async {
      await seedEntity('Didier Girard',
          type: 'PERSON', summary: 'the user', vecA: [0, 1, 0, 0]);
      await seedEntity('Gadget', summary: 'a thing', vecA: [1, 0, 0, 0]);
      await seedEntity('Bare', vecA: [0, 0, 1, 0]); // no summary, CONCEPT
      await seedEntity('Unembedded'); // outside the backfill universe

      final provider = providerB({
        'Didier Girard (PERSON) : the user': [0.1, 0.2, 0.3],
      });
      final service = backfill(provider);

      final before = await service.progress();
      expect(before.total, 3);
      expect(before.remaining, 3);
      expect(before.isComplete, isFalse);

      final after = await service.runToCompletion();

      expect(after.isComplete, isTrue);
      expect(after.done, 3);
      // The embedded text is IngestionPipeline.buildEmbeddingText — type
      // omitted for CONCEPT, summary appended when present (the historical
      // ingestion format joins parts with spaces, hence ' : ').
      expect(
        provider.embeddedTexts,
        ['Didier Girard (PERSON) : the user', 'Gadget : a thing', 'Bare'],
      );

      final rows = await db.customSelect(
          'SELECT name, embedding, embedding_model, embedding_dim '
          'FROM entities ORDER BY id').get();
      for (final r in rows.take(3)) {
        expect(r.read<String>('embedding_model'), 'space-b');
        expect(r.read<int>('embedding_dim'), 3);
      }
      // The known vector landed; unknown texts got the fake's zero vector.
      expect(rows.first.read<Uint8List>('embedding'),
          _blob([0.1, 0.2, 0.3]));
      // The unembedded entity was left alone (spec: re-embed, not embed).
      expect(rows.last.readNullable<Uint8List>('embedding'), isNull);
      expect(rows.last.readNullable<String>('embedding_model'), isNull);
    });

    test('progress counts are exposed mid-run (batched slices)', () async {
      for (var i = 0; i < 5; i++) {
        await seedEntity('Entity $i', vecA: [1, 0, 0, 0]);
      }
      final service = backfill(providerB(), batchSize: 2);

      final p1 = await service.runSlice(maxBatches: 1);
      expect(p1.total, 5);
      expect(p1.done, 2);
      expect(p1.remaining, 3);

      final p2 = await service.runSlice(maxBatches: 1);
      expect(p2.done, 4);
      expect(p2.isComplete, isFalse);

      final p3 = await service.runSlice(maxBatches: 1);
      expect(p3.done, 5);
      expect(p3.isComplete, isTrue);
    });

    test('kill-resume: a re-instantiated service continues without '
        're-processing finished rows', () async {
      for (var i = 0; i < 5; i++) {
        await seedEntity('Entity $i', vecA: [1, 0, 0, 0]);
      }

      // First service processes one batch, then "dies" (is dropped).
      final providerFirst = providerB();
      await backfill(providerFirst, batchSize: 2).runSlice(maxBatches: 1);
      expect(providerFirst.embeddedTexts, hasLength(2));

      // A brand-new service instance resumes purely from the WHERE clause.
      final providerSecond = providerB();
      final after =
          await backfill(providerSecond, batchSize: 2).runToCompletion();

      expect(after.isComplete, isTrue);
      expect(providerSecond.embeddedTexts, hasLength(3),
          reason: 'only the 3 remaining rows are re-embedded');
      expect(
        {...providerFirst.embeddedTexts, ...providerSecond.embeddedTexts},
        hasLength(5),
        reason: 'no entity is processed twice across the restart',
      );
    });

    test('a failed batch is resumable: completed rows stay done', () async {
      for (var i = 0; i < 4; i++) {
        await seedEntity('Entity $i', vecA: [1, 0, 0, 0]);
      }
      final okThenDead = providerB();
      final service = backfill(okThenDead, batchSize: 2);
      await service.runSlice(maxBatches: 1); // 2 done

      final dead = FakeEmbeddingProvider(const {},
          providerId: 'space-b', dimensions: 3, throwOnEmbed: true);
      await expectLater(
          backfill(dead, batchSize: 2).runSlice(), throwsStateError);

      final p = await backfill(providerB(), batchSize: 2).progress();
      expect(p.done, 2, reason: 'the failure lost nothing already written');
    });

    test('cancel stops between slices and the job stays resumable',
        () async {
      for (var i = 0; i < 5; i++) {
        await seedEntity('Entity $i', vecA: [1, 0, 0, 0]);
      }
      final service = backfill(providerB(), batchSize: 1);

      late BackfillProgress seen;
      final p = await service.runToCompletion(onProgress: (progress) {
        seen = progress;
        service.cancel();
      });

      expect(seen.done, 1, reason: 'cancelled after the first slice');
      expect(p.isComplete, isFalse);

      final resumed = await service.runToCompletion();
      expect(resumed.isComplete, isTrue);
    });
  });

  group('refuse-flip-before-complete (query guard integration)', () {
    test('with the provider flipped early, queries do NOT use the partial '
        'target space until coverage is complete', () async {
      for (var i = 0; i < 4; i++) {
        await seedEntity('Entity $i', vecA: [1, 0, 0, 0]);
      }
      final provider = providerB();
      final service = backfill(provider, batchSize: 1);
      await service.runSlice(maxBatches: 1); // 1 of 4 in space B

      // KnowledgeService already flipped to provider B (premature flip).
      final flipped = KnowledgeService(
        db: db,
        embeddingProvider: provider,
        embeddingModel: 'model-b',
        embeddingDimensions: 3,
      );
      final selection = (await flipped.resolveQuerySpace())!;
      expect(selection.isActiveSpace, isFalse,
          reason: 'space-b covers 1/4 — the dominant space-a still rules');
      expect(selection.model, 'space-a');
      expect(selection.isComplete, isFalse);

      // After completion the flip is accepted.
      await service.runToCompletion();
      final after = (await flipped.resolveQuerySpace(refresh: true))!;
      expect(after.isActiveSpace, isTrue);
      expect(after.model, 'space-b');
      expect(after.isComplete, isTrue);
    });
  });

  group('charging gate (service isolate scheduling)', () {
    test('a slice runs ONLY when charging + local configured + model ready '
        '+ backfill incomplete', () {
      bool gate({
        bool charging = true,
        bool configured = true,
        bool ready = true,
        bool incomplete = true,
      }) =>
          BackgroundTaskHandler.shouldRunBackfillSlice(
            charging: charging,
            localProviderConfigured: configured,
            localModelReady: ready,
            backfillIncomplete: incomplete,
          );

      expect(gate(), isTrue);
      expect(gate(charging: false), isFalse);
      expect(gate(configured: false), isFalse);
      expect(gate(ready: false), isFalse);
      expect(gate(incomplete: false), isFalse,
          reason: 'a complete backfill must not burn battery re-checking');
    });

    test('the cached backfill service is rebuilt when embedding dims change '
        'mid-run, but not otherwise (C2/A4/R3)', () {
      // No service cached yet → nothing to rebuild.
      expect(
          BackgroundTaskHandler.backfillServiceDimsStale(
              serviceDims: null, currentDims: 256),
          isFalse);
      // Same dims → keep the cached service.
      expect(
          BackgroundTaskHandler.backfillServiceDimsStale(
              serviceDims: 256, currentDims: 256),
          isFalse);
      // Dims changed in settings mid-run → rebuild so the new provider writes
      // at the new dim (no OLD-dim vectors → no mixed-space provenance).
      expect(
          BackgroundTaskHandler.backfillServiceDimsStale(
              serviceDims: 768, currentDims: 256),
          isTrue);
    });
  });

  group('golden cutover (space A → space B)', () {
    // The golden fixture of hybrid_retrieval_test, embedded in space A
    // ('space-a', 4 dims). The paraphrased query maps to [1,0,0,0]; only
    // Home's vector is similar to it.
    late int didier, home, sfeir, eiffel;

    Future<void> seedGolden() async {
      didier = await seedEntity('Didier Girard',
          type: 'PERSON', summary: 'the user', vecA: [0, 1, 0, 0]);
      home = await seedEntity('Home',
          type: 'PLACE',
          summary: 'primary residence',
          vecA: [0.95, 0.05, 0, 0]);
      sfeir = await seedEntity('SFEIR',
          type: 'ORG',
          summary: 'company where Didier works',
          vecA: [0, 0, 1, 0]);
      eiffel = await seedEntity('Eiffel Tower',
          type: 'PLACE', summary: 'landmark in Paris', vecA: [0, 0, 0, 1]);

      await db.into(db.facts).insert(FactsCompanion.insert(
          entityId: home,
          factKey: 'address',
          factValue: '9 rue de la Paix, Paris'));
      await db.into(db.relations).insert(RelationsCompanion.insert(
          sourceId: didier,
          targetId: home,
          predicate: 'lives_at',
          weight: const Value(0.9)));
      await db.into(db.relations).insert(RelationsCompanion.insert(
          sourceId: didier,
          targetId: sfeir,
          predicate: 'works_at',
          weight: const Value(0.8)));

      // Deterministic decay (mirrors the golden fixture): SFEIR is cold.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      Future<void> touch(int id, int epoch) => db.customStatement(
          'UPDATE entities SET last_accessed = ?, access_count = 1 '
          'WHERE id = ?',
          [epoch, id]);
      await touch(didier, now - 1800);
      await touch(home, now - 1800);
      await touch(sfeir, now - 40 * 86400);
      await touch(eiffel, now - 1800);
    }

    const goldenTopK = ['Didier Girard', 'Home', 'SFEIR'];

    FakeEmbeddingProvider queryProviderA() => FakeEmbeddingProvider({
          'where does Didier live': [1.0, 0.0, 0.0, 0.0],
        }, providerId: 'space-a', dimensions: 4);

    // Space-B vectors: same geometry, 3 dims. Document vectors are keyed by
    // the backfill's rebuilt embedding texts; the query maps near Home.
    FakeEmbeddingProvider providerBGolden() => providerB({
          'where does Didier live': [1.0, 0.0, 0.0],
          'Didier Girard (PERSON) : the user': [0.0, 1.0, 0.0],
          'Home (PLACE) : primary residence': [0.95, 0.05, 0.0],
          'SFEIR (ORG) : company where Didier works': [0.0, 0.0, 1.0],
          'Eiffel Tower (PLACE) : landmark in Paris': [0.0, 0.7071, 0.7071],
        });

    KnowledgeService serviceA() => KnowledgeService(
          db: db,
          embeddingProvider: queryProviderA(),
          embeddingModel: 'model-a',
          embeddingDimensions: 4,
        );

    test('golden top-K holds in space A before the backfill (baseline)',
        () async {
      await seedGolden();
      final results = await serviceA().queryRelevant('where does Didier live');
      expect(results.map((r) => r.entity.name).toList(), goldenTopK);
    });

    test('DURING a partial backfill, queries still use space A and the '
        'golden top-K is identical', () async {
      await seedGolden();

      // One row (lowest id: Didier) moves to space B.
      await backfill(providerBGolden(), batchSize: 1)
          .runSlice(maxBatches: 1);

      final s = serviceA();
      final results = await s.queryRelevant('where does Didier live');

      expect(s.currentQuerySpace!.model, 'space-a',
          reason: 'space A still dominates (3 rows vs 1) — no partial-space '
              'queries');
      expect(results.map((r) => r.entity.name).toList(), goldenTopK,
          reason: 'the cutover must be invisible until it completes');
      // Zero cross-space cosine: only Home (still in space A) has a vector
      // signal; Didier's space-B vector must not be compared.
      final homeResult = results.firstWhere((r) => r.entity.name == 'Home');
      expect(homeResult.vectorScore, greaterThan(0.0));
      expect(s.lastVectorCandidateCount, 1,
          reason: 'exactly one space-A vector passes the threshold; any '
              'space-B comparison would be a cross-space cosine');
    });

    test('AFTER the complete backfill + flip, the golden top-K is correct '
        'in space B and the semantic-gap bridge still works', () async {
      await seedGolden();

      final provider = providerBGolden();
      final progress = await backfill(provider).runToCompletion();
      expect(progress.isComplete, isTrue);

      // The flip: a service built on provider B (config change rebuild).
      final flipped = KnowledgeService(
        db: db,
        embeddingProvider: provider,
        embeddingModel: 'model-b',
        embeddingDimensions: 3,
      );
      final results =
          await flipped.queryRelevant('where does Didier live');

      final selection = flipped.currentQuerySpace!;
      expect(selection.model, 'space-b');
      expect(selection.isActiveSpace, isTrue);
      expect(selection.isComplete, isTrue);
      expect(flipped.lastQueryVectorPathFailed, isFalse);

      expect(results.map((r) => r.entity.name).toList(), goldenTopK);
      // The semantic-gap case: "Home" is reachable only via the vector
      // path (no lexical overlap), now served by space B, with its fact.
      final homeResult = results.firstWhere((r) => r.entity.name == 'Home');
      expect(homeResult.vectorScore, greaterThan(0.0));
      expect(homeResult.bm25Score, 0.0);
      expect(homeResult.facts.map((f) => '${f.key}=${f.value}'),
          contains('address=9 rue de la Paix, Paris'));
    });
  });
}
