import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../config/log_entry.dart';
import '../../providers/llm_provider.dart';
import '../../providers/llm_response.dart';
import '../../services/app_logger.dart';
import '../../../shared/constants.dart';
import '../algorithms/date_similarity.dart';
import '../algorithms/memory_clusterer.dart';
import '../algorithms/string_similarity.dart';
import '../database/knowledge_graph_db.dart';
import '../models/entity.dart';
import 'knowledge_service.dart';

/// A candidate pair of potentially duplicate entities.
class DuplicateCandidate {
  final int idA;
  final int idB;
  final String nameA;
  final String nameB;
  final double nameScore;
  final double relationScore;
  final double factScore;
  final double compositeScore;
  final List<String> aliasesA;
  final List<String> aliasesB;
  final List<String> factSummariesA;
  final List<String> factSummariesB;

  const DuplicateCandidate({
    required this.idA,
    required this.idB,
    required this.nameA,
    required this.nameB,
    required this.nameScore,
    required this.relationScore,
    required this.factScore,
    required this.compositeScore,
    this.aliasesA = const [],
    this.aliasesB = const [],
    this.factSummariesA = const [],
    this.factSummariesB = const [],
  });
}

/// A scored and verified duplicate pair (after optional LLM verification).
class ScoredPair {
  final int primaryId;
  final int secondaryId;
  final String primaryName;
  final String secondaryName;
  final double score;
  final String justification;
  final int level; // 1, 2, or 3

  const ScoredPair({
    required this.primaryId,
    required this.secondaryId,
    required this.primaryName,
    required this.secondaryName,
    required this.score,
    required this.justification,
    required this.level,
  });
}

/// A candidate pair of duplicate facts within the same entity.
class DuplicateFactCandidate {
  final int entityId;
  final String entityName;
  final int factIdA;
  final int factIdB;
  final String factKey;
  final String valueA;
  final String valueB;
  final double similarity;
  final String source; // 'string', 'date', 'cross-key'

  const DuplicateFactCandidate({
    required this.entityId,
    required this.entityName,
    required this.factIdA,
    required this.factIdB,
    required this.factKey,
    required this.valueA,
    required this.valueB,
    required this.similarity,
    required this.source,
  });
}

/// A scored duplicate fact pair with LLM verdict.
class ScoredFactPair {
  final int entityId;
  final String entityName;
  final int factIdKeep;
  final int factIdRemove;
  final String factKey;
  final String valueKeep;
  final String valueRemove;
  final double score;
  final String justification;

  const ScoredFactPair({
    required this.entityId,
    required this.entityName,
    required this.factIdKeep,
    required this.factIdRemove,
    required this.factKey,
    required this.valueKeep,
    required this.valueRemove,
    required this.score,
    required this.justification,
  });
}

/// Service for KB maintenance: duplicate detection and entity merging.
///
/// Follows the [EntityExtractor] pattern: encapsulates LLM calls in a
/// service class, keeping tools thin. Uses token blocking for O(N*k)
/// candidate generation, deterministic scoring with [StringSimilarity],
/// and optional LLM semantic verification.
class KbMaintenanceService {
  final KnowledgeGraphDB _db;
  final KnowledgeService _knowledgeService;
  final LLMProvider _llmProvider;
  final String _model;

  /// The language for LLM prompts (e.g. 'en', 'fr'). Null = English.
  final String? kbLanguage;

  KbMaintenanceService({
    required KnowledgeGraphDB db,
    required KnowledgeService knowledgeService,
    required LLMProvider llmProvider,
    required String model,
    this.kbLanguage,
  })  : _db = db,
        _knowledgeService = knowledgeService,
        _llmProvider = llmProvider,
        _model = model;

  /// Find duplicate candidates using token blocking + deterministic scoring.
  ///
  /// If [fullScan] is false and [lastDreamAt] is provided, only compares
  /// entities created after [lastDreamAt] against all active entities.
  /// Returns scored pairs sorted by composite score descending, capped at [maxPairs].
  Future<List<DuplicateCandidate>> findCandidates({
    int maxPairs = 40,
    bool fullScan = false,
    int? lastDreamAt,
  }) async {
    // 1. Load all active entities
    final allRows = await _db.listEntitiesFiltered(
      limit: 5000,
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
    final factRows =
        await _db.getActiveFactRowsBatch(allIds, perEntityLimit: 10);
    final factData = <int, List<_FactEntry>>{};
    final factKeys = <int, Set<String>>{};
    final factSummaries = <int, List<String>>{};
    for (final id in allIds) {
      final entries = [
        for (final f in factRows[id] ?? const [])
          _FactEntry(key: f.key, value: f.value, type: f.type),
      ];
      factData[id] = entries;
      factKeys[id] = entries.map((f) => f.key).toSet();
      factSummaries[id] = entries
          .map((f) => '${f.key}: ${_truncate(f.value, 50)}')
          .toList();
    }

    // 9. Embedding pre-filter (if available)
    Map<int, Float32List>? embeddings;
    if (_knowledgeService.hasEmbedder) {
      final embRows = await _db.getActiveEntityEmbeddings(limit: 5000);
      embeddings = <int, Float32List>{};
      for (final row in embRows) {
        embeddings[row.id] = Float32List.view(
          Uint8List.fromList(row.embedding).buffer,
        );
      }
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
            if (sim < 0.5) continue;
          }
        }

        // Compute name similarity (best across all name/alias combos)
        final namesA = <String>[newEntity.name, ...aliasMap[newId] ?? []];
        final namesB = <String>[other.name, ...aliasMap[otherId] ?? []];
        final nameScore = StringSimilarity.bestCombined(namesA, namesB);

        // Name floor: skip if best name similarity < 0.60
        // Exception: if one name is literally contained in the other
        // (e.g. "Noé" ⊂ "Noé Girard", "dream" ⊂ "full dream"),
        // containment alone is strong evidence — use a minimal floor.
        final containment = _anyNameContained(namesA, namesB);
        final nameFloor = containment ? 0.20 : 0.60;
        if (nameScore < nameFloor) continue;

        // Relation overlap (Jaccard of neighbor sets)
        final relsA = relNeighbors[newId] ?? <int>{};
        final relsB = relNeighbors[otherId] ?? <int>{};
        final relScore = _jaccard(relsA, relsB);

        // Fact scoring: date-aware + key Jaccard
        final factsA = factData[newId] ?? [];
        final factsB = factData[otherId] ?? [];
        final fScore = _factScore(factsA, factsB);

        // Composite score: 50% name + 35% relations + 15% facts
        // When both entities have relations/facts, use weighted composite.
        // When neither has relations/facts, rely on name score alone.
        final fKeysA = factKeys[newId] ?? <String>{};
        final fKeysB = factKeys[otherId] ?? <String>{};
        final hasStructure = relsA.isNotEmpty || relsB.isNotEmpty ||
            fKeysA.isNotEmpty || fKeysB.isNotEmpty;
        final composite = hasStructure
            ? 0.50 * nameScore + 0.35 * relScore + 0.15 * fScore
            : nameScore;

        // Filter: composite >= 0.55 (with structure) or name >= 0.75 (name-only)
        final threshold = hasStructure ? 0.50 : 0.60;
        if (composite < threshold) continue;

        // Choose primary (higher access count wins, tie-break by earlier creation)
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

        candidates.add(DuplicateCandidate(
          idA: primaryId,
          idB: secondaryId,
          nameA: primaryName,
          nameB: secondaryName,
          nameScore: nameScore,
          relationScore: relScore,
          factScore: fScore,
          compositeScore: composite,
          aliasesA: aliasMap[primaryId] ?? [],
          aliasesB: aliasMap[secondaryId] ?? [],
          factSummariesA: factSummaries[primaryId] ?? [],
          factSummariesB: factSummaries[secondaryId] ?? [],
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
          if (sim < 0.75) continue;

          seenPairs.add(pairKey);
          final newEntity = entityById[newId];
          final other = entityById[otherId];
          if (newEntity == null || other == null) continue;

          // Compute scores for context (may be low for semantic synonyms)
          final namesA = <String>[newEntity.name, ...aliasMap[newId] ?? []];
          final namesB = <String>[other.name, ...aliasMap[otherId] ?? []];
          final nameScore = StringSimilarity.bestCombined(namesA, namesB);
          final relsA = relNeighbors[newId] ?? <int>{};
          final relsB = relNeighbors[otherId] ?? <int>{};
          final relScore = _jaccard(relsA, relsB);
          final factsA = factData[newId] ?? [];
          final factsB = factData[otherId] ?? [];
          final fScore = _factScore(factsA, factsB);

          // Use embedding similarity as composite (LLM will re-score)
          final composite = sim;

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

          candidates.add(DuplicateCandidate(
            idA: primaryId,
            idB: secondaryId,
            nameA: primaryName,
            nameB: secondaryName,
            nameScore: nameScore,
            relationScore: relScore,
            factScore: fScore,
            compositeScore: composite,
            aliasesA: aliasMap[primaryId] ?? [],
            aliasesB: aliasMap[secondaryId] ?? [],
            factSummariesA: factSummaries[primaryId] ?? [],
            factSummariesB: factSummaries[secondaryId] ?? [],
          ));
        }
      }
    }

    // Sort by composite score descending, cap at maxPairs
    candidates.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return candidates.take(maxPairs).toList();
  }

  /// Verify candidates via LLM semantic analysis.
  ///
  /// Sends only names, aliases, and fact key summaries (no raw PII values
  /// like phone numbers or addresses). Returns pairs with LLM-adjusted
  /// scores, justifications, and level classification.
  ///
  /// Falls back to deterministic-only scores on LLM failure.
  Future<List<ScoredPair>> verifyWithLLM(
    List<DuplicateCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return [];

    // Split into batches of <=20 pairs, max 2 LLM calls
    final batches = <List<DuplicateCandidate>>[];
    for (var i = 0; i < candidates.length && batches.length < 2; i += 20) {
      batches.add(candidates.sublist(
        i,
        min(i + 20, candidates.length),
      ));
    }

    final allPairs = <ScoredPair>[];

    for (final batch in batches) {
      final llmPairs = await _verifyBatch(batch);
      allPairs.addAll(llmPairs);
    }

    // Add remaining candidates (beyond 2 batches) as deterministic-only
    final processedCount = min(batches.length * 20, candidates.length);
    for (var i = processedCount; i < candidates.length; i++) {
      allPairs.add(_toDeterministicPair(candidates[i]));
    }

    // Sort by score descending
    allPairs.sort((a, b) => b.score.compareTo(a.score));
    return allPairs;
  }

  /// Execute merge of [secondaryId] into [primaryId].
  ///
  /// Delegates to [KnowledgeGraphDB.mergeEntities] which handles the
  /// full 12-step merge within a single SQLite transaction.
  Future<MergeResult> merge(int primaryId, int secondaryId) async {
    return await _db.mergeEntities(primaryId, secondaryId);
  }

  /// Find duplicate facts within the same entity.
  ///
  /// Detects semantically equivalent fact values on the same entity
  /// (e.g., "vélo" and "bicyclette" as possessions of the same person).
  /// Uses LLM to identify semantic duplicates that string similarity misses.
  Future<({List<DuplicateFactCandidate> candidates, List<EntityFactBundle> bundles})> findDuplicateFacts({
    int maxEntities = 100,
  }) async {
    final allRows = await _db.listEntitiesFiltered(limit: maxEntities, offset: 0);
    final candidates = <DuplicateFactCandidate>[];
    final bundles = <EntityFactBundle>[];

    for (final row in allRows) {
      final entityId = row['id'] as int;
      final entityName = row['name'] as String;

      final facts = await _db.customSelect(
        'SELECT id, fact_key, fact_value, value_type FROM facts '
        'WHERE entity_id = ? AND expired_at IS NULL',
        variables: [Variable.withInt(entityId)],
      ).get();

      if (facts.length < 2) continue;

      // Group facts by key — duplicates are facts with the same key
      // but different values that mean the same thing
      final byKey = <String, List<Map<String, dynamic>>>{};
      for (final f in facts) {
        final key = f.read<String>('fact_key');
        (byKey[key] ??= []).add({
          'id': f.read<int>('id'),
          'key': key,
          'value': f.read<String>('fact_value'),
          'type': f.read<String>('value_type'),
        });
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
            if (a['type'] == 'date' || b['type'] == 'date') {
              final dateScore = DateSimilarity.score(
                a['value'] as String, b['value'] as String);
              if (dateScore >= 0.7) {
                candidates.add(DuplicateFactCandidate(
                  entityId: entityId,
                  entityName: entityName,
                  factIdA: a['id'] as int,
                  factIdB: b['id'] as int,
                  factKey: entry.key,
                  valueA: a['value'] as String,
                  valueB: b['value'] as String,
                  similarity: dateScore,
                  source: 'date',
                ));
              }
              continue;
            }

            // String similarity
            final strScore = StringSimilarity.combined(
              a['value'] as String, b['value'] as String);
            if (strScore >= 0.60) {
              candidates.add(DuplicateFactCandidate(
                entityId: entityId,
                entityName: entityName,
                factIdA: a['id'] as int,
                factIdB: b['id'] as int,
                factKey: entry.key,
                valueA: a['value'] as String,
                valueB: b['value'] as String,
                similarity: strScore,
                source: 'string',
              ));
            }
          }
        }
      }

      // Collect entities with 2+ facts for LLM semantic dedup
      // (catches cross-key synonyms like vélo/bicyclette)
      if (facts.length >= 2) {
        bundles.add(EntityFactBundle(
          entityId: entityId,
          entityName: entityName,
          facts: facts.map((f) => {
                'id': f.read<int>('id'),
                'key': f.read<String>('fact_key'),
                'value': f.read<String>('fact_value'),
              }).toList(),
        ));
      }
    }

    candidates.sort((a, b) => b.similarity.compareTo(a.similarity));
    return (candidates: candidates, bundles: bundles);
  }

  /// Verify duplicate fact candidates via LLM.
  ///
  /// Two-phase approach:
  /// 1. Send entity fact bundles to LLM for cross-key semantic detection
  ///    (catches vélo/bicyclette that string similarity cannot detect).
  /// 2. Verify deterministic candidates (same-key duplicates).
  Future<List<ScoredFactPair>> verifyFactsWithLLM(
    List<DuplicateFactCandidate> candidates, {
    List<EntityFactBundle> factBundles = const [],
  }) async {
    final allResults = <ScoredFactPair>[];

    // Phase 1: LLM cross-key detection on entity fact bundles
    if (factBundles.isNotEmpty) {
      final bundles = factBundles.take(10).toList();
      final buf = StringBuffer();
      buf.writeln('For each entity, list ALL facts. Identify pairs of facts '
          'that express the SAME information (semantic duplicates).\n');
      for (final b in bundles) {
        buf.writeln('Entity "${b.entityName}" (ID ${b.entityId}):');
        for (final f in b.facts) {
          buf.writeln('  - fact_id=${f['id']}: ${f['key']} = ${f['value']}');
        }
        buf.writeln();
      }

      final systemPrompt = '''You are a semantic deduplication specialist.
For each entity, identify facts that express the SAME information.

Examples of duplicate facts:
- "vélo = possède un vélo" and "bicyclette = possède une bicyclette" (same object)
- "tel = 06 12 34" and "telephone = 06 12 34" (same fact, different key)
- "born = 1986" and "birthday = March 14, 1986" (compatible dates)

Examples of NON-duplicates:
- "vélo rouge" and "vélo bleu" (different attributes)
- "born = 1985" and "born = 1986" (conflicting values)

For each duplicate pair found, return: entity_id, fact_id_keep (the more informative one), fact_id_remove, score (0-100), justification (max 50 chars).

Return ONLY valid JSON:
{"pairs":[{"entity_id":1,"fact_id_keep":10,"fact_id_remove":11,"score":95,"justification":"Same object, synonym"}]}

If no duplicates found, return: {"pairs":[]}
No markdown fences, no explanation.''';

      try {
        final response = await _llmProvider.chat(
          messages: [
            Message(role: 'system', content: systemPrompt),
            Message(role: 'user', content: buf.toString()),
          ],
          model: _model,
          options: {'temperature': 0.1},
        );

        final llmPairs = _parseCrossKeyResponse(response.content, bundles);
        allResults.addAll(llmPairs);
      } catch (e) {
        AppLogger.instance.warning(
          LogSource.agent,
          'Dream cross-key fact detection failed: ${e.runtimeType}',
        );
      }
    }

    // Phase 2: Verify deterministic candidates (same-key duplicates)
    if (candidates.isEmpty) return allResults;

    final batch = candidates.take(20).toList();
    final buf = StringBuffer();
    buf.writeln('| # | Entity | Fact Key | Value A | Value B | Det. Score |');
    buf.writeln('|---|--------|----------|---------|---------|------------|');
    for (var i = 0; i < batch.length; i++) {
      final c = batch[i];
      buf.writeln(
        '| ${i + 1} '
        '| ${_sanitize(c.entityName)} '
        '| ${_sanitize(c.factKey)} '
        '| ${_sanitize(c.valueA)} '
        '| ${_sanitize(c.valueB)} '
        '| ${(c.similarity * 100).round()}% |',
      );
    }

    final systemPrompt = '''You are a semantic deduplication specialist.
Analyze pairs of facts on the SAME entity. Determine if they express the same information.

Examples of duplicates:
- "vélo" and "bicyclette" (same object)
- "born 1986" and "born March 14, 1986" (compatible dates)
- "tel: 06 12 34" and "phone: 06 12 34" (same fact, different key)

Examples of NON-duplicates:
- "vélo rouge" and "vélo bleu" (different objects)
- "born 1985" and "born 1986" (conflicting dates)

For each pair, return: index (1-based), score (0-100), keep (A or B — the more informative one), justification (max 50 chars).

Return ONLY valid JSON:
{"pairs":[{"index":1,"score":95,"keep":"B","justification":"Same object, B more precise"}]}

No markdown fences, no explanation.''';

    try {
      final response = await _llmProvider.chat(
        messages: [
          Message(role: 'system', content: systemPrompt),
          Message(role: 'user', content: buf.toString()),
        ],
        model: _model,
        options: {'temperature': 0.1},
      );

      return _parseFactLlmResponse(response.content, batch);
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Dream fact verification failed: ${e.runtimeType}',
      );
      return batch.map((c) => ScoredFactPair(
            entityId: c.entityId,
            entityName: c.entityName,
            factIdKeep: c.factIdA,
            factIdRemove: c.factIdB,
            factKey: c.factKey,
            valueKeep: c.valueA,
            valueRemove: c.valueB,
            score: c.similarity,
            justification: 'Deterministic score only',
          )).toList();
    }
  }

  List<ScoredFactPair> _parseFactLlmResponse(
    String content,
    List<DuplicateFactCandidate> batch,
  ) {
    try {
      var json = content.trim();
      if (json.startsWith('```')) {
        json = json.replaceFirst(RegExp(r'^```\w*\n?'), '');
        json = json.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final data = jsonDecode(json) as Map<String, dynamic>;
      final pairs = data['pairs'] as List? ?? [];
      final result = <ScoredFactPair>[];
      final processed = <int>{};

      for (final p in pairs) {
        final index = ((p['index'] as num?)?.toInt() ?? 0) - 1;
        if (index < 0 || index >= batch.length) continue;
        if (processed.contains(index)) continue;
        processed.add(index);

        final c = batch[index];
        final score = ((p['score'] as num?)?.toDouble() ?? 0) / 100.0;
        final keep = (p['keep'] as String?) ?? 'A';
        final justification =
            _truncate((p['justification'] as String?) ?? '', 100);

        final keepA = keep.toUpperCase() == 'A';
        result.add(ScoredFactPair(
          entityId: c.entityId,
          entityName: c.entityName,
          factIdKeep: keepA ? c.factIdA : c.factIdB,
          factIdRemove: keepA ? c.factIdB : c.factIdA,
          factKey: c.factKey,
          valueKeep: keepA ? c.valueA : c.valueB,
          valueRemove: keepA ? c.valueB : c.valueA,
          score: score,
          justification: justification,
        ));
      }

      // Add unprocessed as deterministic
      for (var i = 0; i < batch.length; i++) {
        if (processed.contains(i)) continue;
        final c = batch[i];
        result.add(ScoredFactPair(
          entityId: c.entityId,
          entityName: c.entityName,
          factIdKeep: c.factIdA,
          factIdRemove: c.factIdB,
          factKey: c.factKey,
          valueKeep: c.valueA,
          valueRemove: c.valueB,
          score: c.similarity,
          justification: 'Deterministic score only',
        ));
      }

      return result;
    } catch (e) {
      return batch.map((c) => ScoredFactPair(
            entityId: c.entityId,
            entityName: c.entityName,
            factIdKeep: c.factIdA,
            factIdRemove: c.factIdB,
            factKey: c.factKey,
            valueKeep: c.valueA,
            valueRemove: c.valueB,
            score: c.similarity,
            justification: 'Deterministic score only',
          )).toList();
    }
  }

  /// Remove a duplicate fact by soft-deleting it (set expired_at).
  Future<void> expireFact(int factId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement(
      'UPDATE facts SET expired_at = ? WHERE id = ?',
      [now, factId],
    );
  }

  // ─── Cleanup: LLM-based full KB analysis ──────────────────────────

  static const _entityTableHeader =
      '| ID | Name | Type | Facts | Aliases | Relations |\n'
      '|----|------|------|-------|---------|-----------|\n';
  static const _relationTableHeader =
      '| ID | Source | → | Target | Type |\n'
      '|----|--------|---|--------|------|\n';

  /// Build compact markdown snapshots of the KB for LLM analysis, chunked
  /// by entity id range so each cleanup prompt stays within context bounds
  /// at several-thousand-entity scale (U15).
  ///
  /// Each chunk is self-contained: a complete entity table plus the
  /// relation table for relations whose *source* entity falls in the chunk
  /// (target names are inlined, so cross-chunk targets stay readable).
  /// Chunk boundaries never split an entity row — an entity and its
  /// outgoing relations always land in the same chunk. A small KB yields a
  /// single chunk with the same content as the old unchunked snapshot.
  ///
  /// [maxChunkChars] defaults to [AppConstants.kbSnapshotChunkMaxChars]; a
  /// single oversized entity block still becomes its own chunk (the bound
  /// is best-effort for pathological rows).
  Future<List<String>> buildKBSnapshotChunks({int? maxChunkChars}) async {
    final budget = maxChunkChars ?? AppConstants.kbSnapshotChunkMaxChars;

    // Batch query: all active entities with fact counts, aliases, relations
    final entities = await _db.customSelect(
      'SELECT e.id, e.name, e.entity_type, '
      '(SELECT COUNT(*) FROM facts f WHERE f.entity_id = e.id AND f.expired_at IS NULL) AS fact_count '
      'FROM entities e WHERE e.is_active = 1 '
      'ORDER BY e.id',
    ).get();

    final aliases = await _db.customSelect(
      'SELECT entity_id, alias_name FROM aliases '
      'WHERE entity_id IN (SELECT id FROM entities WHERE is_active = 1)',
    ).get();

    final relations = await _db.customSelect(
      'SELECT r.id, r.source_id, r.target_id, r.predicate, '
      'src.name AS source_name, tgt.name AS target_name '
      'FROM relations r '
      'JOIN entities src ON src.id = r.source_id '
      'JOIN entities tgt ON tgt.id = r.target_id '
      'WHERE r.is_active = 1 AND r.expired_at IS NULL '
      'ORDER BY r.id',
    ).get();

    // Index aliases by entity_id
    final aliasMap = <int, List<String>>{};
    for (final a in aliases) {
      final eid = a.read<int>('entity_id');
      (aliasMap[eid] ??= []).add(a.read<String>('alias_name'));
    }

    // Index relations by source entity_id: short target list for the entity
    // table, full rows for the relation table.
    final relByEntity = <int, List<String>>{};
    final relRowsBySource = <int, List<String>>{};
    for (final r in relations) {
      final srcId = r.read<int>('source_id');
      final tgtName = r.read<String>('target_name');
      (relByEntity[srcId] ??= []).add('→$tgtName');
      (relRowsBySource[srcId] ??= []).add(
        '| ${r.read<int>('id')} | ${r.read<String>('source_name')} '
        '| → | $tgtName | ${r.read<String>('predicate')} |\n',
      );
    }

    // Fixed per-chunk overhead: both table headers + the blank separator.
    final overhead =
        _entityTableHeader.length + 1 + _relationTableHeader.length;

    final chunks = <String>[];
    var entityLines = <String>[];
    var relationLines = <String>[];
    var size = overhead;

    void flush() {
      if (entityLines.isEmpty) return;
      final buf = StringBuffer()
        ..write(_entityTableHeader)
        ..writeAll(entityLines)
        ..writeln()
        ..write(_relationTableHeader)
        ..writeAll(relationLines);
      chunks.add(buf.toString());
      entityLines = <String>[];
      relationLines = <String>[];
      size = overhead;
    }

    for (final e in entities) {
      final id = e.read<int>('id');
      final name = e.read<String>('name');
      final type = e.read<String>('entity_type');
      final factCount = e.read<int>('fact_count');
      final aliasList = aliasMap[id]?.join(', ') ?? '';
      final relList = relByEntity[id]?.join(', ') ?? '';
      final entityLine =
          '| $id | $name | $type | $factCount | $aliasList | $relList |\n';
      final relRows = relRowsBySource[id] ?? const <String>[];
      var blockSize = entityLine.length;
      for (final row in relRows) {
        blockSize += row.length;
      }

      // Flush before adding if the whole block would overflow the budget
      // (never split an entity row from its relations).
      if (entityLines.isNotEmpty && size + blockSize > budget) flush();

      entityLines.add(entityLine);
      relationLines.addAll(relRows);
      size += blockSize;
    }
    flush();

    // Empty KB: keep the old behavior of one (header-only) snapshot.
    if (chunks.isEmpty) {
      chunks.add('$_entityTableHeader\n$_relationTableHeader');
    }
    return chunks;
  }

  /// Send one KB snapshot chunk to LLM and get proposed cleanup operations.
  ///
  /// Callers iterate the chunks from [buildKBSnapshotChunks] (one LLM call
  /// per chunk) and aggregate the returned operations.
  Future<List<CleanupOperation>> proposeCleanup(String snapshot) async {
    final langInstr = (kbLanguage != null && kbLanguage != 'en')
        ? '\n\nIMPORTANT: The KB data is in ${_languageName(kbLanguage!)}. '
          'Write reasons in the same language as the data.'
        : '';

    final systemPrompt =
        'You are a knowledge base maintenance specialist.\n\n'
        'Analyze the entity and relation tables below and propose cleanup operations.\n\n'
        'Look for:\n'
        '1. DUPLICATE ENTITIES: Same real-world thing with different names → merge (keep the most descriptive name as primary)\n'
        '2. GARBAGE ENTITIES: Test data, URL fragments, meaningless strings → delete\n'
        '3. EPHEMERAL ENTITIES: Dates (2026-03-13), relative time (aujourd\'hui, demain, mercredi) → delete\n'
        '4. ORPHAN RELATIONS: Relations to/from nonsensical entities → delete_relation\n'
        '5. DUPLICATE RELATIONS: Multiple identical relations between same entities → delete_relation (keep one)\n\n'
        'Rules:\n'
        '- Prefer merge over delete when two entities represent the same concept\n'
        '- When merging PERSON entities, keep the most complete name as primary\n'
        '- For phone numbers stored as entities: suggest deleting them (they should be facts on the owner)\n\n'
        'Include a "confidence" field (integer 0-100) for each operation:\n'
        '- 90-100: Certain (obvious garbage, exact duplicates, clearly stale)\n'
        '- 60-89: Probable (likely duplicates, stale data, probably correct)\n'
        '- 30-59: Uncertain (might be valid, needs human review)\n'
        '- 0-29: Speculative (low evidence, better to keep than delete)\n\n'
        'Return ONLY valid JSON (no markdown fences):\n'
        '{"operations":[...], "summary":"..."}\n\n'
        'Operation types:\n'
        '- merge: {"type":"merge", "primary_id":N, "secondary_id":N, "confidence":85, "reason":"..."}\n'
        '- delete: {"type":"delete", "entity_id":N, "confidence":95, "reason":"..."}\n'
        '- delete_relation: {"type":"delete_relation", "relation_id":N, "confidence":70, "reason":"..."}'
        '$langInstr';

    final userMessage = 'Here is the KB snapshot:\n\n$snapshot';

    final response = await _llmProvider.chat(
      messages: [
        Message(role: 'system', content: systemPrompt),
        Message(role: 'user', content: userMessage),
      ],
      model: _model,
      options: {'temperature': 0.1, 'max_tokens': 16384},
    );

    final content = response.content.trim();
    return parseCleanupResponse(content);
  }

  /// Parse LLM cleanup response JSON into operation objects.
  ///
  /// Static for testability. Reads `confidence` (or fallback `score`) from
  /// each operation, clamped to 0-100. Missing confidence defaults to null.
  static List<CleanupOperation> parseCleanupResponse(String content) {
    var json = content.trim();
    // Strip markdown fences if present
    if (json.startsWith('```')) {
      json = json.replaceFirst(RegExp(r'^```\w*\n?'), '');
      json = json.replaceFirst(RegExp(r'\n?```$'), '');
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final ops = data['operations'] as List<dynamic>? ?? [];
    final result = <CleanupOperation>[];

    for (final op in ops) {
      final map = op as Map<String, dynamic>;
      final type = map['type'] as String?;
      final reason = map['reason'] as String? ?? '';
      final rawConf = map['confidence'] ?? map['score'];
      final confidence = rawConf != null
          ? (rawConf is num ? rawConf.toInt() : int.tryParse('$rawConf'))?.clamp(0, 100)
          : null;

      switch (type) {
        case 'delete':
          final entityId = (map['entity_id'] as num?)?.toInt();
          if (entityId != null) {
            result.add(CleanupDelete(entityId: entityId, reason: reason, confidence: confidence));
          }
        case 'merge':
          final primaryId = (map['primary_id'] as num?)?.toInt();
          final secondaryId = (map['secondary_id'] as num?)?.toInt();
          if (primaryId != null && secondaryId != null) {
            result.add(CleanupMerge(
              primaryId: primaryId,
              secondaryId: secondaryId,
              reason: reason,
              confidence: confidence,
            ));
          }
        case 'delete_relation':
          final relationId = (map['relation_id'] as num?)?.toInt();
          if (relationId != null) {
            result.add(CleanupDeleteRelation(
              relationId: relationId,
              reason: reason,
              confidence: confidence,
            ));
          }
      }
    }

    return result;
  }

  /// Execute cleanup operations with validation and PERSON protection.
  ///
  /// Execution order: merges → delete_relations → deletes.
  Future<CleanupResult> executeCleanupOps(List<CleanupOperation> ops) async {
    // Sort by type: merges first, then delete_relations, then deletes
    final merges = ops.whereType<CleanupMerge>().toList();
    final deleteRelations = ops.whereType<CleanupDeleteRelation>().toList();
    final deletes = ops.whereType<CleanupDelete>().toList();

    // Batch-load all referenced entity IDs for validation
    final allEntityIds = <int>{};
    for (final m in merges) {
      allEntityIds.add(m.primaryId);
      allEntityIds.add(m.secondaryId);
    }
    for (final d in deletes) {
      allEntityIds.add(d.entityId);
    }

    // Load entity info (id, name, is_active, entity_type) in one query
    final entityInfo = <int, ({String name, bool isActive, String type})>{};
    if (allEntityIds.isNotEmpty) {
      final placeholders = allEntityIds.map((_) => '?').join(',');
      final rows = await _db.customSelect(
        'SELECT id, name, is_active, entity_type FROM entities WHERE id IN ($placeholders)',
        variables: allEntityIds.map((id) => Variable.withInt(id)).toList(),
      ).get();
      for (final row in rows) {
        entityInfo[row.read<int>('id')] = (
          name: row.read<String>('name'),
          isActive: row.read<bool>('is_active'),
          type: row.read<String>('entity_type'),
        );
      }
    }

    // Load relation info for delete_relation ops
    final allRelationIds = deleteRelations.map((dr) => dr.relationId).toSet();
    final relationInfo = <int, ({String sourceName, String targetName, String predicate})>{};
    if (allRelationIds.isNotEmpty) {
      final placeholders = allRelationIds.map((_) => '?').join(',');
      final rows = await _db.customSelect(
        'SELECT r.id, src.name AS source_name, tgt.name AS target_name, r.predicate '
        'FROM relations r '
        'JOIN entities src ON src.id = r.source_id '
        'JOIN entities tgt ON tgt.id = r.target_id '
        'WHERE r.id IN ($placeholders)',
        variables: allRelationIds.map((id) => Variable.withInt(id)).toList(),
      ).get();
      for (final row in rows) {
        relationInfo[row.read<int>('id')] = (
          sourceName: row.read<String>('source_name'),
          targetName: row.read<String>('target_name'),
          predicate: row.read<String>('predicate'),
        );
      }
    }

    var mergeCount = 0;
    var deleteCount = 0;
    var deleteRelationCount = 0;
    final errors = <String>[];
    final executedOps = <String>[];

    // Execute merges
    for (final m in merges) {
      final primary = entityInfo[m.primaryId];
      final secondary = entityInfo[m.secondaryId];
      if (primary == null || !primary.isActive) {
        errors.add('merge: primary #${m.primaryId} not found or inactive');
        continue;
      }
      if (secondary == null || !secondary.isActive) {
        errors.add('merge: secondary #${m.secondaryId} not found or inactive');
        continue;
      }
      try {
        await _db.mergeEntities(m.primaryId, m.secondaryId);
        mergeCount++;
        final confStr = m.confidence != null ? ' (${m.confidence}%)' : '';
        final desc = 'MERGE: "${secondary.name}" (#${m.secondaryId}) → "${primary.name}" (#${m.primaryId})$confStr — ${m.reason}';
        executedOps.add(desc);
        AppLogger.instance.info(LogSource.agent, 'cleanup: $desc');
      } catch (e) {
        errors.add('merge #${m.primaryId}←#${m.secondaryId}: $e');
      }
    }

    // Execute delete_relations
    for (final dr in deleteRelations) {
      final rel = relationInfo[dr.relationId];
      try {
        await _db.expireRelation(dr.relationId);
        deleteRelationCount++;
        final confStr = dr.confidence != null ? ' (${dr.confidence}%)' : '';
        final desc = rel != null
            ? 'DEL REL: "${rel.sourceName}" —[${rel.predicate}]→ "${rel.targetName}" (#${dr.relationId})$confStr — ${dr.reason}'
            : 'DEL REL: relation #${dr.relationId}$confStr — ${dr.reason}';
        executedOps.add(desc);
        AppLogger.instance.info(LogSource.agent, 'cleanup: $desc');
      } catch (e) {
        errors.add('delete_relation #${dr.relationId}: $e');
      }
    }

    // Execute deletes
    for (final d in deletes) {
      final info = entityInfo[d.entityId];
      if (info == null || !info.isActive) {
        errors.add('delete: entity #${d.entityId} not found or inactive');
        continue;
      }
      try {
        await _db.deactivateEntity(d.entityId);
        deleteCount++;
        final confStr = d.confidence != null ? ' (${d.confidence}%)' : '';
        final desc = 'DELETE: "${info.name}" (#${d.entityId}, ${info.type})$confStr — ${d.reason}';
        executedOps.add(desc);
        AppLogger.instance.info(LogSource.agent, 'cleanup: $desc');
      } catch (e) {
        errors.add('delete entity #${d.entityId}: $e');
      }
    }

    return CleanupResult(
      mergeCount: mergeCount,
      deleteCount: deleteCount,
      deleteRelationCount: deleteRelationCount,
      errors: errors,
      executedOps: executedOps,
    );
  }

  /// Load entity names for a set of cleanup operations (for display).
  Future<Map<int, String>> loadEntityNames(List<CleanupOperation> ops) async {
    final ids = <int>{};
    for (final op in ops) {
      switch (op) {
        case CleanupMerge(:final primaryId, :final secondaryId):
          ids.add(primaryId);
          ids.add(secondaryId);
        case CleanupDelete(:final entityId):
          ids.add(entityId);
        case CleanupDeleteRelation():
          break;
      }
    }
    if (ids.isEmpty) return {};
    final placeholders = ids.map((_) => '?').join(',');
    final rows = await _db.customSelect(
      'SELECT id, name FROM entities WHERE id IN ($placeholders)',
      variables: ids.map((id) => Variable.withInt(id)).toList(),
    ).get();
    return {for (final r in rows) r.read<int>('id'): r.read<String>('name')};
  }

  /// Load relation descriptions (source → target) for display.
  Future<Map<int, String>> loadRelationDescs(List<int> relationIds) async {
    if (relationIds.isEmpty) return {};
    final placeholders = relationIds.map((_) => '?').join(',');
    final rows = await _db.customSelect(
      'SELECT r.id, src.name AS source_name, tgt.name AS target_name, r.predicate '
      'FROM relations r '
      'JOIN entities src ON src.id = r.source_id '
      'JOIN entities tgt ON tgt.id = r.target_id '
      'WHERE r.id IN ($placeholders)',
      variables: relationIds.map((id) => Variable.withInt(id)).toList(),
    ).get();
    return {
      for (final r in rows)
        r.read<int>('id'):
            '"${r.read<String>('source_name')}" —[${r.read<String>('predicate')}]→ "${r.read<String>('target_name')}"',
    };
  }

  static String _languageName(String code) {
    const names = {
      'fr': 'French',
      'es': 'Spanish',
      'de': 'German',
      'it': 'Italian',
    };
    return names[code] ?? code;
  }

  List<ScoredFactPair> _parseCrossKeyResponse(
    String content,
    List<EntityFactBundle> bundles,
  ) {
    try {
      var json = content.trim();
      if (json.startsWith('```')) {
        json = json.replaceFirst(RegExp(r'^```\w*\n?'), '');
        json = json.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final data = jsonDecode(json) as Map<String, dynamic>;
      final pairs = data['pairs'] as List? ?? [];

      // Build valid fact ID set and entity name lookup
      final validFactIds = <int>{};
      final entityNameById = <int, String>{};
      final factInfoById = <int, Map<String, dynamic>>{};
      for (final b in bundles) {
        entityNameById[b.entityId] = b.entityName;
        for (final f in b.facts) {
          final fid = f['id'] as int;
          validFactIds.add(fid);
          factInfoById[fid] = {...f, 'entity_id': b.entityId};
        }
      }

      final result = <ScoredFactPair>[];
      for (final p in pairs) {
        final keepId = (p['fact_id_keep'] as num?)?.toInt();
        final removeId = (p['fact_id_remove'] as num?)?.toInt();
        if (keepId == null || removeId == null) continue;
        if (!validFactIds.contains(keepId) || !validFactIds.contains(removeId)) continue;

        final keepInfo = factInfoById[keepId]!;
        final removeInfo = factInfoById[removeId]!;
        final entityId = keepInfo['entity_id'] as int;
        final score = ((p['score'] as num?)?.toDouble() ?? 0) / 100.0;
        final justification =
            _truncate((p['justification'] as String?) ?? '', 100);

        result.add(ScoredFactPair(
          entityId: entityId,
          entityName: entityNameById[entityId] ?? '',
          factIdKeep: keepId,
          factIdRemove: removeId,
          factKey: '${keepInfo['key']} / ${removeInfo['key']}',
          valueKeep: '${keepInfo['key']}: ${keepInfo['value']}',
          valueRemove: '${removeInfo['key']}: ${removeInfo['value']}',
          score: score,
          justification: justification,
        ));
      }
      return result;
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Dream: failed to parse cross-key response: ${e.runtimeType}',
      );
      return [];
    }
  }

  // -- Private helpers --

  /// Build a markdown table from candidate pairs for LLM verification.
  ///
  /// Exposed as static for testing. More compact than JSON, fewer tokens.
  static String buildVerificationTable(List<DuplicateCandidate> batch) {
    final buf = StringBuffer();
    buf.writeln('| # | ID_A | Name A | Aliases A | Facts A | ID_B | Name B | Aliases B | Facts B | Det. Score |');
    buf.writeln('|---|------|--------|-----------|---------|------|--------|-----------|---------|------------|');
    for (var i = 0; i < batch.length; i++) {
      final c = batch[i];
      buf.writeln(
        '| ${i + 1} '
        '| ${c.idA} | ${_sanitize(c.nameA)} '
        '| ${c.aliasesA.map(_sanitize).join(", ")} '
        '| ${c.factSummariesA.map(_sanitize).join("; ")} '
        '| ${c.idB} | ${_sanitize(c.nameB)} '
        '| ${c.aliasesB.map(_sanitize).join(", ")} '
        '| ${c.factSummariesB.map(_sanitize).join("; ")} '
        '| ${(c.compositeScore * 100).round()}% |',
      );
    }
    return buf.toString();
  }

  Future<List<ScoredPair>> _verifyBatch(
    List<DuplicateCandidate> batch,
  ) async {
    final validIds = <int>{};
    for (final c in batch) {
      validIds.add(c.idA);
      validIds.add(c.idB);
    }

    final systemPrompt = '''You are an Entity Resolution and Master Data Management specialist.
Analyze the candidate duplicate pairs in the table below.

SCORING METHOD (0 to 100%):
- Names & Aliases (40%): Spelling similarity, phonetic match, identical concepts (e.g. "URL rori" and "slug rori")
- Shared Relations (40%): Do they target the same people, places, or concepts?
- Facts (20%): Shared phone numbers, dates, or complementary attributes

For each pair, return: id_a, id_b, score (0-100), justification (max 50 chars).

Return ONLY valid JSON:
{"pairs":[{"id_a":1,"id_b":2,"score":85,"justification":"Same person, typo variant"}]}

No markdown fences, no explanation.''';

    final userMessage = buildVerificationTable(batch);

    try {
      final response = await _llmProvider.chat(
        messages: [
          Message(role: 'system', content: systemPrompt),
          Message(role: 'user', content: userMessage),
        ],
        model: _model,
        options: {'temperature': 0.1},
      );

      return parseLlmResponse(response.content, batch, validIds);
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Dream LLM verification failed: ${e.runtimeType}',
      );
      // Fallback to deterministic scores
      return batch.map(_toDeterministicPair).toList();
    }
  }

  /// Parse LLM JSON response into scored pairs.
  ///
  /// Exposed as static for testing. Handles markdown fences, missing pairs,
  /// and invalid IDs gracefully.
  static List<ScoredPair> parseLlmResponse(
    String content,
    List<DuplicateCandidate> batch,
    Set<int> validIds,
  ) {
    try {
      // Strip markdown fences if present
      var json = content.trim();
      if (json.startsWith('```')) {
        json = json.replaceFirst(RegExp(r'^```\w*\n?'), '');
        json = json.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final data = jsonDecode(json) as Map<String, dynamic>;
      final pairs = data['pairs'] as List? ?? [];

      // Build lookup from batch
      final batchLookup = <String, DuplicateCandidate>{};
      for (final c in batch) {
        final key = '${c.idA}:${c.idB}';
        batchLookup[key] = c;
      }

      final result = <ScoredPair>[];
      final processedKeys = <String>{};

      for (final p in pairs) {
        final idA = (p['id_a'] as num?)?.toInt();
        final idB = (p['id_b'] as num?)?.toInt();
        if (idA == null || idB == null) continue;

        // Validate IDs against sent set
        if (!validIds.contains(idA) || !validIds.contains(idB)) {
          AppLogger.instance.warning(
            LogSource.agent,
            'Dream: LLM returned unknown IDs $idA/$idB, skipping',
          );
          continue;
        }

        final score = ((p['score'] as num?)?.toDouble() ?? 0) / 100.0;
        final justification =
            _truncate((p['justification'] as String?) ?? '', 100);

        // Find matching candidate
        final key1 = '$idA:$idB';
        final key2 = '$idB:$idA';
        final candidate = batchLookup[key1] ?? batchLookup[key2];
        if (candidate == null) continue;

        processedKeys.add('${candidate.idA}:${candidate.idB}');

        result.add(ScoredPair(
          primaryId: candidate.idA,
          secondaryId: candidate.idB,
          primaryName: candidate.nameA,
          secondaryName: candidate.nameB,
          score: score,
          justification: justification,
          level: _classifyLevel(score),
        ));
      }

      // Add any batch entries not returned by LLM as deterministic
      for (final c in batch) {
        final key = '${c.idA}:${c.idB}';
        if (!processedKeys.contains(key)) {
          result.add(_toDeterministicPair(c));
        }
      }

      return result;
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Dream: failed to parse LLM response: ${e.runtimeType}',
      );
      return batch.map(_toDeterministicPair).toList();
    }
  }

  static ScoredPair _toDeterministicPair(DuplicateCandidate c) {
    return ScoredPair(
      primaryId: c.idA,
      secondaryId: c.idB,
      primaryName: c.nameA,
      secondaryName: c.nameB,
      score: c.compositeScore,
      justification: 'Deterministic score only',
      level: _classifyLevel(c.compositeScore),
    );
  }

  static int _classifyLevel(double score) {
    if (score > 0.85) return 1;
    if (score >= 0.50) return 2;
    return 3;
  }

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
  /// Only matches when the shorter name is at least 3 chars (avoids noise).
  static bool _anyNameContained(List<String> namesA, List<String> namesB) {
    for (final a in namesA) {
      final na = StringSimilarity.normalize(a);
      if (na.length < 3) continue;
      for (final b in namesB) {
        final nb = StringSimilarity.normalize(b);
        if (nb.length < 3) continue;
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

  static final _controlCharsRe = RegExp(r'[\x00-\x1f\x7f]');

  /// Sanitize entity content for LLM prompt: truncate and strip control chars.
  static String _sanitize(String s) {
    final cleaned = s.replaceAll(_controlCharsRe, '');
    return _truncate(cleaned, 100);
  }

  /// Truncate string to maxLen characters.
  static String _truncate(String s, int maxLen) {
    return s.length <= maxLen ? s : '${s.substring(0, maxLen)}...';
  }

  /// Date-aware fact scoring between two entities.
  ///
  /// For facts with matching keys:
  /// - Date facts use [DateSimilarity.score] (1.0 identical, 0.7 compatible, -0.3 conflict)
  /// - Non-date facts use exact value match (1.0 match, 0.0 mismatch)
  /// Also includes key Jaccard as a baseline.
  ///
  /// Final score = 0.6 * dateAwareMatch + 0.4 * keyJaccard, clamped to [0, 1].
  static double _factScore(List<_FactEntry> factsA, List<_FactEntry> factsB) {
    if (factsA.isEmpty && factsB.isEmpty) return 0.0;
    if (factsA.isEmpty || factsB.isEmpty) return 0.0;

    // Key Jaccard baseline
    final keysA = factsA.map((f) => f.key).toSet();
    final keysB = factsB.map((f) => f.key).toSet();
    final keyJaccard = _jaccard(keysA, keysB);

    // Build key→value maps for matching
    final mapA = <String, _FactEntry>{};
    for (final f in factsA) {
      mapA[f.key] = f;
    }
    final mapB = <String, _FactEntry>{};
    for (final f in factsB) {
      mapB[f.key] = f;
    }

    // Score matching keys with date awareness
    final sharedKeys = keysA.intersection(keysB);
    if (sharedKeys.isEmpty) return 0.4 * keyJaccard;

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
    return (0.6 * matchScore + 0.4 * keyJaccard).clamp(0.0, 1.0);
  }
}

// ─── Cleanup operation types ─────────────────────────────────────────

/// Sealed class for KB cleanup operations proposed by LLM.
sealed class CleanupOperation {
  final String reason;
  final int? confidence;
  const CleanupOperation({required this.reason, this.confidence});
}

/// Delete a garbage/ephemeral entity.
class CleanupDelete extends CleanupOperation {
  final int entityId;
  const CleanupDelete({required this.entityId, required super.reason, super.confidence});
}

/// Merge duplicate entities.
class CleanupMerge extends CleanupOperation {
  final int primaryId;
  final int secondaryId;
  const CleanupMerge({
    required this.primaryId,
    required this.secondaryId,
    required super.reason,
    super.confidence,
  });
}

/// Delete a duplicate/stale relation.
class CleanupDeleteRelation extends CleanupOperation {
  final int relationId;
  const CleanupDeleteRelation({required this.relationId, required super.reason, super.confidence});
}

/// Result of executing cleanup operations, with detailed execution log.
class CleanupResult {
  final int mergeCount;
  final int deleteCount;
  final int deleteRelationCount;
  final List<String> errors;
  /// Detailed log of each executed operation (human-readable).
  final List<String> executedOps;

  const CleanupResult({
    required this.mergeCount,
    required this.deleteCount,
    required this.deleteRelationCount,
    required this.errors,
    required this.executedOps,
  });

  int get totalExecuted => mergeCount + deleteCount + deleteRelationCount;
}

/// Internal fact entry with key, value, and type.
class _FactEntry {
  final String key;
  final String value;
  final String type;

  const _FactEntry({
    required this.key,
    required this.value,
    required this.type,
  });
}

/// Bundle of facts for a single entity, for LLM cross-key dedup.
class EntityFactBundle {
  final int entityId;
  final String entityName;
  final List<Map<String, dynamic>> facts;

  const EntityFactBundle({
    required this.entityId,
    required this.entityName,
    required this.facts,
  });
}
