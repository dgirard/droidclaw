import 'dart:convert';

import '../config/config_storage.dart';
import '../knowledge/database/knowledge_graph_db.dart';
import '../knowledge/services/kb_maintenance_service.dart';
import 'tool.dart';

/// Tool for KB entity deduplication and cleanup ("dreaming").
///
/// Operations:
/// - **audit**: Identifies duplicate entity candidates using token blocking,
///   deterministic scoring, and LLM semantic verification.
/// - **merge**: Executes approved merges of duplicate entity pairs.
/// - **cleanup**: LLM-based full KB cleanup — sends entire entity/relation
///   tables to LLM for global analysis, then executes proposed operations.
///
/// The metaphor: the KB "dreams" — consolidating and cleaning its memories.
class DreamTool extends Tool {
  final KbMaintenanceService _service;
  final ConfigStorage _configStorage;

  DreamTool({
    required KbMaintenanceService service,
    required ConfigStorage configStorage,
  })  : _service = service,
        _configStorage = configStorage;

  @override
  String get name => 'dream';

  @override
  String get description =>
      'Analyze and clean the knowledge base. '
      'Operations: "audit" identifies duplicates with scoring, "merge" executes approved merges, '
      '"cleanup" sends the full KB to LLM for global analysis (garbage, duplicates, stale relations). '
      'Like a brain during sleep, the KB consolidates its memories.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['audit', 'merge', 'audit_facts', 'merge_facts', 'cleanup', 'cleanup_exec'],
            'description':
                'audit: analyze KB for duplicate entities. '
                'merge: execute approved entity merges. '
                'audit_facts: find duplicate facts within same entity. '
                'merge_facts: remove approved duplicate facts. '
                'cleanup: LLM-based full KB cleanup (auto-executes high-confidence ops, returns low-confidence for review). '
                'cleanup_exec: execute user-approved cleanup operations from a previous cleanup result.',
          },
          'full_scan': {
            'type': 'boolean',
            'description':
                'If true, compare all entities. If false (default), '
                'only compare entities added since last dream.',
          },
          'pairs': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'primary_id': {'type': 'integer'},
                'secondary_id': {'type': 'integer'},
              },
              'required': ['primary_id', 'secondary_id'],
            },
            'description': 'Pairs to merge (merge operation only).',
          },
          'fact_ids': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'Fact IDs to remove (merge_facts operation only).',
          },
          'dry_run': {
            'type': 'boolean',
            'description':
                'If true, only propose cleanup operations without executing (cleanup only).',
          },
          'approved_ops': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'type': {'type': 'string'},
                'entity_id': {'type': 'integer'},
                'primary_id': {'type': 'integer'},
                'secondary_id': {'type': 'integer'},
                'relation_id': {'type': 'integer'},
              },
              'required': ['type'],
            },
            'description':
                'Operations approved by the user for execution (cleanup_exec only). '
                'Each must have "type" and the relevant IDs from the cleanup proposal.',
          },
        },
        'required': ['operation'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) {
      return ToolResult.error('Missing required parameter: operation');
    }

    try {
      switch (operation) {
        case 'audit':
          return await _audit(arguments);
        case 'merge':
          return await _merge(arguments);
        case 'audit_facts':
          return await _auditFacts(arguments);
        case 'merge_facts':
          return await _mergeFacts(arguments);
        case 'cleanup':
          return await _cleanup(arguments);
        case 'cleanup_exec':
          return await _cleanupExec(arguments);
        default:
          return ToolResult.error(
              'Unknown operation "$operation". Use: audit, merge, audit_facts, merge_facts, cleanup, cleanup_exec.');
      }
    } catch (e) {
      return ToolResult.error('dream error: ${e.runtimeType}');
    }
  }

  Future<ToolResult> _audit(Map<String, dynamic> args) async {
    final fullScan = args['full_scan'] as bool? ?? false;
    final lastDreamAt = _configStorage.lastDreamAt;

    // Find candidates (token blocking + deterministic scoring)
    final candidates = await _service.findCandidates(
      maxPairs: 40,
      fullScan: fullScan,
      lastDreamAt: lastDreamAt,
    );

    if (candidates.isEmpty) {
      // Don't update lastDreamAt when no candidates found —
      // avoids marking the KB as "clean" before a full scan has run.
      final msg = fullScan
          ? 'No potential duplicates found in the entire KB.'
          : lastDreamAt != null
              ? 'No potential duplicates found among entities added since last dream. '
                'Use full_scan: true for a complete analysis.'
              : 'No potential duplicates found.';
      return ToolResult.dual(
        forLLM: '{"pairs":[],"count":0}',
        forUser: msg,
      );
    }

    // Verify with LLM
    final scoredPairs = await _service.verifyWithLLM(candidates);

    // Update last dream timestamp only after successful audit
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _configStorage.setLastDreamAt(now);

    // Classify by level
    final level1 = scoredPairs.where((p) => p.level == 1).toList();
    final level2 = scoredPairs.where((p) => p.level == 2).toList();
    final level3 = scoredPairs.where((p) => p.level == 3).toList();

    // forLLM: compact JSON with pair IDs, names, scores
    final forLLM = jsonEncode({
      'pairs': scoredPairs.map((p) => {
            'primary_id': p.primaryId,
            'secondary_id': p.secondaryId,
            'primary_name': p.primaryName,
            'secondary_name': p.secondaryName,
            'score': (p.score * 100).round(),
            'level': p.level,
            'justification': p.justification,
          }).toList(),
      'count': scoredPairs.length,
      'level1_count': level1.length,
      'level2_count': level2.length,
      'level3_count': level3.length,
    });

    // forUser: markdown tables
    final buf = StringBuffer();
    buf.writeln('KB Deduplication Audit');
    buf.writeln('${scoredPairs.length} potential duplicate pairs found.\n');

    if (level1.isNotEmpty) {
      buf.writeln('Level 1 - Evident merges (>85%):');
      _writeTable(buf, level1);
    }
    if (level2.isNotEmpty) {
      buf.writeln('Level 2 - Needs approval (50%-85%):');
      _writeTable(buf, level2);
    }
    if (level3.isNotEmpty) {
      buf.writeln('Level 3 - False positives (<50%):');
      _writeTable(buf, level3);
    }

    if (!fullScan && lastDreamAt != null) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastDreamAt * 1000);
      buf.writeln(
          'Analyzed entities added since ${lastDate.toIso8601String().substring(0, 10)}. '
          'Use full_scan: true for a complete analysis.');
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  Future<ToolResult> _merge(Map<String, dynamic> args) async {
    final pairsRaw = args['pairs'] as List?;
    if (pairsRaw == null || pairsRaw.isEmpty) {
      return ToolResult.error(
          'merge operation requires "pairs" array with primary_id and secondary_id.');
    }

    final results = <MergeResult>[];
    final errors = <String>[];

    for (final pair in pairsRaw) {
      final primaryId = (pair['primary_id'] as num?)?.toInt();
      final secondaryId = (pair['secondary_id'] as num?)?.toInt();
      if (primaryId == null || secondaryId == null) {
        errors.add('Invalid pair: missing primary_id or secondary_id');
        continue;
      }

      try {
        final result = await _service.merge(primaryId, secondaryId);
        results.add(result);
      } catch (e) {
        errors.add('Failed to merge #$primaryId <- #$secondaryId: $e');
      }
    }

    // forLLM
    final forLLM = jsonEncode({
      'merged': results.map((r) => {
            'primary_id': r.primaryId,
            'secondary_id': r.secondaryId,
            'primary_name': r.primaryName,
            'secondary_name': r.secondaryName,
            'relations_transferred': r.relationsTransferred,
            'facts_transferred': r.factsTransferred,
            'aliases_transferred': r.aliasesTransferred,
          }).toList(),
      'merge_count': results.length,
      'error_count': errors.length,
    });

    // forUser
    final buf = StringBuffer();
    buf.writeln('Merge Results');
    if (results.isNotEmpty) {
      buf.writeln('${results.length} pair(s) merged:');
      for (final r in results) {
        buf.writeln(
            '  "${r.secondaryName}" (#${r.secondaryId}) -> "${r.primaryName}" (#${r.primaryId})');
      }
    }
    if (errors.isNotEmpty) {
      buf.writeln('\n${errors.length} error(s):');
      for (final e in errors) {
        buf.writeln('  $e');
      }
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  Future<ToolResult> _auditFacts(Map<String, dynamic> args) async {
    final result = await _service.findDuplicateFacts();

    // Always call verifyFactsWithLLM — even with no deterministic candidates,
    // fact bundles may contain entities needing cross-key LLM detection
    // (e.g. vélo/bicyclette, souliers/chaussures on same entity).
    final scoredPairs = await _service.verifyFactsWithLLM(
      result.candidates,
      factBundles: result.bundles,
    );

    if (scoredPairs.isEmpty) {
      return ToolResult.dual(
        forLLM: '{"fact_pairs":[],"count":0}',
        forUser: 'No duplicate facts found within entities.',
      );
    }

    // forLLM
    final forLLM = jsonEncode({
      'fact_pairs': scoredPairs.map((p) => {
            'entity_id': p.entityId,
            'entity_name': p.entityName,
            'fact_id_keep': p.factIdKeep,
            'fact_id_remove': p.factIdRemove,
            'fact_key': p.factKey,
            'value_keep': p.valueKeep,
            'value_remove': p.valueRemove,
            'score': (p.score * 100).round(),
            'justification': p.justification,
          }).toList(),
      'count': scoredPairs.length,
    });

    // forUser
    final buf = StringBuffer();
    buf.writeln('Duplicate Facts Audit');
    buf.writeln('${scoredPairs.length} duplicate fact(s) found:\n');
    for (final p in scoredPairs) {
      buf.writeln(
          '  "${p.entityName}": "${p.valueRemove}" → keep "${p.valueKeep}" '
          '(${(p.score * 100).round()}%) ${p.justification}');
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  Future<ToolResult> _mergeFacts(Map<String, dynamic> args) async {
    final factIds = (args['fact_ids'] as List?)
        ?.map((e) => (e as num).toInt())
        .toList();
    if (factIds == null || factIds.isEmpty) {
      return ToolResult.error(
          'merge_facts requires "fact_ids" array of fact IDs to remove.');
    }

    var removed = 0;
    final errors = <String>[];
    for (final id in factIds) {
      try {
        await _service.expireFact(id);
        removed++;
      } catch (e) {
        errors.add('Failed to remove fact #$id: $e');
      }
    }

    final forLLM = jsonEncode({
      'removed_count': removed,
      'error_count': errors.length,
    });

    final buf = StringBuffer();
    buf.writeln('$removed fact(s) removed.');
    if (errors.isNotEmpty) {
      buf.writeln('${errors.length} error(s):');
      for (final e in errors) {
        buf.writeln('  $e');
      }
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  /// Confidence threshold for auto-execution. Operations at or above this
  /// level are executed immediately; below this are returned for user review.
  static const _autoExecThreshold = 90;

  Future<ToolResult> _cleanup(Map<String, dynamic> args) async {
    final dryRun = args['dry_run'] as bool? ?? false;

    // Build KB snapshot
    final snapshot = await _service.buildKBSnapshot();

    // Send to LLM for analysis
    final operations = await _service.proposeCleanup(snapshot);

    if (operations.isEmpty) {
      return ToolResult.dual(
        forLLM: '{"operations":[],"auto_executed":{"count":0},"pending_review":{}}',
        forUser: 'LLM analysis found no cleanup operations needed.',
      );
    }

    if (dryRun) {
      // Dry run: show all operations grouped by confidence, execute nothing
      final entityNames = await _service.loadEntityNames(operations);
      final deleteRels = operations.whereType<CleanupDeleteRelation>().toList();
      final relationDescs = await _service.loadRelationDescs(
          deleteRels.map((r) => r.relationId).toList());

      final forLLM = jsonEncode({
        'operations': _opsToJson(operations),
        'count': operations.length,
        'executed': false,
      });

      final buf = StringBuffer();
      buf.writeln('KB Cleanup Proposals (dry run — not executed)');
      buf.writeln('${operations.length} operations proposed:');
      _writeCleanupGrouped(buf, operations, entityNames, relationDescs);

      return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
    }

    // Two-phase execution: auto-execute high confidence, return rest for review
    final autoOps = <CleanupOperation>[];
    final pendingOps = <CleanupOperation>[];
    for (final op in operations) {
      if (op.confidence == null || op.confidence! >= _autoExecThreshold) {
        autoOps.add(op);
      } else {
        pendingOps.add(op);
      }
    }

    // Phase 1: Execute high-confidence operations
    CleanupResult? autoResult;
    if (autoOps.isNotEmpty) {
      autoResult = await _service.executeCleanupOps(autoOps);
    }

    // Phase 2: Build pending review grouped by confidence level
    final probable = pendingOps.where((o) => o.confidence != null && o.confidence! >= 60).toList();
    final uncertain = pendingOps.where((o) => o.confidence != null && o.confidence! >= 30 && o.confidence! < 60).toList();
    final speculative = pendingOps.where((o) => o.confidence != null && o.confidence! < 30).toList();

    // Load entity names/relation descs only if there are pending ops to display
    Map<int, String> entityNames = {};
    Map<int, String> relationDescs = {};
    if (pendingOps.isNotEmpty) {
      entityNames = await _service.loadEntityNames(pendingOps);
      final pendingRelIds = pendingOps
          .whereType<CleanupDeleteRelation>()
          .map((r) => r.relationId)
          .toList();
      relationDescs = await _service.loadRelationDescs(pendingRelIds);
    }

    // Build forLLM JSON
    final forLLM = jsonEncode({
      'auto_executed': {
        'count': autoResult?.totalExecuted ?? 0,
        'operations': _opsToJson(autoOps),
        if (autoResult != null) 'errors': autoResult.errors,
      },
      'pending_review': {
        'probable': _opsToJson(probable),
        'uncertain': _opsToJson(uncertain),
        'speculative': _opsToJson(speculative),
        'count': pendingOps.length,
      },
    });

    // Build forUser
    final buf = StringBuffer();
    if (autoResult != null && autoResult.totalExecuted > 0) {
      buf.writeln('Auto-executed (confidence >= $_autoExecThreshold%): '
          '${autoResult.totalExecuted} operations');
      for (final op in autoResult.executedOps) {
        buf.writeln('  ✓ $op');
      }
      if (autoResult.errors.isNotEmpty) {
        for (final e in autoResult.errors) {
          buf.writeln('  ✗ $e');
        }
      }
    } else if (autoOps.isEmpty) {
      buf.writeln('No operations with confidence >= $_autoExecThreshold%.');
    }

    if (pendingOps.isNotEmpty) {
      buf.writeln();
      _writePendingGroup(buf, 'Probable (60-89%)', probable, entityNames, relationDescs);
      _writePendingGroup(buf, 'Uncertain (30-59%)', uncertain, entityNames, relationDescs);
      _writePendingGroup(buf, 'Speculative (<30%)', speculative, entityNames, relationDescs);
      buf.writeln('\nUse cleanup_exec with approved_ops to execute the ones you approve.');
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  Future<ToolResult> _cleanupExec(Map<String, dynamic> args) async {
    final approvedRaw = args['approved_ops'] as List?;
    if (approvedRaw == null || approvedRaw.isEmpty) {
      return ToolResult.error(
          'cleanup_exec requires "approved_ops" array with operations to execute.');
    }

    // Reconstruct CleanupOperation instances from approved_ops JSON
    final ops = <CleanupOperation>[];
    for (final raw in approvedRaw) {
      final map = raw as Map<String, dynamic>;
      final type = map['type'] as String?;
      final reason = map['reason'] as String? ?? '';
      switch (type) {
        case 'delete':
          final entityId = (map['entity_id'] as num?)?.toInt();
          if (entityId != null) {
            ops.add(CleanupDelete(entityId: entityId, reason: reason));
          }
        case 'merge':
          final primaryId = (map['primary_id'] as num?)?.toInt();
          final secondaryId = (map['secondary_id'] as num?)?.toInt();
          if (primaryId != null && secondaryId != null) {
            ops.add(CleanupMerge(
                primaryId: primaryId, secondaryId: secondaryId, reason: reason));
          }
        case 'delete_relation':
          final relationId = (map['relation_id'] as num?)?.toInt();
          if (relationId != null) {
            ops.add(CleanupDeleteRelation(relationId: relationId, reason: reason));
          }
      }
    }

    if (ops.isEmpty) {
      return ToolResult.error('No valid operations found in approved_ops.');
    }

    final result = await _service.executeCleanupOps(ops);

    final forLLM = jsonEncode({
      'executed': true,
      'merge_count': result.mergeCount,
      'delete_count': result.deleteCount,
      'delete_relation_count': result.deleteRelationCount,
      'error_count': result.errors.length,
      'errors': result.errors,
      'executed_ops': result.executedOps,
    });

    final buf = StringBuffer();
    buf.writeln('Cleanup exec — ${result.totalExecuted} operations executed');
    for (final op in result.executedOps) {
      buf.writeln('  ✓ $op');
    }
    if (result.errors.isNotEmpty) {
      buf.writeln('\n${result.errors.length} error(s):');
      for (final e in result.errors) {
        buf.writeln('  ✗ $e');
      }
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  /// Write operations grouped by confidence level (for dry_run display).
  void _writeCleanupGrouped(
    StringBuffer buf,
    List<CleanupOperation> ops,
    Map<int, String> entityNames,
    Map<int, String> relationDescs,
  ) {
    final certain = ops.where((o) => o.confidence != null && o.confidence! >= _autoExecThreshold).toList();
    final probable = ops.where((o) => o.confidence != null && o.confidence! >= 60 && o.confidence! < _autoExecThreshold).toList();
    final uncertain = ops.where((o) => o.confidence != null && o.confidence! >= 30 && o.confidence! < 60).toList();
    final speculative = ops.where((o) => o.confidence != null && o.confidence! < 30).toList();
    final noConf = ops.where((o) => o.confidence == null).toList();

    if (certain.isNotEmpty) {
      buf.writeln('\nCertain (>= $_autoExecThreshold%) — would auto-execute:');
      _writeOpsList(buf, certain, entityNames, relationDescs);
    }
    if (probable.isNotEmpty) {
      buf.writeln('\nProbable (60-89%) — needs approval:');
      _writeOpsList(buf, probable, entityNames, relationDescs);
    }
    if (uncertain.isNotEmpty) {
      buf.writeln('\nUncertain (30-59%) — needs review:');
      _writeOpsList(buf, uncertain, entityNames, relationDescs);
    }
    if (speculative.isNotEmpty) {
      buf.writeln('\nSpeculative (<30%) — low evidence:');
      _writeOpsList(buf, speculative, entityNames, relationDescs);
    }
    if (noConf.isNotEmpty) {
      buf.writeln('\nNo confidence provided — would auto-execute:');
      _writeOpsList(buf, noConf, entityNames, relationDescs);
    }
  }

  /// Write a group of pending operations for user review.
  void _writePendingGroup(
    StringBuffer buf,
    String label,
    List<CleanupOperation> ops,
    Map<int, String> entityNames,
    Map<int, String> relationDescs,
  ) {
    if (ops.isEmpty) return;
    buf.writeln('Pending review — $label: ${ops.length} operation(s)');
    _writeOpsList(buf, ops, entityNames, relationDescs);
  }

  /// Write a list of operations with entity names and confidence.
  void _writeOpsList(
    StringBuffer buf,
    List<CleanupOperation> ops,
    Map<int, String> entityNames,
    Map<int, String> relationDescs,
  ) {
    for (final op in ops) {
      final confStr = op.confidence != null ? ' (${op.confidence}%)' : '';
      switch (op) {
        case CleanupMerge(:final primaryId, :final secondaryId, :final reason):
          final secName = entityNames[secondaryId] ?? '?';
          final priName = entityNames[primaryId] ?? '?';
          buf.writeln('  "$secName" (#$secondaryId) → "$priName" (#$primaryId)$confStr — $reason');
        case CleanupDelete(:final entityId, :final reason):
          final name = entityNames[entityId] ?? '?';
          buf.writeln('  "$name" (#$entityId)$confStr — $reason');
        case CleanupDeleteRelation(:final relationId, :final reason):
          final desc = relationDescs[relationId] ?? 'relation #$relationId';
          buf.writeln('  $desc$confStr — $reason');
      }
    }
  }

  List<Map<String, dynamic>> _opsToJson(List<CleanupOperation> ops) {
    return ops.map((op) {
      final base = <String, dynamic>{};
      if (op.confidence != null) base['confidence'] = op.confidence;
      return switch (op) {
        CleanupMerge(:final primaryId, :final secondaryId, :final reason) => {
          'type': 'merge',
          'primary_id': primaryId,
          'secondary_id': secondaryId,
          'reason': reason,
          ...base,
        },
        CleanupDelete(:final entityId, :final reason) => {
          'type': 'delete',
          'entity_id': entityId,
          'reason': reason,
          ...base,
        },
        CleanupDeleteRelation(:final relationId, :final reason) => {
          'type': 'delete_relation',
          'relation_id': relationId,
          'reason': reason,
          ...base,
        },
      };
    }).toList();
  }

  void _writeTable(StringBuffer buf, List<ScoredPair> pairs) {
    for (final p in pairs) {
      buf.writeln(
          '  #${p.secondaryId} "${p.secondaryName}" -> '
          '#${p.primaryId} "${p.primaryName}" '
          '(${(p.score * 100).round()}%) ${p.justification}');
    }
    buf.writeln();
  }
}
