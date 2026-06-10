import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants.dart';
import '../net/retrying_http_client.dart';
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
  final http.Client? _client;
  final Duration _retryBaseDelay;

  HttpProvider({
    required this.apiKey,
    required this.apiBase,
    required String defaultModel,
    required String providerName,
    Map<String, String>? extraHeaders,
    http.Client? client,
    Duration retryBaseDelay =
        const Duration(milliseconds: AppConstants.httpRetryBaseDelayMs),
  })  : _defaultModel = defaultModel,
        _providerName = providerName,
        _extraHeaders = extraHeaders ?? {},
        _client = client,
        _retryBaseDelay = retryBaseDelay;

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

    // Shared retry policy (429/5xx + exponential backoff); the predicate
    // adds the provider-specific "200 with empty choices" transient case.
    final client = RetryingHttpClient(
      inner: _client,
      baseDelay: _retryBaseDelay,
      shouldRetry: _hasEmptyChoices,
    );
    try {
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          ..._extraHeaders,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw LLMException(
          'API error ${response.statusCode}',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // If choices stayed empty after exhausting retries, _parseResponse
      // throws the same LLMException as before the extraction.
      return _parseResponse(data);
    } finally {
      client.close();
    }
  }

  /// Retry predicate: a 200 response with no `choices` is a transient
  /// provider issue (observed with OpenRouter) worth re-requesting.
  static bool _hasEmptyChoices(http.Response response) {
    if (response.statusCode != 200) return false;
    try {
      final data = jsonDecode(response.body);
      final choices = (data as Map<String, dynamic>)['choices'] as List?;
      return choices == null || choices.isEmpty;
    } catch (_) {
      return false;
    }
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
