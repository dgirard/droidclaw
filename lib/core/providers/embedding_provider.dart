import 'dart:math';

import 'package:http/http.dart' as http;

/// Result of an embedding request.
class EmbeddingResult {
  final List<List<double>> embeddings;
  final int? promptTokens;

  const EmbeddingResult({required this.embeddings, this.promptTokens});
}

/// Abstract interface for embedding providers.
abstract class EmbeddingProvider {
  /// Embed one or more texts, returning one vector per input.
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  });

  /// Human-readable provider name for logging.
  String get providerName;

  /// Unique provider key stored alongside vectors for provenance tracking.
  String get providerId;

  /// Output vector dimensionality for this provider configuration.
  int get outputDimensions;

  /// Release HTTP client resources.
  Future<void> dispose();
}

/// Shared base class for cloud embedding providers.
/// Centralizes HTTP retry logic (max 2 retries, exponential backoff on 429/5xx).
abstract class BaseCloudEmbeddingProvider implements EmbeddingProvider {
  final String apiKey;
  final String apiBase;
  final int _dimensions;
  final http.Client _client;

  /// [client] is a test seam (U16): inject a mock instead of relying on
  /// `http.runWithClient`. The retry loop here intentionally stays local —
  /// it mirrors, not reuses, `RetryingHttpClient` (timeout + exception-based
  /// flow differ; see U16 exclusion note in the roadmap plan).
  BaseCloudEmbeddingProvider({
    required this.apiKey,
    required this.apiBase,
    required int dimensions,
    http.Client? client,
  })  : _dimensions = dimensions,
        _client = client ?? http.Client();

  @override
  int get outputDimensions => _dimensions;

  /// Subclasses implement the actual HTTP call.
  Future<EmbeddingResult> callApi({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  });

  @override
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  }) async {
    const maxRetries = 2;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await callApi(
          texts: texts,
          model: model,
          dimensions: dimensions,
          taskType: taskType,
        );
      } on HttpRetryException {
        if (attempt == maxRetries) rethrow;
        await Future.delayed(
            Duration(milliseconds: 500 * pow(2, attempt).toInt()));
      }
    }
    throw StateError('Unreachable');
  }

  /// Helper: POST with retry-eligible status code detection.
  Future<http.Response> postRequest(
      Uri uri, Map<String, String> headers, String body) async {
    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw HttpRetryException(response.statusCode, response.body);
    }
    if (response.statusCode != 200) {
      throw EmbeddingApiException(response.statusCode, response.body);
    }
    return response;
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// Thrown on retriable HTTP errors (429, 5xx).
class HttpRetryException implements Exception {
  final int statusCode;
  final String body;

  const HttpRetryException(this.statusCode, this.body);

  @override
  String toString() => 'HttpRetryException($statusCode)';
}

/// Thrown on non-retriable HTTP errors.
class EmbeddingApiException implements Exception {
  final int statusCode;
  final String body;

  const EmbeddingApiException(this.statusCode, this.body);

  @override
  String toString() => 'EmbeddingApiException($statusCode): $body';
}
