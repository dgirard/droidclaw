import 'dart:ui';

import '../../shared/constants.dart';

/// Top-level application configuration.
class AppConfig {
  final AgentConfig agent;
  final Map<String, ProviderConfig> providers;
  final ToolsConfig tools;
  final KnowledgeConfig knowledge;
  final EmbeddingConfig embedding;

  /// Locale setting: 'en', 'fr', or 'system' (follow device language).
  final String locale;

  const AppConfig({
    required this.agent,
    this.providers = const {},
    this.tools = const ToolsConfig(),
    this.knowledge = const KnowledgeConfig(),
    this.embedding = const EmbeddingConfig(),
    this.locale = 'system',
  });

  factory AppConfig.defaults() => AppConfig(
        agent: AgentConfig.defaults(),
        providers: {},
        tools: const ToolsConfig(),
        knowledge: const KnowledgeConfig(),
        embedding: const EmbeddingConfig(),
        locale: 'system',
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
        knowledge: json['knowledge'] != null
            ? KnowledgeConfig.fromJson(
                json['knowledge'] as Map<String, dynamic>)
            : const KnowledgeConfig(),
        embedding: json['embedding'] != null
            ? EmbeddingConfig.fromJson(
                json['embedding'] as Map<String, dynamic>)
            : const EmbeddingConfig(),
        locale: json['locale'] as String? ?? 'system',
      );

  Map<String, dynamic> toJson() => {
        'agent': agent.toJson(),
        'providers': providers.map((k, v) => MapEntry(k, v.toJson())),
        'tools': tools.toJson(),
        'knowledge': knowledge.toJson(),
        'embedding': embedding.toJson(),
        'locale': locale,
      };

  AppConfig copyWith({
    AgentConfig? agent,
    Map<String, ProviderConfig>? providers,
    ToolsConfig? tools,
    KnowledgeConfig? knowledge,
    EmbeddingConfig? embedding,
    String? locale,
  }) =>
      AppConfig(
        agent: agent ?? this.agent,
        providers: providers ?? this.providers,
        tools: tools ?? this.tools,
        knowledge: knowledge ?? this.knowledge,
        embedding: embedding ?? this.embedding,
        locale: locale ?? this.locale,
      );

  /// Get the active provider config based on agent.provider.
  ProviderConfig? get activeProvider => providers[agent.provider];

  /// Resolve the effective locale code.
  /// If locale is 'system', check the device language.
  String get resolvedLocale {
    if (locale == 'system') {
      return _resolveSystemLocale();
    }
    return locale;
  }

  static const _supportedLocales = {'en', 'fr', 'es', 'de', 'it'};

  static String _resolveSystemLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
    return _supportedLocales.contains(deviceLocale) ? deviceLocale : 'en';
  }
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
  final Set<String> disabledTools;

  static const _defaultDisabledTools = {
    'speak', 'open_app', 'set_alarm',
    'notifications', 'contacts', 'calendar',
    'pick_image', 'radio',
    'knowledge_search', 'knowledge_store',
    'proof_editor', 'dream',
  };

  const ToolsConfig({
    this.webSearchMaxResults = AppConstants.webSearchMaxResults,
    this.disabledTools = _defaultDisabledTools,
  });

  factory ToolsConfig.fromJson(Map<String, dynamic> json) => ToolsConfig(
        webSearchMaxResults: json['web_search_max_results'] as int? ??
            AppConstants.webSearchMaxResults,
        disabledTools: (json['disabled_tools'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toSet() ??
            _defaultDisabledTools,
      );

  Map<String, dynamic> toJson() => {
        'web_search_max_results': webSearchMaxResults,
        'disabled_tools': disabledTools.toList(),
      };

  ToolsConfig copyWith({
    int? webSearchMaxResults,
    Set<String>? disabledTools,
  }) =>
      ToolsConfig(
        webSearchMaxResults: webSearchMaxResults ?? this.webSearchMaxResults,
        disabledTools: disabledTools ?? this.disabledTools,
      );
}

/// Embedding provider configuration.
class EmbeddingConfig {
  /// Provider name: 'gemini', 'openai', 'openrouter', '' (disabled).
  final String provider;

  /// Model identifier (e.g. 'gemini-embedding-001').
  final String model;

  /// Output vector dimensionality (e.g. 768).
  final int dimensions;

  /// Custom API base URL (empty = use default for provider).
  final String apiBase;

  /// When false, reuse the LLM provider's API key. When true, use a
  /// dedicated embedding API key stored separately.
  final bool useOwnApiKey;

  const EmbeddingConfig({
    this.provider = '',
    this.model = '',
    this.dimensions = 768,
    this.apiBase = '',
    this.useOwnApiKey = false,
  });

  factory EmbeddingConfig.fromJson(Map<String, dynamic> json) =>
      EmbeddingConfig(
        provider: json['provider'] as String? ?? '',
        model: json['model'] as String? ?? '',
        dimensions: json['dimensions'] as int? ?? 768,
        apiBase: json['api_base'] as String? ?? '',
        useOwnApiKey: json['use_own_api_key'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'model': model,
        'dimensions': dimensions,
        'api_base': apiBase,
        'use_own_api_key': useOwnApiKey,
      };

  EmbeddingConfig copyWith({
    String? provider,
    String? model,
    int? dimensions,
    String? apiBase,
    bool? useOwnApiKey,
  }) =>
      EmbeddingConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        dimensions: dimensions ?? this.dimensions,
        apiBase: apiBase ?? this.apiBase,
        useOwnApiKey: useOwnApiKey ?? this.useOwnApiKey,
      );
}

/// Knowledge Graph configuration.
class KnowledgeConfig {
  final bool enabled;
  final int decayHalfLifeDays;
  final bool autoExtract;

  /// Language for all KG data. Set to the user's resolved locale on first KG
  /// enable, immutable afterwards (until "Forget All" resets it to null).
  final String? kbLanguage;

  const KnowledgeConfig({
    this.enabled = false,
    this.decayHalfLifeDays = AppConstants.knowledgeDecayHalfLifeDays,
    this.autoExtract = true,
    this.kbLanguage,
  });

  factory KnowledgeConfig.fromJson(Map<String, dynamic> json) =>
      KnowledgeConfig(
        enabled: json['enabled'] as bool? ?? false,
        decayHalfLifeDays: json['decay_half_life_days'] as int? ??
            AppConstants.knowledgeDecayHalfLifeDays,
        autoExtract: json['auto_extract'] as bool? ?? true,
        kbLanguage: json['kb_language'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'decay_half_life_days': decayHalfLifeDays,
        'auto_extract': autoExtract,
        if (kbLanguage != null) 'kb_language': kbLanguage,
      };

  KnowledgeConfig copyWith({
    bool? enabled,
    int? decayHalfLifeDays,
    bool? autoExtract,
    String? kbLanguage,
    bool clearKbLanguage = false,
  }) =>
      KnowledgeConfig(
        enabled: enabled ?? this.enabled,
        decayHalfLifeDays: decayHalfLifeDays ?? this.decayHalfLifeDays,
        autoExtract: autoExtract ?? this.autoExtract,
        kbLanguage: clearKbLanguage ? null : (kbLanguage ?? this.kbLanguage),
      );

  /// Map locale code to full language name for LLM prompts.
  ///
  /// SINGLE SOURCE (U19): every prompt that names a language (context
  /// builder KB note, KG query expansion, entity extraction, knowledge
  /// tools, KB cleanup) resolves it here — do not add local copies.
  /// Unknown codes deliberately resolve to 'English': supported locales are
  /// pinned by [AppConfig._supportedLocales], so an unknown code is a
  /// programming error and English matches the app-wide locale fallback.
  /// Pinned by test/agent/language_compliance_test.dart.
  static String languageName(String code) => switch (code) {
        'fr' => 'French',
        'es' => 'Spanish',
        'de' => 'German',
        'it' => 'Italian',
        _ => 'English',
      };
}
