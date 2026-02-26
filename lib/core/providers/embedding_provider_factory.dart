import '../../shared/constants.dart';
import 'embedding_provider.dart';
import 'gemini_embedding_provider.dart';
import 'openai_embedding_provider.dart';

/// Factory to create embedding providers by name.
class EmbeddingProviderFactory {
  EmbeddingProviderFactory._();

  /// Create an embedding provider from config.
  static EmbeddingProvider create({
    required String providerName,
    required String apiKey,
    String? apiBase,
    int dimensions = 768,
  }) {
    final lower = providerName.toLowerCase();

    if (lower == 'gemini') {
      return GeminiEmbeddingProvider(
        apiKey: apiKey,
        apiBase: apiBase ?? AppConstants.geminiEmbeddingApiBase,
        dimensions: dimensions,
      );
    }

    // OpenAI, OpenRouter, Together — all OpenAI-compatible
    return OpenAIEmbeddingProvider(
      apiKey: apiKey,
      apiBase: apiBase ?? _defaultApiBase(lower),
      providerId: lower,
      dimensions: dimensions,
    );
  }

  static String _defaultApiBase(String name) => switch (name) {
        'openai' => 'https://api.openai.com/v1',
        'openrouter' => 'https://openrouter.ai/api/v1',
        'together' => 'https://api.together.xyz/v1',
        _ => 'https://api.openai.com/v1',
      };

  /// Default embedding model for a given provider.
  static String defaultModel(String providerName) =>
      switch (providerName.toLowerCase()) {
        'gemini' => 'gemini-embedding-001',
        'openai' => 'text-embedding-3-small',
        'openrouter' => 'openai/text-embedding-3-small',
        'together' => 'togethercomputer/m2-bert-80M-8k-retrieval',
        _ => 'text-embedding-3-small',
      };
}
