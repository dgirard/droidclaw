import 'dart:convert';

import '../knowledge/models/entity.dart';
import '../knowledge/services/knowledge_service.dart';
import 'tool.dart';

/// Tool for browsing and querying the Knowledge Base.
///
/// Provides list (with filters), detail, and stats operations
/// so the user can explore remembered entities in natural language.
class KnowledgeQueryTool extends Tool {
  final KnowledgeService knowledgeService;

  KnowledgeQueryTool({required this.knowledgeService});

  @override
  String get name => 'kb_query';

  @override
  String get description =>
      'Browse and query the knowledge base. '
      'List all entities (with optional filters by type, temperature, date), '
      'get details on a specific entity, or view KB statistics. '
      'Use this when the user wants to explore what is stored in memory.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['list', 'detail', 'stats'],
            'description':
                'Operation: "list" to browse entities, '
                '"detail" to get full info on one entity, '
                '"stats" for KB overview.',
          },
          'entity_type': {
            'type': 'string',
            'enum': [
              'PERSON', 'PLACE', 'ORG', 'EVENT', 'CONCEPT', 'DATE',
            ],
            'description': 'Filter by entity type (list operation).',
          },
          'temperature': {
            'type': 'string',
            'enum': ['hot', 'warm', 'cool', 'cold'],
            'description': 'Filter by temperature (list operation).',
          },
          'search': {
            'type': 'string',
            'description': 'Full-text search query (list operation).',
          },
          'created_today': {
            'type': 'boolean',
            'description':
                'If true, only entities created today (list operation).',
          },
          'accessed_today': {
            'type': 'boolean',
            'description':
                'If true, only entities accessed today (list operation).',
          },
          'entity_id': {
            'type': 'integer',
            'description': 'Entity ID for detail operation.',
          },
          'entity_name': {
            'type': 'string',
            'description':
                'Entity name for detail operation (resolved via search).',
          },
          'limit': {
            'type': 'integer',
            'description': 'Max results for list (default: 50).',
          },
          'offset': {
            'type': 'integer',
            'description': 'Pagination offset for list (default: 0).',
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
        case 'list':
          return await _list(arguments);
        case 'detail':
          return await _detail(arguments);
        case 'stats':
          return await _stats();
        default:
          return ToolResult.error(
              'Unknown operation "$operation". Use: list, detail, stats.');
      }
    } catch (e) {
      return ToolResult.error('kb_query error: ${e.runtimeType}');
    }
  }

  Future<ToolResult> _list(Map<String, dynamic> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 50;
    final offset = (args['offset'] as num?)?.toInt() ?? 0;
    final type = args['entity_type'] as String?;
    final temperature = args['temperature'] as String?;
    final search = args['search'] as String?;
    final createdToday = args['created_today'] as bool? ?? false;
    final accessedToday = args['accessed_today'] as bool? ?? false;

    // Resolve date filters
    int? createdAfterEpoch;
    int? createdBeforeEpoch;
    int? accessedAfterEpoch;
    if (createdToday) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      createdAfterEpoch = startOfDay.millisecondsSinceEpoch ~/ 1000;
      createdBeforeEpoch =
          startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch ~/
              1000;
    }
    if (accessedToday) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      accessedAfterEpoch = startOfDay.millisecondsSinceEpoch ~/ 1000;
    }

    // Map entity_type label to DB value
    // DB stores UPPERCASE: PERSON, PLACE, ORG, EVENT, CONCEPT, DATE
    final dbType = type; // Already UPPERCASE from enum

    final results = await knowledgeService.listEntitiesFiltered(
      limit: limit,
      offset: offset,
      type: dbType,
      temperature: temperature,
      search: search,
      createdAfterEpoch: createdAfterEpoch,
      createdBeforeEpoch: createdBeforeEpoch,
      accessedAfterEpoch: accessedAfterEpoch,
    );

    if (results.isEmpty) {
      return ToolResult.dual(
        forLLM: '{"entities":[],"count":0}',
        forUser: 'No entities found.',
      );
    }

    // forLLM: compact JSON
    final jsonList = results.map((r) {
      final (entity, factCount) = r;
      return {
        'id': entity.id,
        'name': entity.name,
        'type': entity.entityType.label,
        'temperature': entity.temperature.name,
        'facts': factCount,
        'summary': entity.summary ?? '',
      };
    }).toList();

    final forLLM = jsonEncode({
      'entities': jsonList,
      'count': results.length,
      'offset': offset,
      'limit': limit,
    });

    // forUser: readable list
    final lines = results.map((r) {
      final (entity, factCount) = r;
      return '• ${entity.name} [${entity.entityType.label}] '
          '(${entity.temperature.name}, $factCount facts)';
    }).join('\n');
    final forUser = '${results.length} entities:\n$lines';

    return ToolResult.dual(forLLM: forLLM, forUser: forUser);
  }

  Future<ToolResult> _detail(Map<String, dynamic> args) async {
    final entityId = (args['entity_id'] as num?)?.toInt();
    final entityName = args['entity_name'] as String?;

    KnowledgeEntityDetail? detail;

    if (entityId != null) {
      detail = await knowledgeService.getEntityDetail(entityId);
    } else if (entityName != null && entityName.isNotEmpty) {
      detail = await knowledgeService.resolveEntityByName(entityName);
    } else {
      return ToolResult.error(
          'detail operation requires "entity_id" or "entity_name".');
    }

    if (detail == null) {
      return ToolResult.dual(
        forLLM: '{"error":"Entity not found"}',
        forUser: 'Entity not found.',
      );
    }

    final e = detail.entity;

    // forLLM: full JSON
    final forLLM = jsonEncode({
      'id': e.id,
      'name': e.name,
      'type': e.entityType.label,
      'summary': e.summary ?? '',
      'temperature': e.temperature.name,
      'access_count': e.accessCount,
      'decay_score': detail.decayScore,
      'facts': detail.facts
          .map((f) => {'key': f.key, 'value': f.value})
          .toList(),
      'relations': detail.relations
          .map((r) => {
                'source': r.sourceName,
                'relation': r.relation.predicate,
                'target': r.targetName,
              })
          .toList(),
      'aliases':
          detail.aliases.map((a) => a.aliasName).toList(),
    });

    // forUser: readable
    final buf = StringBuffer()
      ..writeln('${e.name} [${e.entityType.label}]')
      ..writeln(e.summary ?? '');
    if (detail.facts.isNotEmpty) {
      buf.writeln('\nFacts:');
      for (final f in detail.facts) {
        buf.writeln('  ${f.key}: ${f.value}');
      }
    }
    if (detail.relations.isNotEmpty) {
      buf.writeln('\nRelations:');
      for (final r in detail.relations) {
        buf.writeln('  ${r.sourceName} → ${r.relation.predicate} → ${r.targetName}');
      }
    }
    if (detail.aliases.isNotEmpty) {
      buf.writeln('\nAliases: ${detail.aliases.map((a) => a.aliasName).join(', ')}');
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }

  Future<ToolResult> _stats() async {
    final stats = await knowledgeService.getKbStats();

    final forLLM = jsonEncode(stats);

    final byType = stats['by_type'] as Map<String, dynamic>;
    final byTemp = stats['by_temperature'] as Map<String, dynamic>;

    final buf = StringBuffer()
      ..writeln('Knowledge Base Statistics')
      ..writeln('Entities: ${stats['total_entities']}')
      ..writeln('Facts: ${stats['total_facts']}')
      ..writeln('Relations: ${stats['total_relations']}');
    if (byType.isNotEmpty) {
      buf.writeln('\nBy type:');
      byType.forEach((k, v) => buf.writeln('  $k: $v'));
    }
    if (byTemp.isNotEmpty) {
      buf.writeln('\nBy temperature:');
      byTemp.forEach((k, v) => buf.writeln('  $k: $v'));
    }

    return ToolResult.dual(forLLM: forLLM, forUser: buf.toString().trimRight());
  }
}
