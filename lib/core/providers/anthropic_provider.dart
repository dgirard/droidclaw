import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants.dart';
import 'http_provider.dart';
import 'llm_provider.dart';
import 'llm_response.dart';

/// Anthropic Messages API provider.
/// Handles the different message format (content blocks, tool_use/tool_result).
class AnthropicProvider implements LLMProvider {
  final String apiKey;
  final String apiBase;
  final String _defaultModel;
  final http.Client? _client;

  AnthropicProvider({
    required this.apiKey,
    this.apiBase = AppConstants.anthropicApiBase,
    String defaultModel = 'claude-sonnet-4-20250514',
    http.Client? client,
  })  : _defaultModel = defaultModel,
        _client = client;

  @override
  String get defaultModel => _defaultModel;

  @override
  String get providerName => 'anthropic';

  @override
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  }) async {
    // Extract system prompt from messages (Anthropic uses separate system field).
    String? systemPrompt;
    final apiMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == 'system') {
        systemPrompt = msg.content;
        continue;
      }
      apiMessages.add(_convertMessage(msg));
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': apiMessages,
      'max_tokens': options?['max_tokens'] ?? AppConstants.defaultMaxTokens,
    };

    if (systemPrompt != null) {
      body['system'] = systemPrompt;
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toAnthropicJson()).toList();
    }

    if (options?['temperature'] != null) {
      body['temperature'] = options!['temperature'];
    }

    final uri = Uri.parse('$apiBase/messages');
    final client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': AppConstants.anthropicVersion,
        },
        body: jsonEncode(body),
      );
    } finally {
      if (_client == null) client.close();
    }

    if (response.statusCode != 200) {
      throw LLMException(
        'Anthropic API error ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseResponse(data);
  }

  /// Convert a Message to Anthropic API format.
  Map<String, dynamic> _convertMessage(Message msg) {
    if (msg.role == 'assistant' &&
        msg.toolCalls != null &&
        msg.toolCalls!.isNotEmpty) {
      // Assistant message with tool calls → content blocks.
      final content = <Map<String, dynamic>>[];
      if (msg.content.isNotEmpty) {
        content.add({'type': 'text', 'text': msg.content});
      }
      for (final tc in msg.toolCalls!) {
        content.add({
          'type': 'tool_use',
          'id': tc.id,
          'name': tc.name,
          'input': tc.arguments,
        });
      }
      return {'role': 'assistant', 'content': content};
    }

    if (msg.role == 'tool') {
      // Tool result → user message with tool_result content block.
      return {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': msg.toolCallId,
            'content': msg.content,
          }
        ],
      };
    }

    return {
      'role': msg.role,
      'content': msg.content,
    };
  }

  /// Parse Anthropic response format.
  LLMResponse _parseResponse(Map<String, dynamic> data) {
    final content = data['content'] as List? ?? [];
    final textParts = <String>[];
    final toolCalls = <ToolCall>[];

    for (final block in content) {
      final blockMap = block as Map<String, dynamic>;
      final type = blockMap['type'] as String;

      if (type == 'text') {
        textParts.add(blockMap['text'] as String);
      } else if (type == 'tool_use') {
        toolCalls.add(ToolCall(
          id: blockMap['id'] as String,
          type: 'tool_use',
          name: blockMap['name'] as String,
          arguments: blockMap['input'] as Map<String, dynamic>? ?? {},
        ));
      }
    }

    final usage = data['usage'] as Map<String, dynamic>?;
    final stopReason = data['stop_reason'] as String? ?? 'end_turn';

    return LLMResponse(
      content: textParts.join('\n'),
      toolCalls: toolCalls,
      finishReason: stopReason,
      usage: usage != null ? UsageInfo.fromJson(usage) : null,
    );
  }
}
