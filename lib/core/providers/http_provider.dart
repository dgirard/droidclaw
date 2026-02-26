import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';
import 'llm_response.dart';

/// Generic OpenAI-compatible HTTP provider.
/// Works with OpenRouter, OpenAI, Groq, vLLM, etc.
class HttpProvider implements LLMProvider {
  final String apiKey;
  final String apiBase;
  final String _defaultModel;
  final String _providerName;
  final Map<String, String> _extraHeaders;

  HttpProvider({
    required this.apiKey,
    required this.apiBase,
    required String defaultModel,
    required String providerName,
    Map<String, String>? extraHeaders,
  })  : _defaultModel = defaultModel,
        _providerName = providerName,
        _extraHeaders = extraHeaders ?? {};

  @override
  String get defaultModel => _defaultModel;

  @override
  String get providerName => _providerName;

  @override
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toOpenAIJson()).toList();
    }

    if (options != null) {
      if (options.containsKey('max_tokens')) {
        body['max_tokens'] = options['max_tokens'];
      }
      if (options.containsKey('temperature')) {
        body['temperature'] = options['temperature'];
      }
    }

    final uri = Uri.parse('$apiBase/chat/completions');

    // Retry with exponential backoff for transient failures
    const maxRetries = 2;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          ..._extraHeaders,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        // Retry on 429 (rate limit) or 5xx (server errors)
        if (attempt < maxRetries &&
            (response.statusCode == 429 || response.statusCode >= 500)) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        throw LLMException(
          'API error ${response.statusCode}',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      try {
        return _parseResponse(data);
      } on LLMException {
        // Retry on empty choices (transient provider issue)
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }

    // Unreachable, but Dart requires it
    throw LLMException('Max retries exceeded');
  }

  LLMResponse _parseResponse(Map<String, dynamic> data) {
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      // Include response body for diagnostics (truncated)
      final preview = data.toString();
      throw LLMException(
        'No choices in response',
        body: preview.length > 500 ? preview.substring(0, 500) : preview,
      );
    }

    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    final toolCalls = (message['tool_calls'] as List?)
        ?.map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
        .toList();

    final usage = data['usage'] as Map<String, dynamic>?;

    return LLMResponse(
      content: message['content'] as String? ?? '',
      toolCalls: toolCalls ?? [],
      finishReason: choice['finish_reason'] as String? ?? 'stop',
      usage: usage != null ? UsageInfo.fromJson(usage) : null,
    );
  }
}

/// Exception thrown by LLM providers.
class LLMException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  LLMException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    final parts = ['LLMException: $message'];
    if (statusCode != null) parts.add('status=$statusCode');
    if (body != null) {
      final truncated = body!.length > 500 ? '${body!.substring(0, 500)}...' : body!;
      parts.add('body=$truncated');
    }
    return parts.join(', ');
  }
}
