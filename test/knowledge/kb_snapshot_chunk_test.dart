// ignore_for_file: depend_on_referenced_packages

// U15: buildKBSnapshotChunks must bound each cleanup prompt. A large KG
// produces multiple chunks, each within the character budget; a small KG
// produces a single chunk; chunk boundaries never split an entity row, and
// an entity's outgoing relations stay in the same chunk as its row.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/kb_maintenance_service.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/fake_llm_provider.dart';

void main() {
  late KnowledgeGraphDB db;
  late KbMaintenanceService service;

  setUp(() {
    db = KnowledgeGraphDB.forExecutor(NativeDatabase.memory());
    service = KbMaintenanceService(
      db: db,
      knowledgeService: KnowledgeService(db: db),
      llmProvider: FakeLLMProvider.text('{"operations":[]}'),
      model: 'fake-model',
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Seeds [n] entities ('Ent 0'...'Ent n-1') with an alias and a fact each,
  /// plus a relation chain Ent i → Ent i+1. Returns the entity ids.
  Future<List<int>> seed(int n) async {
    final ids = <int>[];
    for (var i = 0; i < n; i++) {
      final id = await db.into(db.entities).insert(EntitiesCompanion.insert(
            name: 'Ent $i',
            entityType: const Value('CONCEPT'),
          ));
      ids.add(id);
      await db.into(db.aliases).insert(AliasesCompanion.insert(
            entityId: id,
            aliasName: 'alias-$i',
          ));
      await db.into(db.facts).insert(FactsCompanion.insert(
            entityId: id,
            factKey: 'serial',
            factValue: 'sn-$i',
          ));
    }
    for (var i = 0; i + 1 < n; i++) {
      await db.into(db.relations).insert(RelationsCompanion.insert(
            sourceId: ids[i],
            targetId: ids[i + 1],
            predicate: 'next_to',
          ));
    }
    return ids;
  }

  test('large KG produces multiple chunks, each within the size bound',
      () async {
    const budget = 800;
    final ids = await seed(60);

    final chunks = await service.buildKBSnapshotChunks(maxChunkChars: budget);

    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(chunk.length, lessThanOrEqualTo(budget),
          reason: 'every chunk must respect the character budget');
      // Each chunk is a self-contained pair of complete markdown tables.
      expect(chunk, startsWith('| ID | Name | Type | Facts | Aliases |'));
      expect(chunk, contains('| ID | Source | → | Target | Type |'));
    }

    // Every entity row appears in exactly one chunk (boundaries never split
    // or duplicate a row).
    for (final id in ids) {
      final occurrences = chunks
          .expand((c) => c.split('\n'))
          // Entity rows only — relation rows share the id column format but
          // never carry the entity type column.
          .where((line) =>
              line.startsWith('| $id | Ent ') && line.contains('| CONCEPT |'))
          .length;
      expect(occurrences, 1,
          reason: 'entity #$id must appear in exactly one chunk');
    }

    // Every relation appears exactly once across chunks.
    final relationRows = chunks
        .expand((c) => c.split('\n'))
        .where((line) => line.contains('| → |'))
        .where((line) => !line.contains('Source'))
        .length;
    expect(relationRows, 59);
  });

  test('chunk boundaries keep an entity and its outgoing relations together',
      () async {
    await seed(40);

    final chunks = await service.buildKBSnapshotChunks(maxChunkChars: 700);
    expect(chunks.length, greaterThan(1));

    for (var i = 0; i + 1 < 40; i++) {
      final ownerChunk = chunks.where((c) =>
          c.split('\n').any((line) => line.contains('| Ent $i | CONCEPT |')));
      expect(ownerChunk.length, 1);
      expect(ownerChunk.single, contains('| Ent $i | → | Ent ${i + 1} |'),
          reason: 'relation sourced at Ent $i must live in its chunk');
    }
  });

  test('small KG produces a single chunk with full content', () async {
    await seed(5);

    final chunks = await service.buildKBSnapshotChunks();

    expect(chunks, hasLength(1));
    final snapshot = chunks.single;
    for (var i = 0; i < 5; i++) {
      expect(snapshot, contains('| Ent $i | CONCEPT | 1 | alias-$i |'));
    }
    expect(snapshot, contains('| Ent 0 | → | Ent 1 | next_to |'));
    expect(snapshot, contains('| Ent 3 | → | Ent 4 | next_to |'));
  });

  test('empty KB produces one header-only chunk', () async {
    final chunks = await service.buildKBSnapshotChunks();
    expect(chunks, hasLength(1));
    expect(chunks.single, contains('| ID | Name | Type |'));
  });
}
