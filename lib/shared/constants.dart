/// App-wide constants and defaults for DroidClaw.
class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'DroidClaw';
  static const String appVersion = '1.0.0';

  // Agent defaults
  static const int maxToolIterations = 10;
  static const int defaultMaxTokens = 4096;
  static const double defaultTemperature = 0.7;

  // Summarization
  static const double summarizationThreshold = 0.75;
  static const int summarizationMessageCount = 20;
  static const int keepLastMessages = 4;

  // Web tools
  static const int webSearchMaxResults = 5;
  static const int webFetchMaxChars = 50000;
  static const int webFetchMaxRedirects = 5;
  static const int webScrapeMaxChars = 15000;
  static const int webScrapeJsTimeoutSeconds = 30;

  // Session
  static const String defaultSessionKey = 'default';

  // Memory
  static const int recentDailyNoteDays = 3;

  // Storage keys
  static const String configKey = 'app_config';
  static const String onboardingCompleteKey = 'onboarding_complete';

  // Default provider settings
  static const String defaultProvider = 'openrouter';
  static const String defaultModel = 'anthropic/claude-sonnet-4-20250514';
  static const String openRouterApiBase = 'https://openrouter.ai/api/v1';
  static const String anthropicApiBase = 'https://api.anthropic.com/v1';
  static const String geminiApiBase = 'https://generativelanguage.googleapis.com/v1beta/openai';
  static const String anthropicVersion = '2023-06-01';

  // Telegram
  static const String telegramApiBase = 'https://api.telegram.org/bot';
  static const String telegramBotTokenKey = 'telegram_bot_token';
  static const String telegramBotEnabledKey = 'telegram_bot_enabled';
  static const String telegramBotOffsetKey = 'telegram_bot_offset';
  static const String telegramAllowedUsersKey = 'telegram_allowed_users';
  static const int telegramPollTimeout = 30;
  static const int telegramHttpTimeout = 35;
  static const int telegramMaxMessageLength = 4000;
  static const int telegramMaxConcurrentChats = 3;
  static const String telegramSessionPrefix = 'telegram_';

  // Cron
  static const String cronSessionPrefix = 'cron_';
  static const String cronDefinitionsKey = 'cron_definitions';
  static const String cronPendingTriggersKey = 'cron_pending_triggers';

  // LLM Trace
  static const int llmTraceMaxEntries = 500;
  static const int llmTraceRetentionHours = 24;

  // Knowledge Graph
  static const String knowledgeDbFilename = 'knowledge_graph.db';
  static const int knowledgeDecayHalfLifeDays = 30;
  static const int knowledgeMaxContextChars = 2000;
  static const String cachedKnowledgeEnabledKey = 'cached_knowledge_enabled';

  // Cached secrets for service isolate (SharedPreferences mirror of SecureStorage)
  static const String cachedApiKeyKey = 'cached_api_key';
  static const String cachedProviderNameKey = 'cached_provider_name';
  static const String cachedBraveApiKeyKey = 'cached_brave_api_key';
  static const String cachedOrsApiKeyKey = 'cached_ors_api_key';
  static const String cachedSncfApiKeyKey = 'cached_sncf_api_key';
  static const String cachedPrimApiKeyKey = 'cached_prim_api_key';
  static const String cachedWorkspacePathKey = 'cached_workspace_path';
  static const String cachedLocaleKey = 'cached_locale';
}
