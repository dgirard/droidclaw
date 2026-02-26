import 'dart:convert';

import 'embedding_provider.dart';

/// Native Gemini embedding provider.
///
/// Uses the Gemini REST API (NOT the OpenAI-compatible wrapper).
/// Base URL: generativelanguage.googleapis.com/v1beta
/// Auth: x-goog-api-key header (not Bearer token).
/// Supports taskType for optimized embeddings.
class GeminiEmbeddingProvider extends BaseCloudEmbeddingProvider {
  GeminiEmbeddingProvider({
    required super.apiKey,
    required super.apiBase,
    required super.dimensions,
  });

  @override
  String get providerName => 'gemini';

  @override
  String get providerId => 'gemini';

  @override
  Future<EmbeddingResult> callApi({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };

    if (texts.length == 1) {
      return _embedSingle(texts.first, model, dimensions, taskType, headers);
    }
    return _embedBatch(texts, model, dimensions, taskType, headers);
  }

  Future<EmbeddingResult> _embedSingle(
    String text,
    String model,
    int? dimensions,
    String? taskType,
    Map<String, String> headers,
  ) async {
    final body = <String, dynamic>{
      'content': {
        'parts': [
          {'text': text}
        ]
      },
    };
    if (dimensions != null) body['output_dimensionality'] = dimensions;
    if (taskType != null) body['taskType'] = taskType;

    final response = await postRequest(
      Uri.parse('$apiBase/models/$model:embedContent'),
      headers,
      jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Response shape: {"embedding": {"values": [...]}}
    final embeddingMap = data['embedding'] as Map<String, dynamic>;
    final values = (embeddingMap['values'] as List)
        .cast<num>()
        .map((n) => n.toDouble())
        .toList();

    return EmbeddingResult(embeddings: [values]);
  }

  Future<EmbeddingResult> _embedBatch(
    List<String> texts,
    String model,
    int? dimensions,
    String? taskType,
    Map<String, String> headers,
  ) async {
    final requests = texts.map((text) {
      final req = <String, dynamic>{
        'model': 'models/$model',
        'content': {
          'parts': [
            {'text': text}
          ]
        },
      };
      if (dimensions != null) req['output_dimensionality'] = dimensions;
      if (taskType != null) req['taskType'] = taskType;
      return req;
    }).toList();

    final response = await postRequest(
      Uri.parse('$apiBase/models/$model:batchEmbedContents'),
      headers,
      jsonEncode({'requests': requests}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final embeddingsList = data['embeddings'] as List;
    final embeddings = embeddingsList
        .map((e) => ((e as Map<String, dynamic>)['values'] as List)
            .cast<num>()
            .map((n) => n.toDouble())
            .toList())
        .toList();

    return EmbeddingResult(embeddings: embeddings);
  }
}
