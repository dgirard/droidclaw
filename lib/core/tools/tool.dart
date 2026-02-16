import '../providers/llm_response.dart';

/// Result of a tool execution with dual content (Go pattern).
/// [forLLM] provides context for the model, [forUser] is displayed in the UI.
class ToolResult {
  final String forLLM;
  final String forUser;
  final bool isError;
  final bool silent;

  const ToolResult({
    required this.forLLM,
    String? forUser,
    this.isError = false,
    this.silent = false,
  }) : forUser = forUser ?? forLLM;

  /// Simple result where LLM and user see the same content.
  factory ToolResult.simple(String content) => ToolResult(forLLM: content);

  /// Error result.
  factory ToolResult.error(String message) =>
      ToolResult(forLLM: message, isError: true);

  /// Silent result (not shown to user, only sent to LLM).
  factory ToolResult.silent(String content) =>
      ToolResult(forLLM: content, silent: true);

  /// Dual content: different views for LLM and user.
  factory ToolResult.dual({
    required String forLLM,
    required String forUser,
  }) =>
      ToolResult(forLLM: forLLM, forUser: forUser);
}

/// Abstract base for all tools.
abstract class Tool {
  /// Tool name used in tool calls.
  String get name;

  /// Human-readable description of what the tool does.
  String get description;

  /// JSON Schema for the tool's parameters.
  Map<String, dynamic> get parameters;

  /// Execute the tool with the given arguments.
  Future<ToolResult> execute(Map<String, dynamic> arguments);

  /// Get the ToolDefinition for LLM registration.
  ToolDefinition get definition => ToolDefinition(
        name: name,
        description: description,
        parameters: parameters,
      );
}

/// Registry managing available tools.
class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) => _tools[tool.name] = tool;

  void unregister(String name) => _tools.remove(name);

  Tool? get(String name) => _tools[name];

  List<String> get toolNames => _tools.keys.toList();

  List<ToolDefinition> getDefinitions() =>
      _tools.values.map((t) => t.definition).toList();

  Future<ToolResult> execute(
      String name, Map<String, dynamic> arguments) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult.error('Unknown tool: $name');
    }
    try {
      return await tool.execute(arguments);
    } catch (e) {
      return ToolResult.error('Tool $name error: $e');
    }
  }
}
