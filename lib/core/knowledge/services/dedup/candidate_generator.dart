import 'dart:math';
import 'dart:typed_data';

import '../../../../shared/constants.dart';
import '../../algorithms/date_similarity.dart';
import '../../algorithms/embedding_codec.dart';
import '../../algorithms/memory_clusterer.dart';
import '../../algorithms/string_similarity.dart';
import '../../database/knowledge_graph_db.dart';
import '../../models/dedup_models.dart';
import '../../models/entity.dart';
import '../knowledge_service.dart';
import 'truncate.dart';

/// Deterministic duplicate-candidate generation for the KB dedup pipeline.
///
/// Extracted from [KbMaintenanceService] (U17). Uses token blocking for
/// O(N*k) entity-pair generation, [StringSimilarity] scoring, an optional
/// embedding pre-filter/discovery pass, and same-entity fact-pair scanning.
/// No LLM calls happen here — see `DedupLlmVerifier` for verification.
class CandidateGenerator {
  final KnowledgeGraphDB _db;
  final KnowledgeService _knowledgeService;

  CandidateGenerator({
    required KnowledgeGraphDB db,
    required KnowledgeService knowledgeService,
  })  : _db = db,
        _knowledgeService = knowledgeService;

  /// Find duplicate candidates using token blocking + deterministic scoring.
  ///
  /// If [fullScan] is false and [lastDreamAt] is provided, only compares
  /// entities created after [lastDreamAt] against all active entities.
  /// Returns scored pairs sorted by composite score descending, capped at [maxPairs].
  Future<List<DuplicateCandidate>> findCandidates({
    int maxPairs = AppConstants.dedupMaxPairsDefault,
    bool fullScan = false,
    int? lastDreamAt,
  }) async {
    // 1. Load all active entities
    final allRows = await _db.listEntitiesFiltered(
      limit: AppConstants.dedupEntityScanLimit,
      offset: 0,
    );
    final allEntities = allRows.map((r) {
      return KnowledgeEntity.fromJson(r);
    }).toList();

    if (allEntities.length < 2) return [];

    // 2. Load all aliases in a single batch query
    final aliasMap = await _db.getAllActiveAliases();

    // 3. Determine which entities are "new" (for incremental mode)
    Set<int> newEntityIds;
    if (!fullScan && lastDreamAt != null) {
      newEntityIds = allEntities
          .where((e) => e.id != null && (e.createdAt ?? 0) > lastDreamAt)
          .map((e) => e.id!)
          .toSet();
      // Fall back to full scan if no new entities since last dream
      if (newEntityIds.isEmpty) {
        newEntityIds = allEntities
            .where((e) => e.id != null)
            .map((e) => e.id!)
            .toSet();
      }
    } else {
      // Full scan: all entities are candidates
      newEntityIds = allEntities
          .where((e) => e.id != null)
          .map((e) => e.id!)
          .toSet();
    }

    // 4. Build token → entity_id index for blocking
    // Also index synonym tokens so that "papa" and "père" share a block.
    final tokenIndex = <String, Set<int>>{};
    for (final e in allEntities) {
      if (e.id == null) continue;
      final names = [e.name, ...aliasMap[e.id!] ?? []];
      for (final name in names) {
        final tokens = _tokenize(name);
        for (final token in tokens) {
          (tokenIndex[token] ??= <int>{}).add(e.id!);
          // Add all synonym variants so entities with synonymous names
          // end up in the same blocking bucket (papa↔père, vélo↔bicyclette)
          final synonyms = StringSimilarity.synonymsOf(token);
          for (final syn in synonyms) {
            (tokenIndex[syn] ??= <int>{}).add(e.id!);
          }
        }
      }
    }

    // 5. Build entity lookup
    final entityById = <int, KnowledgeEntity>{};
    for (final e in allEntities) {
      if (e.id != null) entityById[e.id!] = e;
    }

    final allIds = [
      for (final e in allEntities)
        if (e.id != null) e.id!,
    ];

    // 6. Load relation neighbors for all entities — a handful of chunked
    // IN (...) queries instead of one getEntityRelationsWithNames per
    // entity (U14: the dream-run N+1, up to 5000 queries).
    final relNeighbors = await _db.getRelationNeighborIdsBatch(allIds);

    // 7. Load facts for all entities (key, value, type for date-aware
    // scoring) — chunked IN (...) queries instead of one SELECT per entity.
    final factRows = await _db.getActiveFactRowsBatch(
      allIds,
      perEntityLimit: AppConstants.dedupFactsPerEntityLimit,
    );
    final factData = <int, List<FactRow>>{};
    final factKeys = <int, Set<String>>{};
    final factSummaries = <int, List<String>>{};
    for (final id in allIds) {
      final entries = factRows[id] ?? const <FactRow>[];
      factData[id] = entries;
      factKeys[id] = entries.map((f) => f.key).toSet();
      factSummaries[id] = entries
          .map((f) => '${f.key}: ${truncate(f.value, 50)}')
          .toList();
    }

    // 9. Embedding pre-filter (if available) — paged scan, bounded at
    // [AppConstants.dedupEntityScanLimit] embeddings (the same explicit
    // bound the old single LIMIT query used). The scan is restricted to the
    // selected query space (U3): cosine similarity between vectors from two
    // embedding spaces is meaningless, in dedup as in retrieval.
    Map<int, Float32List>? embeddings;
    final querySpace = await _knowledgeService.resolveQuerySpace();
    if (querySpace != null) {
      embeddings = <int, Float32List>{};
      var afterId = 0;
      while (embeddings.length < AppConstants.dedupEntityScanLimit) {
        final pageSize = min(
          AppConstants.knowledgeEmbeddingScanPageSize,
          AppConstants.dedupEntityScanLimit - embeddings.length,
        );
        final page = await _db.getActiveEntityEmbeddingsPage(
          afterId: afterId,
          pageSize: pageSize,
          model: querySpace.model,
          dim: querySpace.dim,
        );
        for (final row in page) {
          embeddings[row.id] = EmbeddingCodec.decode(row.embedding);
        }
        if (page.length < pageSize) break;
        afterId = page.last.id;
      }
    }

    // Shared scoring for both candidate paths: best name similarity across
    // names + aliases, containment, relation-neighbor Jaccard, date-aware
    // fact score, and whether the pair has any relations/facts at all.
    ({
      double nameScore,
      bool containment,
      double relScore,
      double factScore,
      bool hasStructure,
    }) scorePair(int idA, int idB, KnowledgeEntity a, KnowledgeEntity b) {
      final namesA = <String>[a.name, ...aliasMap[idA] ?? []];
      final namesB = <String>[b.name, ...aliasMap[idB] ?? []];
      final nameScore = StringSimilarity.bestCombined(namesA, namesB);
      final containment = _anyNameContained(namesA, namesB);
      final relsA = relNeighbors[idA] ?? <int>{};
      final relsB = relNeighbors[idB] ?? <int>{};
      final relScore = _jaccard(relsA, relsB);
      final fScore = _factScore(factData[idA] ?? [], factData[idB] ?? []);
      final fKeysA = factKeys[idA] ?? <String>{};
      final fKeysB = factKeys[idB] ?? <String>{};
      final hasStructure = relsA.isNotEmpty ||
          relsB.isNotEmpty ||
          fKeysA.isNotEmpty ||
          fKeysB.isNotEmpty;
      return (
        nameScore: nameScore,
        containment: containment,
        relScore: relScore,
        factScore: fScore,
        hasStructure: hasStructure,
      );
    }

    // Shared candidate construction (U17: this block used to be copy-pasted
    // in the token-blocking and embedding-discovery paths). Chooses the
    // primary (higher access count wins, tie-break by earlier creation) and
    // attaches aliases + fact summaries.
    DuplicateCandidate buildCandidate({
      required int newId,
      required int otherId,
      required KnowledgeEntity newEntity,
      required KnowledgeEntity other,
      required double nameScore,
      required double relScore,
      required double factScore,
      required double composite,
    }) {
      int primaryId, secondaryId;
      String primaryName, secondaryName;
      if (newEntity.accessCount > other.accessCount ||
          (newEntity.accessCount == other.accessCount &&
              (newEntity.createdAt ?? 0) < (other.createdAt ?? 0))) {
        primaryId = newId;
        secondaryId = otherId;
        primaryName = newEntity.name;
        secondaryName = other.name;
      } else {
        primaryId = otherId;
        secondaryId = newId;
        primaryName = other.name;
        secondaryName = newEntity.name;
      }

      return DuplicateCandidate(
        idA: primaryId,
        idB: secondaryId,
        nameA: primaryName,
        nameB: secondaryName,
        nameScore: nameScore,
        relationScore: relScore,
        factScore: factScore,
        compositeScore: composite,
        aliasesA: aliasMap[primaryId] ?? [],
        aliasesB: aliasMap[secondaryId] ?? [],
        factSummariesA: factSummaries[primaryId] ?? [],
        factSummariesB: factSummaries[secondaryId] ?? [],
      );
    }

    // 10. Generate candidate pairs via token blocking
    final seenPairs = <String>{};
    final candidates = <DuplicateCandidate>[];

    for (final newId in newEntityIds) {
      final newEntity = entityById[newId];
      if (newEntity == null) continue;

      // Find entities sharing tokens
      final newNames = [newEntity.name, ...aliasMap[newId] ?? []];
      final candidateIds = <int>{};
      for (final name in newNames) {
        final tokens = _tokenize(name);
        for (final token in tokens) {
          final matches = tokenIndex[token];
          if (matches != null) candidateIds.addAll(matches);
        }
      }
      candidateIds.remove(newId);

      for (final otherId in candidateIds) {
        // Deduplicate pairs
        final pairKey = newId < otherId ? '$newId:$otherId' : '$otherId:$newId';
        if (seenPairs.contains(pairKey)) continue;
        seenPairs.add(pairKey);

        final other = entityById[otherId];
        if (other == null) continue;

        // Embedding pre-filter
        if (embeddings != null) {
          final embA = embeddings[newId];
          final embB = embeddings[otherId];
          if (embA != null && embB != null && embA.length == embB.length) {
            final sim = MemoryClusterer.cosineSimilarity(embA, embB);
            if (sim < AppConstants.dedupEmbeddingPrefilterMinSim) continue;
          }
        }

        final s = scorePair(newId, otherId, newEntity, other);

        // Name floor: skip if best name similarity < dedupNameFloor.
        // Exception: if one name is literally contained in the other
        // (e.g. "Noé" ⊂ "Noé Girard", "dream" ⊂ "full dream"),
        // containment alone is strong evidence — use a minimal floor.
        final nameFloor = s.containment
            ? AppConstants.dedupContainmentNameFloor
            : AppConstants.dedupNameFloor;
        if (s.nameScore < nameFloor) continue;

        // Composite score: 50% name + 35% relations + 15% facts.
        // When both entities have relations/facts, use weighted composite.
        // When neither has relations/facts, rely on name score alone.
        final composite = s.hasStructure
            ? AppConstants.dedupNameWeight * s.nameScore +
                AppConstants.dedupRelationWeight * s.relScore +
                AppConstants.dedupFactWeight * s.factScore
            : s.nameScore;

        // Filter: composite floor (with structure) or name floor (name-only)
        final threshold = s.hasStructure
            ? AppConstants.dedupCompositeThresholdStructured
            : AppConstants.dedupCompositeThresholdNameOnly;
        if (composite < threshold) continue;

        candidates.add(buildCandidate(
          newId: newId,
          otherId: otherId,
          newEntity: newEntity,
          other: other,
          nameScore: s.nameScore,
          relScore: s.relScore,
          factScore: s.factScore,
          composite: composite,
        ));
      }
    }

    // 11. Embedding-based candidate discovery (catches semantic synonyms
    // like vélo/bicyclette that share no tokens and fail string similarity).
    // These pairs bypass the name floor — the LLM will judge semantically.
    if (embeddings != null && embeddings.length >= 2) {
      final embeddedNewIds = newEntityIds
          .where((id) => embeddings!.containsKey(id))
          .toList();
      final allEmbeddedIds = embeddings.keys.toList();

      for (final newId in embeddedNewIds) {
        final embA = embeddings[newId]!;
        for (final otherId in allEmbeddedIds) {
          if (otherId == newId) continue;
          final pairKey = newId < otherId
              ? '$newId:$otherId'
              : '$otherId:$newId';
          if (seenPairs.contains(pairKey)) continue;

          final embB = embeddings[otherId]!;
          if (embA.length != embB.length) continue;
          final sim = MemoryClusterer.cosineSimilarity(embA, embB);
          if (sim < AppConstants.dedupEmbeddingCandidateMinSim) continue;

          seenPairs.add(pairKey);
          final newEntity = entityById[newId];
          final other = entityById[otherId];
          if (newEntity == null || other == null) continue;

          // Compute scores for context (may be low for semantic synonyms);
          // use embedding similarity as composite (LLM will re-score).
          final s = scorePair(newId, otherId, newEntity, other);

          candidates.add(buildCandidate(
            newId: newId,
            otherId: otherId,
            newEntity: newEntity,
            other: other,
            nameScore: s.nameScore,
            relScore: s.relScore,
            factScore: s.factScore,
            composite: sim,
          ));
        }
      }
    }

    // Sort by composite score descending, cap at maxPairs
    candidates.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return candidates.take(maxPairs).toList();
  }

  /// Find duplicate facts within the same entity.
  ///
  /// Detects semantically equivalent fact values on the same entity
  /// (e.g., "vélo" and "bicyclette" as possessions of the same person).
  /// Uses LLM to identify semantic duplicates that string similarity misses.
  Future<({List<DuplicateFactCandidate> candidates, List<EntityFactBundle> bundles})> findDuplicateFacts({
    int maxEntities = AppConstants.dedupFactScanMaxEntities,
  }) async {
    final allRows = await _db.listEntitiesFiltered(limit: maxEntities, offset: 0);
    final candidates = <DuplicateFactCandidate>[];
    final bundles = <EntityFactBundle>[];

    // Batch-load all facts in chunked IN (...) queries instead of one
    // SELECT per entity (the findDuplicateFacts N+1, sibling of U14).
    final factRows = await _db.getActiveFactRowsBatch(
      [for (final row in allRows) row['id'] as int],
    );

    for (final row in allRows) {
      final entityId = row['id'] as int;
      final entityName = row['name'] as String;

      final facts = factRows[entityId] ?? const <FactRow>[];
      if (facts.length < 2) continue;

      // Group facts by key — duplicates are facts with the same key
      // but different values that mean the same thing
      final byKey = <String, List<FactRow>>{};
      for (final f in facts) {
        (byKey[f.key] ??= []).add(f);
      }

      // For keys with multiple values, check for duplicates
      for (final entry in byKey.entries) {
        if (entry.value.length < 2) continue;
        final values = entry.value;
        for (var i = 0; i < values.length; i++) {
          for (var j = i + 1; j < values.length; j++) {
            final a = values[i];
            final b = values[j];

            // Date-aware comparison
            if (a.type == 'date' || b.type == 'date') {
              final dateScore = DateSimilarity.score(a.value, b.value);
              if (dateScore >= AppConstants.dedupFactDateScoreMin) {
                candidates.add(DuplicateFactCandidate(
                  entityId: entityId,
                  entityName: entityName,
                  factIdA: a.id,
                  factIdB: b.id,
                  factKey: entry.key,
                  valueA: a.value,
                  valueB: b.value,
                  similarity: dateScore,
                  source: 'date',
                ));
              }
              continue;
            }

            // String similarity
            final strScore = StringSimilarity.combined(a.value, b.value);
            if (strScore >= AppConstants.dedupFactStringScoreMin) {
              candidates.add(DuplicateFactCandidate(
                entityId: entityId,
                entityName: entityName,
                factIdA: a.id,
                factIdB: b.id,
                factKey: entry.key,
                valueA: a.value,
                valueB: b.value,
                similarity: strScore,
                source: 'string',
              ));
            }
          }
        }
      }

      // Collect entities with 2+ facts for LLM semantic dedup
      // (catches cross-key synonyms like vélo/bicyclette)
      bundles.add(EntityFactBundle(
        entityId: entityId,
        entityName: entityName,
        facts: [
          for (final f in facts) {'id': f.id, 'key': f.key, 'value': f.value},
        ],
      ));
    }

    candidates.sort((a, b) => b.similarity.compareTo(a.similarity));
    return (candidates: candidates, bundles: bundles);
  }

  // -- Private helpers --

  static final _nonWordRe = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _whitespaceRe = RegExp(r'\s+');
  static final _camelCaseRe = RegExp(r'([a-z])([A-Z])');

  /// Tokenize a name into lowercase, accent-stripped words for blocking index.
  ///
  /// Also splits camelCase tokens (e.g. "ProofEditor" → {"proof", "editor"})
  /// so that "ProofEditor" and "Proof Editor.ai" share tokens.
  static Set<String> _tokenize(String s) {
    final words = s
        .replaceAll(_nonWordRe, ' ')
        .split(_whitespaceRe)
        .where((t) => t.isNotEmpty);
    final tokens = <String>{};
    for (final word in words) {
      final normalized = StringSimilarity.normalize(word);
      if (normalized.length > 1) tokens.add(normalized);
      // Split camelCase: "ProofEditor" → ["proof", "editor"]
      final camelParts = word
          .replaceAllMapped(
            _camelCaseRe,
            (m) => '${m.group(1)} ${m.group(2)}',
          )
          .split(' ')
          .map((t) => StringSimilarity.normalize(t))
          .where((t) => t.length > 1);
      tokens.addAll(camelParts);
    }
    return tokens;
  }

  /// Check if any name in A is contained in any name in B (or vice versa).
  ///
  /// Catches cases like "Noé" ⊂ "Noé Girard" or "dream" ⊂ "full dream"
  /// where one entity has a short name that appears inside the other's name.
  /// Only matches when the shorter name is at least
  /// [AppConstants.dedupContainmentMinNameLength] chars (avoids noise).
  static bool _anyNameContained(List<String> namesA, List<String> namesB) {
    for (final a in namesA) {
      final na = StringSimilarity.normalize(a);
      if (na.length < AppConstants.dedupContainmentMinNameLength) continue;
      for (final b in namesB) {
        final nb = StringSimilarity.normalize(b);
        if (nb.length < AppConstants.dedupContainmentMinNameLength) continue;
        if (na != nb && (nb.contains(na) || na.contains(nb))) return true;
      }
    }
    return false;
  }

  /// Jaccard similarity for two sets.
  static double _jaccard<T>(Set<T> a, Set<T> b) {
    if (a.isEmpty && b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union > 0 ? intersection / union : 0.0;
  }

  /// Date-aware fact scoring between two entities.
  ///
  /// For facts with matching keys:
  /// - Date facts use [DateSimilarity.score] (1.0 identical, 0.7 compatible, -0.3 conflict)
  /// - Non-date facts use exact value match (1.0 match, 0.0 mismatch)
  /// Also includes key Jaccard as a baseline.
  ///
  /// Final score = 0.6 * dateAwareMatch + 0.4 * keyJaccard, clamped to [0, 1].
  static double _factScore(List<FactRow> factsA, List<FactRow> factsB) {
    if (factsA.isEmpty && factsB.isEmpty) return 0.0;
    if (factsA.isEmpty || factsB.isEmpty) return 0.0;

    // Key Jaccard baseline
    final keysA = factsA.map((f) => f.key).toSet();
    final keysB = factsB.map((f) => f.key).toSet();
    final keyJaccard = _jaccard(keysA, keysB);

    // Build key→value maps for matching
    final mapA = <String, FactRow>{};
    for (final f in factsA) {
      mapA[f.key] = f;
    }
    final mapB = <String, FactRow>{};
    for (final f in factsB) {
      mapB[f.key] = f;
    }

    // Score matching keys with date awareness
    final sharedKeys = keysA.intersection(keysB);
    if (sharedKeys.isEmpty) {
      return AppConstants.dedupFactKeyJaccardWeight * keyJaccard;
    }

    var totalScore = 0.0;
    for (final key in sharedKeys) {
      final a = mapA[key]!;
      final b = mapB[key]!;
      if (a.type == 'date' || b.type == 'date') {
        totalScore += DateSimilarity.score(a.value, b.value);
      } else {
        totalScore += a.value.toLowerCase() == b.value.toLowerCase() ? 1.0 : 0.0;
      }
    }
    final matchScore = totalScore / sharedKeys.length;

    // Combine: 60% date-aware match + 40% key overlap
    return (AppConstants.dedupFactMatchWeight * matchScore +
            AppConstants.dedupFactKeyJaccardWeight * keyJaccard)
        .clamp(0.0, 1.0);
  }
}
