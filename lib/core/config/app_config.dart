import '../../shared/constants.dart';

/// Top-level application configuration.
class AppConfig {
  final AgentConfig agent;
  final Map<String, ProviderConfig> providers;
  final ToolsConfig tools;

  const AppConfig({
    required this.agent,
    this.providers = const {},
    this.tools = const ToolsConfig(),
  });

  factory AppConfig.defaults() => AppConfig(
        agent: AgentConfig.defaults(),
        providers: {},
        tools: const ToolsConfig(),
      );

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        agent: json['agent'] != null
            ? AgentConfig.fromJson(json['agent'] as Map<String, dynamic>)
            : AgentConfig.defaults(),
        providers: (json['providers'] as Map<String, dynamic>?)?.map(
              (k, v) =>
                  MapEntry(k, ProviderConfig.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
        tools: json['tools'] != null
            ? ToolsConfig.fromJson(json['tools'] as Map<String, dynamic>)
            : const ToolsConfig(),
      );

  Map<String, dynamic> toJson() => {
        'agent': agent.toJson(),
        'providers': providers.map((k, v) => MapEntry(k, v.toJson())),
        'tools': tools.toJson(),
      };

  AppConfig copyWith({
    AgentConfig? agent,
    Map<String, ProviderConfig>? providers,
    ToolsConfig? tools,
  }) =>
      AppConfig(
        agent: agent ?? this.agent,
        providers: providers ?? this.providers,
        tools: tools ?? this.tools,
      );

  /// Get the active provider config based on agent.provider.
  ProviderConfig? get activeProvider => providers[agent.provider];
}

/// Agent behavior configuration.
class AgentConfig {
  final String provider;
  final String model;
  final int maxTokens;
  final double temperature;
  final int maxToolIterations;

  const AgentConfig({
    required this.provider,
    required this.model,
    this.maxTokens = AppConstants.defaultMaxTokens,
    this.temperature = AppConstants.defaultTemperature,
    this.maxToolIterations = AppConstants.maxToolIterations,
  });

  factory AgentConfig.defaults() => const AgentConfig(
        provider: AppConstants.defaultProvider,
        model: AppConstants.defaultModel,
      );

  factory AgentConfig.fromJson(Map<String, dynamic> json) => AgentConfig(
        provider: json['provider'] as String? ?? AppConstants.defaultProvider,
        model: json['model'] as String? ?? AppConstants.defaultModel,
        maxTokens:
            json['max_tokens'] as int? ?? AppConstants.defaultMaxTokens,
        temperature:
            (json['temperature'] as num?)?.toDouble() ?? AppConstants.defaultTemperature,
        maxToolIterations: json['max_tool_iterations'] as int? ??
            AppConstants.maxToolIterations,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'max_tool_iterations': maxToolIterations,
      };

  AgentConfig copyWith({
    String? provider,
    String? model,
    int? maxTokens,
    double? temperature,
    int? maxToolIterations,
  }) =>
      AgentConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        maxTokens: maxTokens ?? this.maxTokens,
        temperature: temperature ?? this.temperature,
        maxToolIterations: maxToolIterations ?? this.maxToolIterations,
      );
}

/// LLM provider configuration (API key stored separately in secure storage).
class ProviderConfig {
  final String apiBase;
  final Map<String, String> extraHeaders;

  const ProviderConfig({
    required this.apiBase,
    this.extraHeaders = const {},
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        apiBase: json['api_base'] as String? ?? '',
        extraHeaders:
            (json['extra_headers'] as Map<String, dynamic>?)?.cast<String, String>() ??
                {},
      );

  Map<String, dynamic> toJson() => {
        'api_base': apiBase,
        'extra_headers': extraHeaders,
      };

  ProviderConfig copyWith({
    String? apiBase,
    Map<String, String>? extraHeaders,
  }) =>
      ProviderConfig(
        apiBase: apiBase ?? this.apiBase,
        extraHeaders: extraHeaders ?? this.extraHeaders,
      );
}

/// Tools-specific configuration.
/// Note: Brave API key is stored in SecureStorage, not here.
class ToolsConfig {
  final int webSearchMaxResults;

  const ToolsConfig({
    this.webSearchMaxResults = AppConstants.webSearchMaxResults,
  });

  factory ToolsConfig.fromJson(Map<String, dynamic> json) => ToolsConfig(
        webSearchMaxResults: json['web_search_max_results'] as int? ??
            AppConstants.webSearchMaxResults,
      );

  Map<String, dynamic> toJson() => {
        'web_search_max_results': webSearchMaxResults,
      };

  ToolsConfig copyWith({
    int? webSearchMaxResults,
  }) =>
      ToolsConfig(
        webSearchMaxResults: webSearchMaxResults ?? this.webSearchMaxResults,
      );
}
