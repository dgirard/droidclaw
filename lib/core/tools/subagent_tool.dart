import 'tool.dart';

/// Callback type for creating a subagent that processes a task.
/// Returns the subagent's final response.
typedef SubagentExecutor = Future<String> Function(String task);

/// Synchronous subagent tool: creates a new agent loop instance,
/// executes a task, and returns the result.
class SubagentTool extends Tool {
  SubagentExecutor? executor;

  SubagentTool({this.executor});

  @override
  String get name => 'subagent';

  @override
  String get description =>
      'Delegate a task to a sub-agent that will work on it independently. '
      'Useful for complex tasks that benefit from focused attention.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'task': {
            'type': 'string',
            'description': 'The task description for the sub-agent',
          },
        },
        'required': ['task'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final task = arguments['task'] as String?;
    if (task == null || task.isEmpty) {
      return ToolResult.error('Missing required parameter: task');
    }

    if (executor == null) {
      return ToolResult.error('Subagent executor not configured');
    }

    try {
      final result = await executor!(task);

      // Truncate for user display, full for LLM
      final userResult = result.length > 500
          ? '${result.substring(0, 500)}...\n[Truncated - ${result.length} chars total]'
          : result;

      return ToolResult.dual(
        forLLM: result,
        forUser: userResult,
      );
    } catch (e) {
      return ToolResult.error('Subagent failed: $e');
    }
  }
}
