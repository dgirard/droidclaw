import '../../../config/log_entry.dart';
import '../../../providers/llm_provider.dart';
import '../../../providers/llm_response.dart';
import '../../../services/app_logger.dart';
import '../../../../shared/constants.dart';
import '../../database/knowledge_graph_db.dart';
import '../../models/dedup_models.dart';
import '../llm_json_parser.dart';

import 'package:drift/drift.dart';

/// LLM-based full-KB cleanup: snapshot chunking, proposal, and
/// confidence-gated execution.
///
/// Extracted from [KbMaintenanceService] (U17); the chunked-snapshot flow
/// is the U15 implementation moved intact.
class KbCleanupService {
  final KnowledgeGraphDB _db;
  final LLMProvider _llmProvider;
  final String _model;

  /// The language for LLM prompts (e.g. 'en', 'fr'). Null = English.
  final String? kbLanguage;

  KbCleanupService({
    required KnowledgeGraphDB db,
    required LLMProvider llmProvider,
    required String model,
    this.kbLanguage,
  })  : _db = db,
        _llmProvider = llmProvider,
        _model = model;

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
  /// Malformed JSON throws (propagated to the caller, as before U17).
  static List<CleanupOperation> parseCleanupResponse(String content) {
    final data = LlmJsonParser.decodeObject(content);
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

  /// Remove a duplicate fact by soft-deleting it (set expired_at).
  Future<void> expireFact(int factId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement(
      'UPDATE facts SET expired_at = ? WHERE id = ?',
      [now, factId],
    );
  }

  /// Language-code → English name map for cleanup prompts.
  ///
  /// Moved verbatim from `kb_maintenance_service.dart` in U17. NOTE for U19
  /// (language consolidation): this duplicates `KnowledgeConfig.languageName`
  /// with a divergent default (returns the raw code instead of English) —
  /// U19 should consolidate to the single source. New location:
  /// `lib/core/knowledge/services/dedup/cleanup_service.dart`.
  static String _languageName(String code) {
    const names = {
      'fr': 'French',
      'es': 'Spanish',
      'de': 'German',
      'it': 'Italian',
    };
    return names[code] ?? code;
  }
}
