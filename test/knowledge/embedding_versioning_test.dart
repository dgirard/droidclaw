// ignore_for_file: depend_on_referenced_packages

// U3: embedding provenance + active-space query guard.
//
// - Migration v3→v4 annotates pre-existing vectors with the legacy marker
//   and a dimension computed from the blob's actual byte length.
// - Every new vector write stamps its space (provider id + dim).
// - The query guard picks ONE space per query and the page loader's WHERE
//   clause makes cross-space cosine structurally impossible.

import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/fake_embedding_provider.dart';
import '../support/in_memory_kg.dart';

Uint8List _blob(List<double> v) =>
    Float32List.fromList(v).buffer.asUint8List();

/// Creates an in-memory database with the PRE-U3 (v3) physical schema for
/// the three embedding-bearing tables — no provenance columns — and
/// `user_version = 3`, so opening it through [KnowledgeGraphDB] runs the
/// v3→v4 migration exactly as it would on an upgraded device.
sqlite3.Database _seededV3Database() {
  final raw = sqlite3.sqlite3.openInMemory();
  raw.execute('''
    CREATE TABLE entities (
      id            INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name          TEXT    NOT NULL,
      entity_type   TEXT    NOT NULL DEFAULT 'CONCEPT',
      summary       TEXT,
      properties    TEXT    NOT NULL DEFAULT '{}',
      embedding     BLOB,
      created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      valid_at      INTEGER,
      invalid_at    INTEGER,
      ingested_at   INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      expired_at    INTEGER,
      last_accessed INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      access_count  INTEGER NOT NULL DEFAULT 1,
      temperature   TEXT    NOT NULL DEFAULT 'warm',
      base_score    REAL    NOT NULL DEFAULT 0.5,
      parent_summary_id INTEGER,
      is_active     INTEGER NOT NULL DEFAULT 1
    );
  ''');
  raw.execute('''
    CREATE TABLE relations (
      id            INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      source_id     INTEGER NOT NULL,
      target_id     INTEGER NOT NULL,
      predicate     TEXT    NOT NULL,
      weight        REAL    NOT NULL DEFAULT 1.0,
      properties    TEXT    NOT NULL DEFAULT '{}',
      embedding     BLOB,
      created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      valid_at      INTEGER,
      invalid_at    INTEGER,
      ingested_at   INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      expired_at    INTEGER,
      last_accessed INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      access_count  INTEGER NOT NULL DEFAULT 1,
      confidence    REAL    NOT NULL DEFAULT 1.0,
      source_text   TEXT,
      is_active     INTEGER NOT NULL DEFAULT 1
    );
  ''');
  raw.execute('''
    CREATE TABLE summary_nodes (
      id            INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      parent_id     INTEGER,
      level         INTEGER NOT NULL DEFAULT 0,
      summary_text  TEXT    NOT NULL,
      embedding     BLOB,
      member_ids    TEXT    NOT NULL DEFAULT '[]',
      cluster_label INTEGER,
      created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      last_updated  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
    );
  ''');

  // Minimal v3 companions so queryRelevant can run post-migration: the
  // facts table and (empty) FTS5 indexes. The v4 migration touches neither.
  raw.execute('''
    CREATE TABLE facts (
      id            INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      entity_id     INTEGER NOT NULL,
      fact_key      TEXT    NOT NULL,
      fact_value    TEXT    NOT NULL,
      value_type    TEXT    NOT NULL DEFAULT 'string',
      valid_at      INTEGER,
      invalid_at    INTEGER,
      ingested_at   INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      expired_at    INTEGER,
      confidence    REAL    NOT NULL DEFAULT 1.0,
      source_text   TEXT
    );
  ''');
  raw.execute('''
    CREATE VIRTUAL TABLE entities_fts USING fts5(
      name, summary, entity_type,
      content=entities, content_rowid=id, prefix='2 3', tokenize='unicode61'
    );
  ''');
  raw.execute('''
    CREATE VIRTUAL TABLE facts_fts USING fts5(
      fact_key, fact_value,
      content=facts, content_rowid=id, prefix='2 3', tokenize='unicode61'
    );
  ''');

  // Seed: a 4-dim vector, a 768-dim vector, and an embedding-less entity.
  final insertEntity = raw.prepare(
      'INSERT INTO entities (name, embedding) VALUES (?, ?)');
  insertEntity.execute(['Four Dims', _blob([1, 0, 0, 0])]);
  insertEntity.execute(['Big Cloud', _blob(List.filled(768, 0.5))]);
  insertEntity.execute(['No Vector', null]);
  insertEntity.dispose();
  raw.execute(
      'INSERT INTO relations (source_id, target_id, predicate, embedding) '
      'VALUES (1, 2, ?, ?)',
      ['knows', _blob([0, 1, 0, 0])]);
  raw.execute(
      'INSERT INTO summary_nodes (summary_text, embedding) VALUES (?, ?)',
      ['a cluster summary', _blob([0, 0, 1, 0])]);

  raw.execute('PRAGMA user_version = 3');
  return raw;
}

void main() {
  group('v3→v4 migration', () {
    late KnowledgeGraphDB db;

    setUp(() {
      db = KnowledgeGraphDB.forExecutor(
          NativeDatabase.opened(_seededV3Database()));
    });
    tearDown(() => db.close());

    test(
        'pre-existing vectors get the legacy marker and a dim computed from '
        'the blob byte length, on all three embedding-bearing tables',
        () async {
      final entities = await db.customSelect(
          'SELECT name, embedding_model, embedding_dim FROM entities '
          'ORDER BY id').get();

      expect(entities[0].read<String>('name'), 'Four Dims');
      expect(entities[0].read<String>('embedding_model'),
          AppConstants.knowledgeLegacyEmbeddingModel);
      expect(entities[0].read<int>('embedding_dim'), 4);

      expect(entities[1].read<String>('name'), 'Big Cloud');
      expect(entities[1].read<int>('embedding_dim'), 768);

      // Rows without a vector get NO provenance: the columns mirror the
      // embedding column's NULL-ness.
      expect(entities[2].readNullable<String>('embedding_model'), isNull);
      expect(entities[2].readNullable<int>('embedding_dim'), isNull);

      final relation = await db.customSelect(
          'SELECT embedding_model, embedding_dim FROM relations').getSingle();
      expect(relation.read<String>('embedding_model'),
          AppConstants.knowledgeLegacyEmbeddingModel);
      expect(relation.read<int>('embedding_dim'), 4);

      final summaryNode = await db.customSelect(
          'SELECT embedding_model, embedding_dim FROM summary_nodes')
          .getSingle();
      expect(summaryNode.read<String>('embedding_model'),
          AppConstants.knowledgeLegacyEmbeddingModel);
      expect(summaryNode.read<int>('embedding_dim'), 4);

      final version =
          await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, 4);
    });

    test('legacy rows are queryable through the guard with a same-dim '
        'provider (best-guess compatibility of the migration marker)',
        () async {
      // Provider 'fake'/4d, all stored rows 'legacy:pre-v4'. The active
      // space has zero rows, so the dominant (legacy) space serves queries.
      final service = KnowledgeService(
        db: db,
        embeddingProvider: FakeEmbeddingProvider({
          'quantum banana smoothie': [1.0, 0.0, 0.0, 0.0],
        }),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      final results = await service.queryRelevant('quantum banana smoothie');

      final selection = service.currentQuerySpace!;
      expect(selection.model, AppConstants.knowledgeLegacyEmbeddingModel);
      expect(selection.dim, 4);
      expect(selection.isActiveSpace, isFalse);
      expect(selection.usable, isTrue);
      expect(service.lastQueryVectorPathFailed, isFalse);
      // 'Four Dims' [1,0,0,0] matches the query vector via the legacy space.
      expect(results.map((r) => r.entity.name), contains('Four Dims'));
    });
  });

  group('write-path provenance', () {
    late KnowledgeGraphDB db;

    setUp(() => db = inMemoryKnowledgeGraphDB());
    tearDown(() => db.close());

    Future<int> entity(String name) => db.into(db.entities).insert(
        EntitiesCompanion.insert(name: name, summary: const Value('x')));

    test('updateEntityEmbedding stamps model and dim with the vector',
        () async {
      final id = await entity('Stamped');
      await db.updateEntityEmbedding(id, _blob([1, 0, 0, 0]),
          model: 'gemini', dim: 4);

      final row = await db.customSelect(
          'SELECT embedding_model, embedding_dim FROM entities WHERE id = ?',
          variables: [Variable.withInt(id)]).getSingle();
      expect(row.read<String>('embedding_model'), 'gemini');
      expect(row.read<int>('embedding_dim'), 4);
    });

    test('deactivating an entity clears the provenance with the vector',
        () async {
      final id = await entity('Gone');
      await db.updateEntityEmbedding(id, _blob([1, 0, 0, 0]),
          model: 'gemini', dim: 4);

      await db.deactivateEntity(id);

      final row = await db.customSelect(
          'SELECT embedding, embedding_model, embedding_dim FROM entities '
          'WHERE id = ?',
          variables: [Variable.withInt(id)]).getSingle();
      expect(row.readNullable<Uint8List>('embedding'), isNull);
      expect(row.readNullable<String>('embedding_model'), isNull);
      expect(row.readNullable<int>('embedding_dim'), isNull);
    });

    test('merging entities clears the primary\'s stale provenance', () async {
      final primary = await entity('Primary');
      final secondary = await entity('Secondary');
      await db.updateEntityEmbedding(primary, _blob([1, 0, 0, 0]),
          model: 'gemini', dim: 4);
      await db.updateEntityEmbedding(secondary, _blob([0, 1, 0, 0]),
          model: 'gemini', dim: 4);

      await db.mergeEntities(primary, secondary);

      final row = await db.customSelect(
          'SELECT embedding, embedding_model, embedding_dim FROM entities '
          'WHERE id = ?',
          variables: [Variable.withInt(primary)]).getSingle();
      expect(row.readNullable<Uint8List>('embedding'), isNull);
      expect(row.readNullable<String>('embedding_model'), isNull);
      expect(row.readNullable<int>('embedding_dim'), isNull);
    });

    test('getEmbeddingSpaceCounts groups active embedded entities by space',
        () async {
      for (var i = 0; i < 3; i++) {
        final id = await entity('A$i');
        await db.updateEntityEmbedding(id, _blob([1, 0, 0, 0]),
            model: 'space-a', dim: 4);
      }
      final b = await entity('B0');
      await db.updateEntityEmbedding(b, _blob([1, 0, 0]),
          model: 'space-b', dim: 3);
      await entity('NoVector');

      final counts = await db.getEmbeddingSpaceCounts();
      expect(counts, hasLength(2));
      expect(counts[0], (model: 'space-a', dim: 4, count: 3));
      expect(counts[1], (model: 'space-b', dim: 3, count: 1));
    });
  });

  group('active-space query guard', () {
    late KnowledgeGraphDB db;

    setUp(() => db = inMemoryKnowledgeGraphDB());
    tearDown(() => db.close());

    Future<int> seed(String name, List<double> vec, String model) async {
      final id = await db.into(db.entities).insert(
          EntitiesCompanion.insert(name: name, summary: const Value('s')));
      await db.updateEntityEmbedding(id, _blob(vec),
          model: model, dim: vec.length);
      return id;
    }

    KnowledgeService service() => KnowledgeService(
          db: db,
          embeddingProvider: FakeEmbeddingProvider({
            'quantum banana smoothie': [1.0, 0.0, 0.0, 0.0],
          }),
          embeddingModel: 'fake-model',
          embeddingDimensions: 4,
        );

    test('the active space wins when its row count >= every other space',
        () async {
      await seed('Mine 1', [1, 0, 0, 0], 'fake');
      await seed('Mine 2', [0, 1, 0, 0], 'fake');
      await seed('Other', [1, 0, 0, 0], 'other-model');

      final s = service();
      final selection = (await s.resolveQuerySpace())!;
      expect(selection.model, 'fake');
      expect(selection.dim, 4);
      expect(selection.isActiveSpace, isTrue);
      expect(selection.rowCount, 2);
      expect(selection.totalEmbedded, 3);
      expect(selection.isComplete, isFalse);
    });

    test('a dominant foreign space serves queries while the active space '
        'is still a minority (incomplete backfill)', () async {
      await seed('Mine', [1, 0, 0, 0], 'fake');
      await seed('Old 1', [1, 0, 0, 0], 'old-model');
      await seed('Old 2', [0, 1, 0, 0], 'old-model');
      await seed('Old 3', [0, 0, 1, 0], 'old-model');

      final selection = (await service().resolveQuerySpace())!;
      expect(selection.model, 'old-model');
      expect(selection.isActiveSpace, isFalse);
      expect(selection.usable, isTrue, reason: 'same dim → scannable');
      expect(selection.rowCount, 3);
    });

    test('a dimension-incompatible dominant space degrades retrieval to '
        'lexical and flags the vector path as failed', () async {
      await seed('Old 1', [1, 0, 0, 0, 0, 0, 0, 0], 'old-768ish');
      await seed('Old 2', [0, 1, 0, 0, 0, 0, 0, 0], 'old-768ish');

      final s = service();
      final results = await s.queryRelevant('quantum banana smoothie');

      expect(s.currentQuerySpace!.usable, isFalse);
      expect(s.lastQueryVectorPathFailed, isTrue,
          reason: 'callers must retry with LLM keyword expansion');
      expect(results, isEmpty, reason: 'no lexical match, no usable space');
    });

    test('ZERO cross-space cosine: a same-dim foreign vector identical to '
        'the query never becomes a candidate (page loader WHERE)', () async {
      // Active space content is orthogonal to the query...
      await seed('Honest Row', [0, 1, 0, 0], 'fake');
      await seed('Honest Row 2', [0, 0, 1, 0], 'fake');
      // ...while a foreign space (same dim!) contains a perfect match.
      final intruder = await seed('Intruder', [1, 0, 0, 0], 'other-model');

      final s = service();
      final results = await s.queryRelevant('quantum banana smoothie');

      expect(s.currentQuerySpace!.model, 'fake');
      expect(results.map((r) => r.entity.id), isNot(contains(intruder)),
          reason: 'a cosine across spaces would have surfaced the intruder');
      expect(s.lastVectorCandidateCount, 0,
          reason: 'active-space vectors are orthogonal to the query; the '
              'foreign perfect match must never be compared');
    });

    test('an empty KB is not cached: embeddings ingested later are picked '
        'up without a service rebuild', () async {
      final s = service();
      expect(await s.resolveQuerySpace(), isNull);

      await seed('Late Arrival', [1, 0, 0, 0], 'fake');

      final results = await s.queryRelevant('quantum banana smoothie');
      expect(results.map((r) => r.entity.name), contains('Late Arrival'));
      expect(s.currentQuerySpace!.model, 'fake');
    });
  });
}
