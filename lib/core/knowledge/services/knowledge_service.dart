import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../shared/constants.dart';
import '../../config/log_entry.dart';
import '../../providers/embedding_provider.dart';
import '../../services/app_logger.dart';
import '../algorithms/embedding_codec.dart';
import '../algorithms/hybrid_scorer.dart';
import '../algorithms/memory_clusterer.dart';
import '../algorithms/memory_decay.dart';
import '../algorithms/spreading_activation.dart';
import '../database/knowledge_graph_db.dart';
import '../models/entity.dart';
import '../models/ranked_result.dart';

/// High-level API for the Knowledge Graph.
///
/// Wraps the Drift database + algorithms to provide:
/// - Hybrid query pipeline (queryRelevant) with optional vector search
/// - Batch decay recalculation
/// - Entity/fact/relation CRUD
/// - Statistics
class KnowledgeService {
  final KnowledgeGraphDB db;

  /// Optional embedding provider for vector similarity search.
  final EmbeddingProvider? embeddingProvider;

  /// Model name for embedding API calls.
  final String embeddingModel;

  /// Output dimensions for embeddings.
  final int embeddingDimensions;

  /// Whether vector similarity is available.
  bool get hasEmbedder => embeddingProvider != null;

  /// Page size for the keyset-paged embedding scan (injectable for tests;
  /// production uses [AppConstants.knowledgeEmbeddingScanPageSize]). Bounds
  /// resident BLOBs only — the scan always covers ALL active embeddings.
  final int embeddingScanPageSize;

  final _spreading = const SpreadingActivation();

  /// True when the last [queryRelevant] call had an embedder configured but
  /// the query embed failed at query time (API down, bad key, ...) — the
  /// vector path was skipped and retrieval degraded to lexical-only on the
  /// raw query. Callers that skip LLM keyword expansion BECAUSE an embedder
  /// is configured (see AgentLoop) must check this and retry with expansion,
  /// or the documented semantic-gap bug re-opens (docs/solutions/logic-errors/
  /// knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md).
  bool get lastQueryVectorPathFailed => _lastQueryVectorPathFailed;
  bool _lastQueryVectorPathFailed = false;

  KnowledgeService({
    required this.db,
    this.embeddingProvider,
    this.embeddingModel = '',
    this.embeddingDimensions = 768,
    this.embeddingScanPageSize = AppConstants.knowledgeEmbeddingScanPageSize,
  });

  /// Query the knowledge graph for entities relevant to a text query.
  ///
  /// Returns ranked entities with attached facts and relations,
  /// sorted by fused score (descending).
  ///
  /// The vector path runs even when FTS finds zero lexical candidates, so a
  /// configured embedder bridges the semantic gap (paraphrased queries with
  /// no token overlap with stored entities/facts) without any LLM query
  /// expansion. See docs/solutions/logic-errors/
  /// knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md.
  Future<List<RankedEntity>> queryRelevant(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    // 1. FTS5 BM25 search on entities + facts (3x limit for candidate pool)
    final ftsQuery = _buildFtsQuery(query);
    var ftsResults = <SearchEntitiesResult>[];
    var factResults = <SearchFactsResult>[];
    if (ftsQuery.isNotEmpty) {
      ftsResults = await db.searchEntities(ftsQuery, limit * 3).get();
      factResults = await db.searchFacts(ftsQuery, limit * 3).get();
    }

    // Collect BM25 scores (rank is negative in FTS5, more negative = better)
    final bm25Scores = <int, double>{};
    for (final r in ftsResults) {
      bm25Scores[r.id] = r.rank;
    }

    // Merge fact matches: map fact → parent entity, keep best score per entity.
    // Entities that appear in BOTH entity and fact search get a boost.
    for (final f in factResults) {
      final entityId = f.entityId;
      final factScore = f.rank;
      if (bm25Scores.containsKey(entityId)) {
        // Entity matched on both name AND facts — boost by taking better score
        if (factScore < bm25Scores[entityId]!) {
          bm25Scores[entityId] = factScore;
        }
      } else {
        bm25Scores[entityId] = factScore;
      }
    }

    // 2. Vector similarity search (if embedder is available). Runs regardless
    // of FTS results: this is the semantic-gap bridge.
    final vectorScores = <int, double>{};
    _lastQueryVectorPathFailed = false;
    if (hasEmbedder) {
      try {
        final queryResult = await embeddingProvider!.embed(
          texts: [query],
          model: embeddingModel,
          dimensions: embeddingDimensions,
          taskType: 'RETRIEVAL_QUERY',
        );
        if (queryResult.embeddings.isNotEmpty) {
          final queryVec = Float32List.fromList(queryResult.embeddings.first);
          // Same candidate-pool multiplier as the FTS path above: the
          // downstream getEntitiesByIds/findNeighborsBatch IN-lists are
          // documented as top-K-sized, so the vector pool must be capped too.
          vectorScores.addAll(
              await _scanEmbeddings(queryVec, maxCandidates: limit * 3));
        }
      } catch (e) {
        _lastQueryVectorPathFailed = true;
        AppLogger.instance.warning(
          LogSource.agent,
          'KG vector search failed, falling back to degraded mode: $e',
        );
      }
    }

    // 3. Union candidates (FTS + vector)
    final candidateIds = <int>{...bm25Scores.keys, ...vectorScores.keys};
    if (candidateIds.isEmpty) return [];

    // 4. Load 2-hop subgraph neighbors — one batched query per hop.
    final neighborEdges = await db.findNeighborsBatch(candidateIds.toList());
    final expandedIds = Set<int>.from(candidateIds);
    for (final edges in neighborEdges.values) {
      for (final e in edges) {
        expandedIds.add(e.neighborId);
      }
    }

    final hop1Ids = expandedIds.difference(candidateIds);
    final hop2Edges = await db.findNeighborsBatch(hop1Ids.toList());
    neighborEdges.addAll(hop2Edges);
    for (final edges in hop2Edges.values) {
      for (final e in edges) {
        expandedIds.add(e.neighborId);
      }
    }
    // Ids whose neighbors have been loaded (an anchor with zero edges has no
    // map entry, but must not be re-queried during hydration).
    final neighborsLoaded = <int>{...candidateIds, ...hop1Ids};

    // 5. Spreading activation.
    // Seed from top BM25 results (entity + fact combined); when there is no
    // lexical match at all, seed from the best vector candidates instead so
    // graph context still spreads from semantic hits.
    final seeds = <int, double>{};
    if (bm25Scores.isNotEmpty) {
      final topCandidates = bm25Scores.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value)); // more negative = better
      for (final entry
          in topCandidates.take(AppConstants.knowledgeActivationSeedCount)) {
        seeds[entry.key] = 1.0;
      }
    } else {
      final topVector = vectorScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // higher = better
      for (final entry
          in topVector.take(AppConstants.knowledgeActivationSeedCount)) {
        seeds[entry.key] = 1.0;
      }
    }

    final activationScores = _spreading.activate(
      seeds: seeds,
      neighborFn: (id) => [
        for (final e in neighborEdges[id] ?? const <NeighborEdge>[])
          (entityId: e.neighborId, weight: e.weight),
      ],
    );

    // 6. Load all expanded entities in one batch: used for both decay
    // computation and top-K hydration (no per-id re-fetch).
    final entityRows = {
      for (final e in await db.getEntitiesByIds(expandedIds.toList())) e.id: e,
    };
    final decayScores = <int, double>{
      for (final e in entityRows.values)
        e.id: MemoryDecay.retention(
          lastAccessedEpoch: e.lastAccessed,
          accessCount: e.accessCount,
        ),
    };

    // 7. Score fusion (full mode if vectorScores available, degraded otherwise)
    final scored = HybridScorer.fuse(
      candidates: expandedIds,
      bm25Scores: bm25Scores,
      vectorScores: vectorScores.isNotEmpty ? vectorScores : null,
      activationScores: activationScores,
      decayScores: decayScores,
    );

    // 8. Take top-K and hydrate with facts + relations (batched).
    final topK = scored.take(limit).toList();

    // Skip deactivated entities as defense-in-depth.
    final topIds = [
      for (final s in topK)
        if (entityRows[s.entityId] case final e? when e.isActive == 1)
          s.entityId,
    ];

    // One batched facts query for all top-K entities.
    final factsByEntity = <int, List<KnowledgeFact>>{};
    for (final f in await db.getFactsForEntityIds(topIds)) {
      (factsByEntity[f.entityId] ??= []).add(KnowledgeFact(
        id: f.id,
        entityId: f.entityId,
        key: f.factKey,
        value: f.factValue,
        valueType: f.valueType,
        validAt: f.validAt,
        invalidAt: f.invalidAt,
        ingestedAt: f.ingestedAt,
        expiredAt: f.expiredAt,
        confidence: f.confidence,
        sourceText: f.sourceText,
      ));
    }

    // Relations come from the neighbor edges already loaded; only hop-2
    // entities that made the top-K need one extra batched lookup.
    final missingNeighborIds =
        topIds.where((id) => !neighborsLoaded.contains(id)).toList();
    if (missingNeighborIds.isNotEmpty) {
      neighborEdges.addAll(await db.findNeighborsBatch(missingNeighborIds));
    }

    final results = <RankedEntity>[];
    for (final s in topK) {
      final entity = entityRows[s.entityId];
      if (entity == null || entity.isActive == 0) continue;

      final knowledgeRelations = [
        for (final e in neighborEdges[s.entityId] ?? const <NeighborEdge>[])
          KnowledgeRelation(
            sourceId: s.entityId,
            targetId: e.neighborId,
            predicate: e.predicate,
            weight: e.weight,
            confidence: e.relConfidence,
          ),
      ];

      results.add(RankedEntity(
        entity: KnowledgeEntity(
          id: entity.id,
          name: entity.name,
          entityType: EntityType.fromString(entity.entityType),
          summary: entity.summary,
          createdAt: entity.createdAt,
          lastAccessed: entity.lastAccessed,
          accessCount: entity.accessCount,
          temperature: Temperature.fromString(entity.temperature),
          baseScore: entity.baseScore,
          isActive: entity.isActive == 1,
        ),
        facts: factsByEntity[s.entityId] ?? const [],
        relations: knowledgeRelations,
        score: s.score,
        bm25Score: s.bm25Score,
        vectorScore: s.vectorScore,
        activationScore: s.activationScore,
        decayScore: s.decayScore,
      ));
    }

    // Touch retrieved entities (reinforcement)
    final touchIds = results.map((r) => r.entity.id!).toList();
    if (touchIds.isNotEmpty) {
      await db.touchEntities(touchIds);
    }

    return results;
  }

  /// Number of vector candidates produced by the last [_scanEmbeddings] run
  /// (after the top-N cap). Test-only observability for the candidate cap.
  @visibleForTesting
  int lastVectorCandidateCount = 0;

  /// Cosine-scan ALL active entity embeddings against [queryVec], in keyset
  /// pages of [embeddingScanPageSize] rows (U14), keeping only the
  /// [maxCandidates] best-scoring entities above the similarity threshold.
  ///
  /// Replaces the old single `getActiveEntityEmbeddings(limit: 1000)` load,
  /// which silently ignored every entity past the first 1000 and kept the
  /// whole embedding list materialized on the agent isolate. Paging bounds
  /// memory to one page of BLOBs; scoring is unchanged (same math, same
  /// threshold). The scan stays on the calling isolate by design: the
  /// benchmark in tool/benchmark_cosine_scan.dart showed Isolate.run is ~2x
  /// slower at 5K entities because copying the embeddings dominates the
  /// cosine math.
  ///
  /// The cap mirrors the FTS candidate pool (`limit * 3` in [queryRelevant]):
  /// without it, every entity above the threshold would flow into the
  /// `getEntitiesByIds`/`findNeighborsBatch` IN-lists, which are documented
  /// as top-K-sized. Running top-N selection per page (sort of at most
  /// pageSize + maxCandidates entries) keeps memory bounded.
  Future<Map<int, double>> _scanEmbeddings(
    Float32List queryVec, {
    required int maxCandidates,
  }) async {
    var top = <({int id, double sim})>[];
    var afterId = 0;
    while (true) {
      final page = await db.getActiveEntityEmbeddingsPage(
        afterId: afterId,
        pageSize: embeddingScanPageSize,
      );
      if (page.isEmpty) break;
      for (final entry in page) {
        final entVec = EmbeddingCodec.decode(entry.embedding);
        if (entVec.length != queryVec.length) continue;
        final sim = MemoryClusterer.cosineSimilarity(queryVec, entVec);
        if (sim > AppConstants.knowledgeVectorSimilarityThreshold) {
          top.add((id: entry.id, sim: sim));
        }
      }
      // Running top-N: prune once per page, never let the pool exceed the cap
      // between pages.
      if (top.length > maxCandidates) {
        top.sort((a, b) => b.sim.compareTo(a.sim));
        top = top.sublist(0, maxCandidates);
      }
      afterId = page.last.id;
      if (page.length < embeddingScanPageSize) break;
    }
    lastVectorCandidateCount = top.length;
    return {for (final t in top) t.id: t.sim};
  }

  /// Batch recalculate memory decay.
  /// Returns the number of entities whose temperature changed.
  ///
  /// U15: the recompute is restricted to rows whose temperature could
  /// actually cross a threshold instead of loading every active entity each
  /// hour. Non-cold rows can always decay further, so they are always
  /// candidates (a small population — anything untouched for days is cold).
  /// A cold row can only leave 'cold' when a recent access pushed its
  /// retention back above the cool threshold; using
  /// [MemoryDecay.maxAgeForRetention] with the max access count among cold
  /// rows gives an exact superset cutoff (stability grows with access
  /// count), so no crossing row is ever missed and the decay math stays
  /// solely in memory_decay.dart.
  Future<int> recalculateDecay() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final maxColdAccessCount = await db.maxColdAccessCount();
    final coldCutoff = now -
        MemoryDecay.maxAgeForRetention(
          MemoryDecay.coolThreshold,
          maxColdAccessCount,
        ).ceil();
    final entities = await db.getDecayCandidates(coldCutoff);

    final updates = MemoryDecay.batchDecay(entities, nowEpoch: now);
    if (updates.isNotEmpty) {
      await db.batchUpdateTemperatures(
        updates.map((u) => (id: u.id, temp: u.temp)).toList(),
      );
    }
    return updates.length;
  }

  /// Get entity count (active only).
  Future<int> entityCount() async {
    return await db.countEntities().getSingle();
  }

  /// Get relation count (active, non-expired).
  Future<int> relationCount() async {
    return await db.countRelations().getSingle();
  }

  /// Get database file size in bytes.
  Future<int> databaseSize(String dbPath) async {
    return await db.getDatabaseSize(dbPath);
  }

  /// List entities for browsing with optional filters.
  Future<List<(KnowledgeEntity, int)>> listEntities({
    int limit = 50,
    int offset = 0,
    String? type,
    String? temperature,
    String? search,
  }) async {
    List<Map<String, dynamic>> rows;

    if (search != null && search.trim().isNotEmpty) {
      final ftsQuery = _buildFtsQuery(search);
      if (ftsQuery.isEmpty) return [];
      rows = await db.searchEntitiesBrowse(ftsQuery, limit);
    } else if (type != null) {
      rows = await db.listEntitiesByType(type, limit, offset);
    } else if (temperature != null) {
      rows = await db.listEntitiesByTemperature(temperature, limit, offset);
    } else {
      rows = await db.listEntitiesPaged(limit, offset);
    }

    return rows.map((r) {
      final entity = KnowledgeEntity.fromJson(r);
      final factCount = (r['fact_count'] as int?) ?? 0;
      return (entity, factCount);
    }).toList();
  }

  /// Get full detail for one entity.
  Future<KnowledgeEntityDetail?> getEntityDetail(int entityId) async {
    final entityRow = await db.getEntityById(entityId).getSingleOrNull();
    if (entityRow == null) return null;

    final entity = KnowledgeEntity(
      id: entityRow.id,
      name: entityRow.name,
      entityType: EntityType.fromString(entityRow.entityType),
      summary: entityRow.summary,
      createdAt: entityRow.createdAt,
      lastAccessed: entityRow.lastAccessed,
      accessCount: entityRow.accessCount,
      temperature: Temperature.fromString(entityRow.temperature),
      baseScore: entityRow.baseScore,
      isActive: entityRow.isActive == 1,
    );

    // Facts
    final factRows = await db.getEntityFacts(entityId).get();
    final facts = factRows
        .map((f) => KnowledgeFact(
              id: f.id,
              entityId: f.entityId,
              key: f.factKey,
              value: f.factValue,
              valueType: f.valueType,
              validAt: f.validAt,
              invalidAt: f.invalidAt,
              ingestedAt: f.ingestedAt,
              expiredAt: f.expiredAt,
              confidence: f.confidence,
              sourceText: f.sourceText,
            ))
        .toList();

    // Relations with names
    final relRows = await db.getEntityRelationsWithNames(entityId);
    final relations = relRows
        .map((r) => KnowledgeRelationWithNames(
              relation: KnowledgeRelation.fromJson(r),
              sourceName: r['source_name'] as String? ?? '',
              targetName: r['target_name'] as String? ?? '',
            ))
        .toList();

    // Aliases
    final aliasRows = await db.getEntityAliases(entityId);
    final aliases = aliasRows.map((a) => KnowledgeAlias.fromJson(a)).toList();

    // Decay score
    final decayScore = MemoryDecay.retention(
      lastAccessedEpoch: entity.lastAccessed ?? 0,
      accessCount: entity.accessCount,
    );

    return KnowledgeEntityDetail(
      entity: entity,
      facts: facts,
      relations: relations,
      aliases: aliases,
      decayScore: decayScore,
    );
  }

  /// Soft-delete an entity.
  Future<void> deactivateEntity(int entityId) async {
    await db.deactivateEntity(entityId);
  }

  /// Count entities with optional filters.
  Future<int> countFilteredEntities({String? type, String? temperature}) async {
    return await db.countEntitiesFiltered(type: type, temp: temperature);
  }

  /// List entities with combined AND filters (type + temperature + date range).
  Future<List<(KnowledgeEntity, int)>> listEntitiesFiltered({
    int limit = 50,
    int offset = 0,
    String? type,
    String? temperature,
    String? search,
    int? createdAfterEpoch,
    int? createdBeforeEpoch,
    int? accessedAfterEpoch,
  }) async {
    List<Map<String, dynamic>> rows;

    if (search != null && search.trim().isNotEmpty) {
      final ftsQuery = _buildFtsQuery(search);
      if (ftsQuery.isEmpty) return [];
      rows = await db.searchEntitiesBrowse(ftsQuery, limit);
    } else {
      rows = await db.listEntitiesFiltered(
        type: type,
        temperature: temperature,
        createdAfterEpoch: createdAfterEpoch,
        createdBeforeEpoch: createdBeforeEpoch,
        accessedAfterEpoch: accessedAfterEpoch,
        limit: limit,
        offset: offset,
      );
    }

    return rows.map((r) {
      final entity = KnowledgeEntity.fromJson(r);
      final factCount = (r['fact_count'] as int?) ?? 0;
      return (entity, factCount);
    }).toList();
  }

  /// Get KB statistics: total entities, facts, relations, counts by type/temperature.
  Future<Map<String, dynamic>> getKbStats() async {
    final totalEntities = await db.countEntitiesFiltered();
    final totalFacts = await db.countActiveFacts();
    final totalRelations = await db.countActiveRelations();
    final byType = await db.countByType();
    final byTemp = await db.countByTemperature();

    return {
      'total_entities': totalEntities,
      'total_facts': totalFacts,
      'total_relations': totalRelations,
      'by_type': {for (final r in byType) r['entity_type'] as String: r['cnt'] as int},
      'by_temperature': {for (final r in byTemp) r['temperature'] as String: r['cnt'] as int},
    };
  }

  /// Resolve an entity by exact name match (case-insensitive).
  Future<KnowledgeEntityDetail?> resolveEntityByName(String name) async {
    final ftsQuery = '"${name.replaceAll('"', '')}"';
    final rows = await db.searchEntitiesBrowse(ftsQuery, 5);
    final nameLower = name.toLowerCase();
    for (final r in rows) {
      final entityName = (r['name'] as String?) ?? '';
      if (entityName.toLowerCase() == nameLower) {
        final entity = KnowledgeEntity.fromJson(r);
        if (entity.id != null) return await getEntityDetail(entity.id!);
      }
    }
    // Fallback: return first FTS match if any
    if (rows.isNotEmpty) {
      final entity = KnowledgeEntity.fromJson(rows.first);
      if (entity.id != null) return await getEntityDetail(entity.id!);
    }
    return null;
  }

  /// Delete all knowledge graph data.
  Future<void> deleteAll() async {
    await db.deleteAllData();
  }

  /// Build an FTS5 MATCH query from natural language text.
  ///
  /// Splits on non-letter/non-digit boundaries (matching FTS5 unicode61
  /// tokenizer behavior), removes stopwords, and deduplicates.
  static String _buildFtsQuery(String text) {
    final tokens = text
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .map((t) => t.toLowerCase())
        .where((t) => t.length > 1 && !_stopwords.contains(t))
        .toSet() // deduplicate
        .toList();
    if (tokens.isEmpty) return '';
    // Use OR for broader matching
    return tokens.map((t) => '"$t"').join(' OR ');
  }

  /// Common FR/EN stopwords to filter from FTS queries.
  static const _stopwords = <String>{
    // English
    'the', 'is', 'at', 'in', 'on', 'of', 'to', 'and', 'or', 'an', 'it',
    'do', 'my', 'me', 'am', 'are', 'was', 'be', 'has', 'had', 'have',
    'this', 'that', 'what', 'where', 'when', 'how', 'who', 'which',
    'with', 'for', 'not', 'but', 'can', 'will', 'from',
    // French
    'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'au', 'aux',
    'et', 'ou', 'en', 'est', 'ce', 'que', 'qui', 'ne', 'pas',
    'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils', 'elles',
    'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'son', 'sa', 'ses',
    'se', 'si', 'sur', 'par', 'pour', 'dans', 'avec', 'sans',
    // German (excluding duplicates with FR/EN: du, was)
    'der', 'die', 'das', 'ein', 'eine', 'ist', 'und', 'ich',
    'er', 'sie', 'wir', 'ihr', 'es', 'zu', 'von', 'mit', 'auf',
    'den', 'dem', 'nicht', 'bin', 'hat', 'wie', 'wo',
    // Spanish (excluding duplicates with DE: es)
    'el', 'los', 'las', 'yo', 'mi', 'su', 'nos',
    'por', 'con', 'sin', 'pero', 'como', 'donde',
    // Italian (excluding duplicates with FR/ES: il, tu, con)
    'lo', 'gli', 'io', 'lui', 'lei', 'noi', 'voi',
    'non', 'che', 'chi', 'per', 'tra', 'fra', 'come', 'dove',
  };
}
