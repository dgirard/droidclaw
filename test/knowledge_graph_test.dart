// ignore_for_file: depend_on_referenced_packages

import 'package:drift/drift.dart';
import 'package:test/test.dart';

import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';

import 'support/in_memory_kg.dart';

void main() {
  late KnowledgeGraphDB db;

  setUp(() => db = inMemoryKnowledgeGraphDB());
  tearDown(() => db.close());

  Future<int> insertEntity(String name,
          {String type = 'PERSON', String? summary}) =>
      db.into(db.entities).insert(EntitiesCompanion.insert(
            name: name,
            entityType: Value(type),
            summary: Value(summary),
          ));

  Future<void> insertFact(int entityId, String key, String value) =>
      db.into(db.facts).insert(FactsCompanion.insert(
            entityId: entityId,
            factKey: key,
            factValue: value,
          ));

  test('FTS5 entity search finds an inserted entity by name', () async {
    await insertEntity('Alice Dupont');
    final results = await db.searchEntities('Alice', 5).get();
    expect(results.map((e) => e.name), contains('Alice Dupont'));
  });

  test('searchFacts surfaces a stored fact value (facts search is wired)',
      () async {
    // Regression guard: facts search was once dead code, so a stored fact
    // (e.g. an address) was invisible to retrieval.
    final id = await insertEntity('Home', type: 'PLACE');
    await insertFact(id, 'address', '9 rue la Paix');

    final facts = await db.searchFacts('Paix', 5).get();
    expect(facts.any((f) => f.factValue.contains('Paix')), isTrue);
  });

  test('getEntityFacts returns the active facts for an entity', () async {
    final id = await insertEntity('Bob');
    await insertFact(id, 'role', 'engineer');

    final facts = await db.getEntityFacts(id).get();
    expect(facts.single.factKey, 'role');
    expect(facts.single.factValue, 'engineer');
  });

  test('mergeEntities moves facts to the primary and deactivates the secondary',
      () async {
    final primary = await insertEntity('Catherine');
    final secondary = await insertEntity('Cathy');
    await insertFact(secondary, 'nickname', 'Cat');
    await db.into(db.aliases).insert(
        AliasesCompanion.insert(entityId: secondary, aliasName: 'Cathy'));

    await db.mergeEntities(primary, secondary);

    // The secondary's fact now belongs to the primary.
    final primaryFacts = await db.getEntityFacts(primary).get();
    expect(primaryFacts.any((f) => f.factKey == 'nickname'), isTrue);

    // The secondary is no longer returned by active search.
    final stillActive = await db.searchEntities('Cathy', 5).get();
    expect(stillActive, isEmpty);
  });
}
