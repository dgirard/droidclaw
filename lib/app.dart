import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/chat/chat_screen.dart';
import 'features/chat/history_screen.dart';
import 'features/onboarding/onboard_screen.dart';
import 'features/settings/cron_config_screen.dart';
import 'features/settings/cron_edit_screen.dart';
import 'features/settings/embedding_config_screen.dart';
import 'features/settings/knowledge_browser_screen.dart';
import 'features/settings/knowledge_config_screen.dart';
import 'features/settings/knowledge_entity_detail_screen.dart';
import 'features/settings/llm_trace_detail_screen.dart';
import 'features/settings/llm_traces_screen.dart';
import 'features/settings/locale_config_screen.dart';
import 'features/settings/logs_screen.dart';
import 'features/settings/provider_config_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/skills_screen.dart';
import 'features/settings/tools_config_screen.dart';
import 'features/settings/telegram_config_screen.dart';
import 'features/settings/routing_config_screen.dart';
import 'features/settings/web_search_config_screen.dart';
import 'l10n/l10n.dart';
import 'providers/app_providers.dart';

/// Root MaterialApp with Material 3 theme and routing.
class DroidClawApp extends ConsumerWidget {
  const DroidClawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final configStorage = ref.read(configStorageProvider);
    final initialRoute =
        configStorage.isOnboardingComplete ? '/chat' : '/onboard';

    // Resolve locale: 'system' → null (let Flutter pick), otherwise explicit
    final locale = config.locale == 'system' ? null : Locale(config.locale);

    return MaterialApp(
      title: 'DroidClaw',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: initialRoute,
      routes: {
        '/onboard': (context) => const OnboardScreen(),
        '/chat': (context) => const ChatScreen(),
        '/history': (context) => const HistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings/provider': (context) => const ProviderConfigScreen(),
        '/settings/skills': (context) => const SkillsScreen(),
        '/settings/telegram': (context) => const TelegramConfigScreen(),
        '/settings/tools': (context) => const ToolsConfigScreen(),
        '/settings/web-search': (context) => const WebSearchConfigScreen(),
        '/settings/routing': (context) => const RoutingConfigScreen(),
        '/settings/crons': (context) => const CronConfigScreen(),
        '/settings/crons/edit': (context) => const CronEditScreen(),
        '/settings/knowledge': (context) => const KnowledgeConfigScreen(),
        '/settings/embedding': (context) => const EmbeddingConfigScreen(),
        '/settings/knowledge-browser': (context) => const KnowledgeBrowserScreen(),
        '/settings/knowledge-entity': (context) => const KnowledgeEntityDetailScreen(),
        '/settings/locale': (context) => const LocaleConfigScreen(),
        '/settings/logs': (context) => const LogsScreen(),
        '/settings/llm-traces': (context) => const LlmTracesScreen(),
        '/settings/llm-trace-detail': (context) => const LlmTraceDetailScreen(),
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
