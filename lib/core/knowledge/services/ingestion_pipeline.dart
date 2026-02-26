import 'package:drift/drift.dart';

import '../../config/log_entry.dart';
import '../../services/app_logger.dart';
import '../database/knowledge_graph_db.dart';
import 'entity_extractor.dart';
import 'entity_resolver.dart';

/// Orchestrates the full ingestion flow:
/// LLM extraction → entity resolution → bi-temporal storage.
class IngestionPipeline {
  final EntityExtractor extractor;
  final EntityResolver resolver;
  final KnowledgeGraphDB db;

  IngestionPipeline({
    required this.extractor,
    required this.resolver,
    required this.db,
  });

  /// Extract and store knowledge from a conversation turn.
  ///
  /// Returns the number of new facts/relations stored.
  Future<int> extractAndStore({
    required String userMessage,
    required String assistantResponse,
  }) async {
    // 1. Extract entities, relations, facts via LLM
    final result = await extractor.extract(
      userMessage: userMessage,
      assistantResponse: assistantResponse,
    );

    if (result.isEmpty) return 0;

    var storedCount = 0;

    try {
      // 2. Resolve entities (creates new ones if needed)
      final entityIds = <String, int>{};
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

      AppLogger.instance.info(
        LogSource.agent,
        'KG ingestion: ${result.entities.length} entities, '
        '${result.relations.length} relations, '
        '${result.facts.length} facts → $storedCount stored',
      );
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'KG ingestion error: $e',
      );
    }

    return storedCount;
  }
}
