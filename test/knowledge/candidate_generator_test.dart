// ignore_for_file: depend_on_referenced_packages

// U17 golden test for CandidateGenerator.findCandidates.
//
// The expected candidate set below was captured by running the PRE-refactor
// KbMaintenanceService.findCandidates (main @ U16) against this exact seed,
// then re-pointed at the extracted CandidateGenerator seam. It pins both
// candidate paths:
// - token blocking (Alpha pair, synonym block vélo/bicyclette, containment
//   pair Noé ⊂ Noé Girard), and
// - embedding-only discovery (qwxa/brzb: no shared tokens, composite =
//   cosine similarity),
// plus primary selection (access count, created_at tie-break), alias and
// fact-summary attachment, and composite-descending ordering.

import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/dedup/candidate_generator.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';

import '../support/fake_embedding_provider.dart';

Uint8List _blob(List<double> v) =>
    Float32List.fromList(v).buffer.asUint8List();

Future<int> _insertEntity(
  KnowledgeGraphDB db, {
  required String name,
  String type = 'CONCEPT',
  required int accessCount,
  required int createdAt,
  required int lastAccessed,
  List<double>? embedding,
}) async {
  final id = await db.into(db.entities).insert(EntitiesCompanion.insert(
        name: name,
        entityType: Value(type),
      ));
  await db.customStatement(
    'UPDATE entities SET access_count = ?, created_at = ?, last_accessed = ?'
    '${embedding != null ? ', embedding = ?' : ''} WHERE id = ?',
    [
      accessCount,
      createdAt,
      lastAccessed,
      if (embedding != null) _blob(embedding),
      id,
    ],
  );
  return id;
}

void main() {
  late KnowledgeGraphDB db;
  // Seeded ids (deterministic: AUTOINCREMENT from an empty in-memory DB).
  late int noeGirard, noe, alphaProject, alphaProjet, velo, bicyclette;
  late int qwxa, brzb;

  setUp(() async {
    db = KnowledgeGraphDB.forExecutor(NativeDatabase.memory());

    // Containment pair: "Noé" ⊂ "Noé Girard", compatible date facts.
    noeGirard = await _insertEntity(db,
        name: 'Noé Girard',
        type: 'PERSON',
        accessCount: 5,
        createdAt: 1000,
        lastAccessed: 9000);
    noe = await _insertEntity(db,
        name: 'Noé',
        type: 'PERSON',
        accessCount: 2,
        createdAt: 2000,
        lastAccessed: 8000);

    // High name similarity + shared relation neighbor + identical fact.
    alphaProject = await _insertEntity(db,
        name: 'Alpha Project',
        accessCount: 3,
        createdAt: 1500,
        lastAccessed: 7000);
    alphaProjet = await _insertEntity(db,
        name: 'Alpha Projet',
        accessCount: 3,
        createdAt: 1600,
        lastAccessed: 6000);
    final paris = await _insertEntity(db,
        name: 'Paris',
        type: 'PLACE',
        accessCount: 1,
        createdAt: 1700,
        lastAccessed: 5000);

    // Synonym token block (vélo↔bicyclette) with embeddings present.
    velo = await _insertEntity(db,
        name: 'vélo',
        accessCount: 4,
        createdAt: 1800,
        lastAccessed: 4000,
        embedding: [1, 0, 0, 0]);
    bicyclette = await _insertEntity(db,
        name: 'bicyclette',
        accessCount: 1,
        createdAt: 1900,
        lastAccessed: 3000,
        embedding: [0.9, 0.1, 0, 0]);
    // Orthogonal embedding: must pair with nothing.
    await _insertEntity(db,
        name: 'zzz qqq',
        accessCount: 1,
        createdAt: 2000,
        lastAccessed: 2000,
        embedding: [0, 1, 0, 0]);

    // Embedding-discovery pair: no shared tokens, no synonyms, dissimilar
    // names — only the embedding-similarity block can produce this pair.
    qwxa = await _insertEntity(db,
        name: 'qwxa',
        accessCount: 2,
        createdAt: 2100,
        lastAccessed: 1500,
        embedding: [0, 0, 1, 0]);
    brzb = await _insertEntity(db,
        name: 'brzb',
        accessCount: 1,
        createdAt: 2200,
        lastAccessed: 1400,
        embedding: [0, 0.1, 0.995, 0]);

    // Aliases + facts + relations.
    await db.customStatement(
        'INSERT INTO aliases (entity_id, alias_name) VALUES (?, ?)',
        [noeGirard, 'Noé G']);
    await db.into(db.facts).insert(FactsCompanion.insert(
        entityId: noeGirard,
        factKey: 'birthday',
        factValue: '1986-03-14',
        valueType: const Value('date')));
    await db.into(db.facts).insert(FactsCompanion.insert(
        entityId: noe,
        factKey: 'birthday',
        factValue: 'March 14, 1986',
        valueType: const Value('date')));
    await db.into(db.facts).insert(FactsCompanion.insert(
        entityId: alphaProject, factKey: 'serial', factValue: 'alpha-1'));
    await db.into(db.facts).insert(FactsCompanion.insert(
        entityId: alphaProjet, factKey: 'serial', factValue: 'alpha-1'));
    await db.into(db.relations).insert(RelationsCompanion.insert(
        sourceId: alphaProject, targetId: paris, predicate: 'LOCATED_IN'));
    await db.into(db.relations).insert(RelationsCompanion.insert(
        sourceId: alphaProjet, targetId: paris, predicate: 'LOCATED_IN'));
  });

  tearDown(() => db.close());

  CandidateGenerator generator({bool withEmbedder = true}) =>
      CandidateGenerator(
        db: db,
        knowledgeService: KnowledgeService(
          db: db,
          embeddingProvider:
              withEmbedder ? FakeEmbeddingProvider(const {}) : null,
        ),
      );

  test('golden: candidate set matches the pre-refactor baseline', () async {
    final candidates = await generator().findCandidates(fullScan: true);

    expect(candidates, hasLength(4));

    // 1. Embedding-discovery pair: composite = cosine similarity, bypasses
    // the name floor (nameScore 0). Primary = qwxa (access 2 > 1).
    final c0 = candidates[0];
    expect(c0.idA, qwxa);
    expect(c0.idB, brzb);
    expect(c0.nameA, 'qwxa');
    expect(c0.nameB, 'brzb');
    expect(c0.nameScore, 0.0);
    expect(c0.relationScore, 0.0);
    expect(c0.factScore, 0.0);
    expect(c0.compositeScore, closeTo(0.994988, 1e-5));

    // 2. Token-blocked structured pair: shared relation neighbor (Paris) and
    // identical fact → composite = 0.5*name + 0.35*1.0 + 0.15*1.0.
    // Primary = Alpha Project (equal access count, earlier created_at).
    final c1 = candidates[1];
    expect(c1.idA, alphaProject);
    expect(c1.idB, alphaProjet);
    expect(c1.nameScore, closeTo(0.757459, 1e-5));
    expect(c1.relationScore, 1.0);
    expect(c1.factScore, 1.0);
    expect(c1.compositeScore, closeTo(0.878730, 1e-5));
    expect(c1.factSummariesA, ['serial: alpha-1']);
    expect(c1.factSummariesB, ['serial: alpha-1']);

    // 3. Synonym token block (vélo↔bicyclette): no structure → composite =
    // name score. Primary = vélo (access 4 > 1). Reached via the token path
    // (composite == nameScore), not the embedding path (cosine ≈ 0.994).
    final c2 = candidates[2];
    expect(c2.idA, velo);
    expect(c2.idB, bicyclette);
    expect(c2.nameScore, closeTo(0.85, 1e-9));
    expect(c2.compositeScore, closeTo(0.85, 1e-9));

    // 4. Containment pair ("Noé" ⊂ "Noé Girard"): passes the relaxed
    // containment floor; date facts compatible → factScore 1.0.
    // Primary = Noé Girard (access 5 > 2). Alias carried through.
    final c3 = candidates[3];
    expect(c3.idA, noeGirard);
    expect(c3.idB, noe);
    expect(c3.nameScore, closeTo(0.828333, 1e-5));
    expect(c3.relationScore, 0.0);
    expect(c3.factScore, 1.0);
    expect(c3.compositeScore, closeTo(0.564167, 1e-5));
    expect(c3.aliasesA, ['Noé G']);
    expect(c3.aliasesB, isEmpty);
    expect(c3.factSummariesA, ['birthday: 1986-03-14']);
    expect(c3.factSummariesB, ['birthday: March 14, 1986']);
  });

  test('without an embedder the embedding-discovery pair is absent and the '
      'token-blocked pairs are unchanged', () async {
    final candidates =
        await generator(withEmbedder: false).findCandidates(fullScan: true);

    expect(candidates, hasLength(3));
    expect(
      candidates.map((c) => '${c.idA}:${c.idB}'),
      ['$alphaProject:$alphaProjet', '$velo:$bicyclette', '$noeGirard:$noe'],
    );
    expect(candidates[0].compositeScore, closeTo(0.878730, 1e-5));
    expect(candidates[1].compositeScore, closeTo(0.85, 1e-9));
    expect(candidates[2].compositeScore, closeTo(0.564167, 1e-5));
  });

  test('maxPairs caps the result at the top composite scores', () async {
    final candidates =
        await generator().findCandidates(fullScan: true, maxPairs: 2);

    expect(candidates, hasLength(2));
    expect(candidates[0].compositeScore, closeTo(0.994988, 1e-5));
    expect(candidates[1].compositeScore, closeTo(0.878730, 1e-5));
  });
}
