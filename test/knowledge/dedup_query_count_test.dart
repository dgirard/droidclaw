// ignore_for_file: depend_on_referenced_packages

// U14: KbMaintenanceService.findCandidates must issue a bounded number of
// DB round-trips. Pre-U14 it ran one getEntityRelationsWithNames query AND
// one facts SELECT per entity (up to 2 x 5000 queries per dream run). Now
// both loads are chunked IN (...) batches, so the SELECT count is constant
// in the entity count. findDuplicateFacts had the same N+1 (one facts
// SELECT per entity) until it was moved onto the same batch loader.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/kb_maintenance_service.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/counting_interceptor.dart';
import '../support/fake_llm_provider.dart';

void main() {
  // Seeds [n] entities sharing the "alpha" token (same blocking bucket, so
  // candidate pairs are actually generated), each with one fact, plus a
  // relation chain entity i → entity i+1.
  Future<void> seed(KnowledgeGraphDB db, int n) async {
    final ids = <int>[];
    for (var i = 0; i < n; i++) {
      final id = await db.into(db.entities).insert(EntitiesCompanion.insert(
            name: 'Alpha Variant $i',
            entityType: const Value('CONCEPT'),
            summary: Value('alpha test entity $i'),
          ));
      ids.add(id);
      await db.into(db.facts).insert(FactsCompanion.insert(
            entityId: id,
            factKey: 'serial',
            factValue: 'alpha-sn-$i',
          ));
    }
    for (var i = 0; i + 1 < n; i++) {
      await db.into(db.relations).insert(RelationsCompanion.insert(
            sourceId: ids[i],
            targetId: ids[i + 1],
            predicate: 'next_to',
          ));
    }
  }

  Future<int> selectsForFindCandidates(int entityCount) async {
    final counter = SelectCountingInterceptor();
    final db = KnowledgeGraphDB.forExecutor(
      NativeDatabase.memory().interceptWith(counter),
    );
    try {
      await seed(db, entityCount);
      final service = KbMaintenanceService(
        db: db,
        // No embedder → the embedding pre-filter (its own explicit bound)
        // stays out of the picture; this pins the relation/fact loads.
        knowledgeService: KnowledgeService(db: db),
        llmProvider: FakeLLMProvider.text('{"pairs":[]}'),
        model: 'fake-model',
      );
      counter.reset();
      final candidates = await service.findCandidates(fullScan: true);
      expect(candidates, isNotEmpty); // sanity: blocking produced pairs
      return counter.selectCount;
    } finally {
      await db.close();
    }
  }

  test(
      'findCandidates SELECT count is constant in entity count — '
      'batched relation/fact loads, no per-entity N+1', () async {
    final small = await selectsForFindCandidates(6);
    final large = await selectsForFindCandidates(18);

    // Pre-U14: 2 + 2*N selects (one relations query + one facts query per
    // entity) → 14 vs 38 here, thousands on a real dream run. Now:
    // listEntitiesFiltered + getAllActiveAliases + one relation chunk +
    // one fact chunk = 4 (chunking only kicks in past
    // AppConstants.knowledgeSqlInChunkSize ids).
    expect(large, equals(small),
        reason: 'DB round-trips must not scale with entity count');
    expect(large, lessThanOrEqualTo(4));
  });

  Future<int> selectsForFindDuplicateFacts(int entityCount) async {
    final counter = SelectCountingInterceptor();
    final db = KnowledgeGraphDB.forExecutor(
      NativeDatabase.memory().interceptWith(counter),
    );
    try {
      await seed(db, entityCount);
      // Add a second fact per entity (different key — active facts are
      // unique on (entity_id, fact_key)) so entities qualify for the
      // cross-key LLM bundles and the per-entity fact scan has work to do.
      for (var i = 1; i <= entityCount; i++) {
        await db.into(db.facts).insert(FactsCompanion.insert(
              entityId: i,
              factKey: 'code',
              factValue: 'ALPHA-SN-${i - 1}',
            ));
      }
      final service = KbMaintenanceService(
        db: db,
        knowledgeService: KnowledgeService(db: db),
        llmProvider: FakeLLMProvider.text('{"pairs":[]}'),
        model: 'fake-model',
      );
      counter.reset();
      final result = await service.findDuplicateFacts();
      expect(result.bundles, hasLength(entityCount)); // sanity: facts loaded
      return counter.selectCount;
    } finally {
      await db.close();
    }
  }

  test(
      'findDuplicateFacts SELECT count is constant in entity count — '
      'batched fact load, no per-entity N+1', () async {
    final small = await selectsForFindDuplicateFacts(6);
    final large = await selectsForFindDuplicateFacts(18);

    // Before the batch loader: 1 + N selects (one facts query per entity)
    // → 7 vs 19 here. Now: listEntitiesFiltered + one fact chunk = 2.
    expect(large, equals(small),
        reason: 'DB round-trips must not scale with entity count');
    expect(large, lessThanOrEqualTo(2));
  });
}
