import 'package:drift/drift.dart';

import '../../config/log_entry.dart';
import '../../providers/embedding_provider.dart';
import '../../providers/llm_response.dart';
import '../../services/app_logger.dart';
import '../algorithms/embedding_codec.dart';
import '../database/knowledge_graph_db.dart';
import 'entity_extractor.dart';
import 'entity_resolver.dart';

/// Orchestrates the full ingestion flow:
/// LLM extraction → entity resolution → bi-temporal storage → embedding.
class IngestionPipeline {
  final EntityExtractor extractor;
  final EntityResolver resolver;
  final KnowledgeGraphDB db;

  /// Optional embedding provider for computing entity vectors.
  final EmbeddingProvider? embeddingProvider;

  /// Model name for embedding API calls.
  final String embeddingModel;

  /// Output dimensions for embeddings.
  final int embeddingDimensions;

  IngestionPipeline({
    required this.extractor,
    required this.resolver,
    required this.db,
    this.embeddingProvider,
    this.embeddingModel = '',
    this.embeddingDimensions = 768,
  });

  /// Extract and store knowledge from a conversation turn.
  ///
  /// Returns the number of new facts/relations stored.
  Future<int> extractAndStore({
    required String userMessage,
    required String assistantResponse,
    String? sessionKey,
  }) async {
    // 1. Extract entities, relations, facts via LLM
    final result = await extractor.extract(
      userMessage: userMessage,
      assistantResponse: assistantResponse,
      sessionKey: sessionKey,
    );

    if (result.isEmpty) return 0;

    var storedCount = 0;
    final entityIds = <String, int>{};

    try {
      await db.transaction(() async {
        // 2. Resolve entities (creates new ones if needed)
        for (final e in result.entities) {
          final id = await resolver.resolve(
            name: e.name,
            entityType: e.type,
            summary: e.summary,
          );
          entityIds[e.name.toLowerCase()] = id;
        }

        // 3. Store relations
        for (final r in result.relations) {
          // Resolve source and target entities
          final sourceId = entityIds[r.source.toLowerCase()] ??
              await resolver.resolve(name: r.source);
          final targetId = entityIds[r.target.toLowerCase()] ??
              await resolver.resolve(name: r.target);

          // Upsert: check if this exact triplet already exists
          try {
            await db.into(db.relations).insert(
                  RelationsCompanion.insert(
                    sourceId: sourceId,
                    targetId: targetId,
                    predicate: r.predicate,
                    confidence: Value(r.confidence),
                    sourceText: Value('${r.source} ${r.predicate} ${r.target}'),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            storedCount++;
          } catch (_) {
            // Unique constraint violation — relation already exists
          }
        }

        // 4. Store facts bi-temporally
        for (final f in result.facts) {
          final entityId = entityIds[f.entity.toLowerCase()] ??
              await resolver.resolve(name: f.entity);

          await db.updateFactBiTemporal(
            entityId: entityId,
            key: f.key,
            newValue: f.value,
            valueType: f.type,
          );
          storedCount++;
        }
      });

      AppLogger.instance.info(
        LogSource.agent,
        'KG ingestion: ${result.entities.length} entities, '
        '${result.relations.length} relations, '
        '${result.facts.length} facts → $storedCount stored',
      );

      // 5. Compute and store entity embeddings (outside transaction)
      if (embeddingProvider != null && entityIds.isNotEmpty) {
        await _embedEntities(result.entities, entityIds);
      }
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'KG ingestion error: $e',
      );
    }

    return storedCount;
  }

  /// Build the canonical embedding text for an entity:
  /// "Name (TYPE): summary" (type omitted for CONCEPT, summary if present).
  ///
  /// Single home for the text format — the versioned re-embed backfill
  /// (EmbeddingBackfillService) MUST reconstruct exactly the same text, or
  /// backfilled vectors would silently live in a differently-shaped space.
  static String buildEmbeddingText({
    required String name,
    required String entityType,
    String? summary,
  }) {
    final parts = [name];
    if (entityType != 'CONCEPT') parts.add('($entityType)');
    if (summary != null && summary.isNotEmpty) parts.add(': $summary');
    return parts.join(' ');
  }

  /// Compute embeddings for resolved entities and store in DB.
  Future<void> _embedEntities(
    List<ExtractedEntity> entities,
    Map<String, int> entityIds,
  ) async {
    try {
      final texts = entities
          .map((e) => buildEmbeddingText(
                name: e.name,
                entityType: e.type,
                summary: e.summary,
              ))
          .toList();

      final result = await embeddingProvider!.embed(
        texts: texts,
        model: embeddingModel,
        dimensions: embeddingDimensions,
        taskType: 'RETRIEVAL_DOCUMENT',
      );

      // Store each embedding as a Float32 BLOB stamped with its space
      // (provider id + actual vector length — U3 provenance).
      for (var i = 0; i < entities.length; i++) {
        final entityId = entityIds[entities[i].name.toLowerCase()];
        if (entityId == null || i >= result.embeddings.length) continue;

        final vector = result.embeddings[i];
        await db.updateEntityEmbedding(
          entityId,
          EmbeddingCodec.encode(vector),
          model: embeddingProvider!.providerId,
          dim: vector.length,
        );
      }

      AppLogger.instance.info(
        LogSource.agent,
        'KG embeddings: ${entities.length} entities embedded '
        '(${embeddingDimensions}d, $embeddingModel)',
      );
    } catch (e) {
      // Embedding failure should not break ingestion
      AppLogger.instance.warning(
        LogSource.agent,
        'KG embedding failed (ingestion continues): $e',
      );
    }
  }

  /// Extract (userMessage, assistantResponse) pairs from session messages.
  /// Skips tool/system messages and assistant messages with only tool calls.
  /// Matches the pairing logic used by [AgentLoop._extractAsync].
  static List<(String, String)> extractPairs(List<Message> messages) {
    final pairs = <(String, String)>[];
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role != 'user' || messages[i].content.isEmpty) continue;
      final userMsg = messages[i].content;
      // Find next assistant message with actual content (not just tool calls)
      for (var j = i + 1; j < messages.length; j++) {
        if (messages[j].role == 'user') break; // next user turn, no match
        if (messages[j].role == 'assistant' &&
            messages[j].content.isNotEmpty &&
            (messages[j].toolCalls == null || messages[j].toolCalls!.isEmpty)) {
          pairs.add((userMsg, messages[j].content));
          break;
        }
      }
    }
    return pairs;
  }
}
