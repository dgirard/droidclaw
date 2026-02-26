import 'dart:math';

import 'package:drift/drift.dart';

import '../database/knowledge_graph_db.dart';

/// Resolves entity names to existing entities via aliases and fuzzy matching.
///
/// Resolution order:
/// 1. Exact alias match (NOCASE via resolveAlias named query)
/// 2. FTS5 search + Jaro-Winkler similarity > threshold
/// 3. Create new entity if no match found
class EntityResolver {
  final KnowledgeGraphDB _db;

  /// Jaro-Winkler threshold for fuzzy matching (0.0–1.0).
  final double similarityThreshold;

  EntityResolver(this._db, {this.similarityThreshold = 0.88});

  /// Resolve an entity name to an existing entity ID, or create a new one.
  ///
  /// [name]: the entity name to resolve.
  /// [entityType]: the type for new entities (default 'CONCEPT').
  /// [summary]: optional summary for new entities.
  ///
  /// Returns the entity ID (existing or newly created).
  Future<int> resolve({
    required String name,
    String entityType = 'CONCEPT',
    String? summary,
  }) async {
    // 1. Exact alias match
    final aliasMatch = await _db.resolveAlias(name).getSingleOrNull();
    if (aliasMatch != null) return aliasMatch.id;

    // 2. FTS5 fuzzy search + Jaro-Winkler
    final ftsQuery = _buildFtsQuery(name);
    if (ftsQuery.isNotEmpty) {
      final candidates = await _db.searchEntities(ftsQuery, 5).get();
      for (final c in candidates) {
        final similarity = jaroWinkler(name.toLowerCase(), c.name.toLowerCase());
        if (similarity >= similarityThreshold) {
          // Create alias for this match so future lookups are instant
          await _db.into(_db.aliases).insert(
                AliasesCompanion.insert(
                  entityId: c.id,
                  aliasName: name,
                ),
                mode: InsertMode.insertOrIgnore,
              );
          return c.id;
        }
      }
    }

    // 3. Create new entity (or return existing if unique constraint fires)
    try {
      final entityId = await _db.into(_db.entities).insert(
            EntitiesCompanion.insert(
              name: name,
              entityType: Value(entityType),
              summary: Value(summary),
            ),
          );

      // Create primary alias
      await _db.into(_db.aliases).insert(
            AliasesCompanion.insert(
              entityId: entityId,
              aliasName: name,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      return entityId;
    } on Exception {
      // Unique constraint on (name, entity_type) — entity was created concurrently
      final existing = await _db.resolveAlias(name).getSingleOrNull();
      if (existing != null) return existing.id;
      rethrow;
    }
  }

  /// Build an FTS5 query from a name.
  /// Escapes special characters and wraps tokens for prefix matching.
  static String _buildFtsQuery(String name) {
    final tokens = name
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '"$t"').join(' OR ');
  }

  /// Jaro-Winkler string similarity (0.0–1.0).
  static double jaroWinkler(String s1, String s2, {double p = 0.1}) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final jaro = _jaroSimilarity(s1, s2);
    // Common prefix length (max 4)
    var prefix = 0;
    for (var i = 0; i < min(4, min(s1.length, s2.length)); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }
    return jaro + prefix * p * (1 - jaro);
  }

  static double _jaroSimilarity(String s1, String s2) {
    final maxDist = (max(s1.length, s2.length) ~/ 2) - 1;
    if (maxDist < 0) return 0.0;

    final s1Matches = List<bool>.filled(s1.length, false);
    final s2Matches = List<bool>.filled(s2.length, false);

    var matches = 0;
    var transpositions = 0;

    for (var i = 0; i < s1.length; i++) {
      final start = max(0, i - maxDist);
      final end = min(i + maxDist + 1, s2.length);
      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    var k = 0;
    for (var i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    return (matches / s1.length +
            matches / s2.length +
            (matches - transpositions / 2) / matches) /
        3;
  }
}
