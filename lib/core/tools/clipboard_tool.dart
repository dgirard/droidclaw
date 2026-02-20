import 'package:flutter/services.dart';

import 'tool.dart';

/// Tool that reads or writes the device clipboard.
class ClipboardTool extends Tool {
  static const int _maxReadChars = 10000;
  static const int _maxWriteChars = 50000;

  @override
  String get name => 'clipboard';

  @override
  String get description =>
      'Read or write the device clipboard. '
      'Only read the clipboard when the user explicitly asks you to. '
      'Use "write" to place text in the clipboard for the user to paste elsewhere.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['read', 'write'],
            'description': 'Whether to read from or write to the clipboard',
          },
          'text': {
            'type': 'string',
            'description':
                'Text to write to clipboard (required for write operation)',
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
        case 'read':
          final data = await Clipboard.getData('text/plain');
          if (data == null || data.text == null || data.text!.isEmpty) {
            return ToolResult.simple(
                'Clipboard is empty or contains non-text content.');
          }
          var text = data.text!;
          final truncated = text.length > _maxReadChars;
          if (truncated) text = text.substring(0, _maxReadChars);
          final preview =
              text.length > 100 ? '${text.substring(0, 100)}...' : text;
          return ToolResult.dual(
            forLLM: truncated
                ? 'Clipboard content (truncated to $_maxReadChars chars, '
                    'original ${data.text!.length}):\n$text'
                : 'Clipboard content:\n$text',
            forUser: 'Clipboard: $preview',
          );

        case 'write':
          final text = arguments['text'] as String?;
          if (text == null || text.isEmpty) {
            return ToolResult.error(
                'Missing required parameter: text (for write)');
          }
          if (text.length > _maxWriteChars) {
            return ToolResult.error(
                'Text too long for clipboard '
                '(${text.length} chars, max $_maxWriteChars)');
          }
          await Clipboard.setData(ClipboardData(text: text));
          return ToolResult.dual(
            forLLM: 'Copied ${text.length} characters to clipboard.',
            forUser: 'Copied to clipboard (${text.length} chars)',
          );

        default:
          return ToolResult.error(
              'Unknown operation: $operation. Use "read" or "write".');
      }
    } catch (e) {
      return ToolResult.error('Clipboard operation failed: $e');
    }
  }
}
