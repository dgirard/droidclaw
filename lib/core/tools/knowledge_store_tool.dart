import '../knowledge/database/knowledge_graph_db.dart';
import '../knowledge/services/entity_resolver.dart';
import 'tool.dart';

/// Tool for explicitly storing a fact in the Knowledge Graph.
///
/// Allows the LLM to persist information the user explicitly asks
/// to be remembered ("remember that my dentist is Dr. Martin").
class KnowledgeStoreTool extends Tool {
  final KnowledgeGraphDB db;
  final EntityResolver resolver;

  KnowledgeStoreTool({required this.db, required this.resolver});

  @override
  String get name => 'knowledge_store';

  @override
  String get description =>
      'Store a fact in the knowledge graph to remember it across conversations. '
      'Use when the user explicitly asks you to remember something, or when '
      'important information should be persisted.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'entity': {
            'type': 'string',
            'description':
                'The entity name (person, place, concept, etc.)',
          },
          'key': {
            'type': 'string',
            'description': 'The fact key (e.g., "role", "address", "birthday")',
          },
          'value': {
            'type': 'string',
            'description': 'The fact value',
          },
          'entity_type': {
            'type': 'string',
            'description':
                'Entity type: PERSON, PLACE, ORG, EVENT, CONCEPT, DATE (default: CONCEPT)',
          },
        },
        'required': ['entity', 'key', 'value'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final entityName = arguments['entity'] as String?;
    final key = arguments['key'] as String?;
    final value = arguments['value'] as String?;
    final entityType = arguments['entity_type'] as String? ?? 'CONCEPT';

    if (entityName == null || entityName.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: entity');
    }
    if (key == null || key.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: key');
    }
    if (value == null || value.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: value');
    }
    if (entityName.length > 200 || key.length > 200 || value.length > 5000) {
      return ToolResult.error('Input too long (entity/key max 200, value max 5000 chars)');
    }

    try {
      // Resolve or create the entity
      final entityId = await resolver.resolve(
        name: entityName,
        entityType: entityType,
      );

      // Store the fact bi-temporally
      await db.updateFactBiTemporal(
        entityId: entityId,
        key: key,
        newValue: value,
      );

      return ToolResult.dual(
        forLLM: 'Stored: $entityName.$key = $value (entity_id=$entityId)',
        forUser: '$entityName: $key = $value',
      );
    } catch (e) {
      return ToolResult.error('Knowledge store error: $e');
    }
  }
}
