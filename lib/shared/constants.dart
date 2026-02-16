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
}
