import 'dart:convert';

import '../knowledge/services/knowledge_service.dart';
import 'tool.dart';

/// Tool for querying the Knowledge Graph.
///
/// Performs hybrid search (FTS5 + graph activation + decay scoring)
/// and returns ranked entities with their facts and relations.
class KnowledgeSearchTool extends Tool {
  final KnowledgeService knowledgeService;

  KnowledgeSearchTool({required this.knowledgeService});

  @override
  String get name => 'knowledge_search';

  @override
  String get description =>
      'Search the knowledge graph for remembered information about people, '
      'places, events, or concepts from past conversations. '
      'Use this to recall facts, relationships, and context the user has '
      'previously shared.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Search query (natural language or entity name)',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results (default: 10)',
          },
        },
        'required': ['query'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: query');
    }
    if (query.length > 500) {
      return ToolResult.error('Query too long (max 500 characters)');
    }

    final limit = (arguments['limit'] as num?)?.toInt() ?? 10;

    try {
      final results = await knowledgeService.queryRelevant(
        query,
        limit: limit,
      );

      if (results.isEmpty) {
        return ToolResult.dual(
          forLLM: 'No knowledge found matching: $query',
          forUser: 'No results found.',
        );
      }

      // forLLM: structured JSON for reasoning
      final jsonResults = results.map((r) => r.toJson()).toList();
      final forLLM = const JsonEncoder.withIndent('  ').convert({
        'query': query,
        'results': jsonResults,
        'count': results.length,
      });

      // forUser: readable summary
      final forUser = results.map((r) => r.toReadable()).join('\n\n');

      return ToolResult.dual(forLLM: forLLM, forUser: forUser);
    } catch (e) {
      return ToolResult.error('Knowledge search error: $e');
    }
  }
}
