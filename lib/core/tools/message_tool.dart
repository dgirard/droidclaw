import 'dart:async';

import 'tool.dart';

/// Sends a message directly to the user via callback.
/// Returns a silent result so the LLM doesn't see its own forwarded message.
class MessageTool extends Tool {
  /// Callback invoked with the message content for the user.
  final void Function(String message)? onMessage;

  MessageTool({this.onMessage});

  @override
  String get name => 'message';

  @override
  String get description =>
      'Send a message directly to the user. Use this when you want to '
      'communicate something to the user outside of your main response.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': 'The message to send to the user',
          },
        },
        'required': ['content'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final content = arguments['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error('Missing required parameter: content');
    }

    onMessage?.call(content);

    return ToolResult.silent('Message sent to user.');
  }
}
