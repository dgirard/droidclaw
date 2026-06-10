// ignore_for_file: depend_on_referenced_packages

// U14: KbMaintenanceService.findCandidates must issue a bounded number of
// DB round-trips. Pre-U14 it ran one getEntityRelationsWithNames query AND
// one facts SELECT per entity (up to 2 x 5000 queries per dream run). Now
// both loads are chunked IN (...) batches, so the SELECT count is constant
// in the entity count.

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
}
