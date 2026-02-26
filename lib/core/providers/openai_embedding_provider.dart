import 'dart:convert';

import 'embedding_provider.dart';

/// OpenAI-compatible embedding provider.
/// Works with OpenAI, OpenRouter, Together AI, and any API
/// that implements the POST /embeddings endpoint.
class OpenAIEmbeddingProvider extends BaseCloudEmbeddingProvider {
  final String _providerId;

  OpenAIEmbeddingProvider({
    required super.apiKey,
    required super.apiBase,
    required super.dimensions,
    required String providerId,
  }) : _providerId = providerId;

  @override
  String get providerName => _providerId;

  @override
  String get providerId => _providerId;

  @override
  Future<EmbeddingResult> callApi({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'input': texts.length == 1 ? texts.first : texts,
      'encoding_format': 'float',
    };
    if (dimensions != null) body['dimensions'] = dimensions;

    final response = await postRequest(
      Uri.parse('$apiBase/embeddings'),
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['data'] as List)
      ..sort((a, b) =>
          (a['index'] as int).compareTo(b['index'] as int));

    final embeddings = items
        .map((item) => (item['embedding'] as List)
            .cast<num>()
            .map((n) => n.toDouble())
            .toList())
        .toList();

    final usage = data['usage'] as Map<String, dynamic>?;
    return EmbeddingResult(
      embeddings: embeddings,
      promptTokens: usage?['prompt_tokens'] as int?,
    );
  }
}
