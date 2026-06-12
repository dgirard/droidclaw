// ignore_for_file: depend_on_referenced_packages

// U14: the vector path of queryRelevant must cover ALL active entity
// embeddings. Pre-U14 it loaded `getActiveEntityEmbeddings(limit: 1000)`
// once — every entity past the first 1000 rows was silently invisible to
// semantic search. Now the scan is keyset-paged ([embeddingScanPageSize]
// rows at a time, injectable here) with no total cap.

import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/counting_interceptor.dart';
import '../support/fake_embedding_provider.dart';

Uint8List _blob(List<double> v) =>
    Float32List.fromList(v).buffer.asUint8List();

void main() {
  late SelectCountingInterceptor counter;
  late KnowledgeGraphDB db;

  setUp(() {
    counter = SelectCountingInterceptor();
    db = KnowledgeGraphDB.forExecutor(
      NativeDatabase.memory().interceptWith(counter),
    );
  });
  tearDown(() => db.close());

  // Seeds [n] entities with embeddings. Only the LAST one (highest id)
  // matches the query vector [1,0,0,0]; all others are orthogonal. Entity
  // names share no token with the query, so retrieval can only succeed
  // through the vector path — and only if the scan reaches the final page.
  Future<int> seed(int n) async {
    var lastId = -1;
    for (var i = 0; i < n; i++) {
      lastId = await db.into(db.entities).insert(EntitiesCompanion.insert(
            name: 'Widget $i',
            entityType: const Value('CONCEPT'),
            summary: Value('inventory item number $i'),
          ));
      final isLast = i == n - 1;
      await db.updateEntityEmbedding(
        lastId,
        _blob(isLast ? [1.0, 0.0, 0.0, 0.0] : [0.0, 1.0, 0.0, 0.0]),
        model: 'fake',
        dim: 4,
      );
    }
    return lastId;
  }

  KnowledgeService service({required int pageSize}) => KnowledgeService(
        db: db,
        embeddingProvider: FakeEmbeddingProvider({
          'quantum banana smoothie': [1.0, 0.0, 0.0, 0.0],
        }),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
        embeddingScanPageSize: pageSize,
      );

  test(
      'semantic search covers entities beyond the first scan page '
      '(no silent cap)', () async {
    const pageSize = 3;
    const entityCount = 7; // 3 pages: 3 + 3 + 1
    final matchId = await seed(entityCount);

    final results =
        await service(pageSize: pageSize).queryRelevant('quantum banana smoothie');

    // The only matching entity sits on the LAST page. A capped scan
    // (pre-U14 behavior, cap == pageSize here) would silently drop it.
    expect(results, isNotEmpty);
    expect(results.first.entity.id, matchId);
    expect(results.first.entity.name, 'Widget ${entityCount - 1}');
    expect(results.first.vectorScore, greaterThan(0.0));
    expect(results.first.bm25Score, 0.0); // vector-only bridge
  });

  test('the scan pages through the whole KB (keyset pagination)', () async {
    const pageSize = 3;
    await seed(7);
    counter.reset();

    await service(pageSize: pageSize).queryRelevant('quantum banana smoothie');

    final pageQueries = counter.statements
        // Keyset page queries only (U3 added a space-counts query that also
        // mentions 'embedding IS NOT NULL').
        .where((s) => s.contains('embedding IS NOT NULL') && s.contains('id > ?'))
        .toList();
    // 7 entities at page size 3 → pages of 3, 3, 1 (last page short-circuits
    // the loop). Coverage is total: 3 page queries, not 1 capped load.
    expect(pageQueries, hasLength(3));
  });
}
