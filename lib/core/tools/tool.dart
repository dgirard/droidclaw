import '../../shared/constants.dart';
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

/// Wraps a cacheable read-only tool (U4 episodic memory) so the episodic
/// cache contract is exposed without editing the tool implementations:
///
/// - `parameters` gains a `force_fresh` boolean ("bypass the cached result")
///   so the LLM can opt out of a stale episode;
/// - `execute` strips `force_fresh` before delegating, so the wrapped tool
///   never sees the cache-control param.
///
/// Applied automatically by [ToolRegistry.register] for tools listed in
/// [AppConstants.episodeTtlSeconds] — both isolates' registration sites get
/// the schema injection with zero per-tool changes. The interception itself
/// (serve-from-cache before execution) lives in the AgentLoop, which also
/// strips `force_fresh` so cache keys never include it.
class CacheableToolWrapper extends Tool {
  CacheableToolWrapper(this.inner);

  final Tool inner;

  @override
  String get name => inner.name;

  @override
  String get description => inner.description;

  /// Merged schema (inner params + the injected `force_fresh` flag). Computed
  /// once — `inner.parameters` is static per tool and `getDefinitions()` reads
  /// this 3×/agent-iteration.
  @override
  late final Map<String, dynamic> parameters = _buildParameters();

  Map<String, dynamic> _buildParameters() {
    final params = Map<String, dynamic>.from(inner.parameters);
    final props = <String, dynamic>{
      ...?(params['properties'] as Map?)?.cast<String, dynamic>(),
      'force_fresh': {
        'type': 'boolean',
        'description':
            'Set true to bypass the cached result and fetch fresh data',
      },
    };
    params['properties'] = props;
    return params;
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) {
    final args = Map<String, dynamic>.from(arguments)..remove('force_fresh');
    return inner.execute(args);
  }
}

/// Registry managing available tools.
class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) {
    final wrapped = tool is! CacheableToolWrapper &&
            AppConstants.episodeTtlSeconds.containsKey(tool.name)
        ? CacheableToolWrapper(tool)
        : tool;
    _tools[wrapped.name] = wrapped;
  }

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
