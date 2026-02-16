import '../../shared/constants.dart';
import '../config/app_config.dart';
import 'anthropic_provider.dart';
import 'http_provider.dart';
import 'llm_provider.dart';

/// Factory to create LLM providers by name.
class ProviderFactory {
  ProviderFactory._();

  /// Create a provider from config.
  /// [name] is the provider identifier (e.g. "anthropic", "openrouter", "openai").
  /// [config] is the provider-specific configuration.
  /// [apiKey] is the API key (loaded from secure storage).
  static LLMProvider create({
    required String name,
    required ProviderConfig config,
    required String apiKey,
    String? defaultModel,
  }) {
    final lowerName = name.toLowerCase();

    if (lowerName == 'anthropic') {
      return AnthropicProvider(
        apiKey: apiKey,
        apiBase: config.apiBase.isNotEmpty
            ? config.apiBase
            : AppConstants.anthropicApiBase,
        defaultModel: defaultModel ?? 'claude-sonnet-4-20250514',
      );
    }

    // All others are OpenAI-compatible (OpenRouter, OpenAI, Groq, etc.)
    final apiBase = config.apiBase.isNotEmpty
        ? config.apiBase
        : _defaultApiBase(lowerName);

    return HttpProvider(
      apiKey: apiKey,
      apiBase: apiBase,
      defaultModel: defaultModel ?? _defaultModel(lowerName),
      providerName: lowerName,
      extraHeaders: config.extraHeaders.isNotEmpty
          ? config.extraHeaders
          : null,
    );
  }

  static String _defaultApiBase(String name) => switch (name) {
        'openrouter' => AppConstants.openRouterApiBase,
        'openai' => 'https://api.openai.com/v1',
        'groq' => 'https://api.groq.com/openai/v1',
        _ => '',
      };

  static String _defaultModel(String name) => switch (name) {
        'openrouter' => AppConstants.defaultModel,
        'openai' => 'gpt-4o',
        'groq' => 'llama-3.3-70b-versatile',
        _ => 'gpt-4o',
      };
}
