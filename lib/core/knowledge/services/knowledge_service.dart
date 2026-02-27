import 'dart:typed_data';

import '../../config/log_entry.dart';
import '../../providers/embedding_provider.dart';
import '../../services/app_logger.dart';
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

  final _spreading = const SpreadingActivation();

  KnowledgeService({
    required this.db,
    this.embeddingProvider,
    this.embeddingModel = '',
    this.embeddingDimensions = 768,
  });

  /// Query the knowledge graph for entities relevant to a text query.
  ///
  /// Returns ranked entities with attached facts and relations,
  /// sorted by fused score (descending).
  Future<List<RankedEntity>> queryRelevant(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    // 1. FTS5 BM25 search (3x limit for candidate pool)
    final ftsQuery = _buildFtsQuery(query);
    if (ftsQuery.isEmpty) return [];

    final ftsResults =
        await db.searchEntities(ftsQuery, limit * 3).get();

    // 1b. FTS5 BM25 search on facts (fact_key + fact_value)
    final factResults =
        await db.searchFacts(ftsQuery, limit * 3).get();

    if (ftsResults.isEmpty && factResults.isEmpty) return [];

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

    // 2. Vector similarity search (if embedder is available)
    final vectorScores = <int, double>{};
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
          final entityEmbeddings =
              await db.getActiveEntityEmbeddings(limit: 1000);

          for (final entry in entityEmbeddings) {
            final entVec = Float32List.view(
              Uint8List.fromList(entry.embedding).buffer,
            );
            if (entVec.length != queryVec.length) continue;
            final sim = MemoryClusterer.cosineSimilarity(queryVec, entVec);
            if (sim > 0.5) {
              vectorScores[entry.id] = sim;
            }
          }
        }
      } catch (e) {
        AppLogger.instance.warning(
          LogSource.agent,
          'KG vector search failed, falling back to degraded mode: $e',
        );
      }
    }

    // 3. Union candidates (FTS + vector)
    final candidateIds = <int>{...bm25Scores.keys, ...vectorScores.keys};

    // 4. Load 2-hop subgraph neighbors
    final neighborMap = <int, List<({int entityId, double weight})>>{};
    final expandedIds = Set<int>.from(candidateIds);

    for (final id in candidateIds) {
      final neighbors = await db.findNeighbors(id).get();
      final neighborList = <({int entityId, double weight})>[];
      for (final n in neighbors) {
        neighborList.add((entityId: n.id, weight: n.weight));
        expandedIds.add(n.id);
      }
      neighborMap[id] = neighborList;
    }

    // Load 2nd hop neighbors
    final hop1Ids = expandedIds.difference(candidateIds);
    for (final id in hop1Ids) {
      final neighbors = await db.findNeighbors(id).get();
      neighborMap[id] = neighbors
          .map((n) => (entityId: n.id, weight: n.weight))
          .toList();
      for (final n in neighbors) {
        expandedIds.add(n.id);
      }
    }

    // 5. Spreading activation
    // Seed from top BM25 results (entity + fact combined)
    final seeds = <int, double>{};
    final topCandidates = bm25Scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)); // more negative = better
    for (final entry in topCandidates.take(5)) {
      seeds[entry.key] = 1.0;
    }

    final activationScores = _spreading.activate(
      seeds: seeds,
      neighborFn: (id) => neighborMap[id] ?? [],
    );

    // 6. Compute decay scores for all candidates
    // Use entity FTS results for direct data, load remaining from DB.
    final decayScores = <int, double>{};
    for (final r in ftsResults) {
      final decay = MemoryDecay.retention(
        lastAccessedEpoch: r.lastAccessed,
        accessCount: r.accessCount,
      );
      decayScores[r.id] = decay;
    }
    // Compute decay for candidates not already covered (fact-sourced + expanded)
    for (final id in expandedIds.difference(decayScores.keys.toSet())) {
      final entity = await db.getEntityById(id).getSingleOrNull();
      if (entity != null) {
        decayScores[id] = MemoryDecay.retention(
          lastAccessedEpoch: entity.lastAccessed,
          accessCount: entity.accessCount,
        );
      }
    }

    // 7. Score fusion (full mode if vectorScores available, degraded otherwise)
    final scored = HybridScorer.fuse(
      candidates: expandedIds,
      bm25Scores: bm25Scores,
      vectorScores: vectorScores.isNotEmpty ? vectorScores : null,
      activationScores: activationScores,
      decayScores: decayScores,
    );

    // 8. Take top-K and hydrate with facts + relations
    final topK = scored.take(limit).toList();
    final results = <RankedEntity>[];

    for (final s in topK) {
      // Load entity (skip deactivated as defense-in-depth)
      final entity = await db.getEntityById(s.entityId).getSingleOrNull();
      if (entity == null || entity.isActive == 0) continue;

      // Load active facts
      final facts = await db.getEntityFacts(s.entityId).get();
      final knowledgeFacts = facts
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

      // Load relations (from neighbors already loaded)
      final neighborResults =
          await db.findNeighbors(s.entityId).get();
      final knowledgeRelations = neighborResults
          .map((n) => KnowledgeRelation(
                sourceId: s.entityId,
                targetId: n.id,
                predicate: n.predicate,
                weight: n.weight,
                confidence: n.relConfidence,
              ))
          .toList();

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
        facts: knowledgeFacts,
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

  /// Batch recalculate memory decay for all active entities.
  /// Returns the number of entities whose temperature changed.
  Future<int> recalculateDecay() async {
    final activeEntities = await db.getActiveEntities().get();
    final entities = activeEntities
        .map((e) => (
              id: e.id,
              lastAccessed: e.lastAccessed,
              accessCount: e.accessCount,
              temperature: e.temperature,
            ))
        .toList();

    final updates = MemoryDecay.batchDecay(entities);
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
