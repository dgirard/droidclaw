import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/chat/chat_screen.dart';
import 'features/onboarding/onboard_screen.dart';
import 'features/settings/provider_config_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/skills_screen.dart';
import 'features/settings/telegram_config_screen.dart';
import 'providers/app_providers.dart';

/// Root MaterialApp with Material 3 theme and routing.
class DroidClawApp extends ConsumerWidget {
  const DroidClawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configStorage = ref.read(configStorageProvider);
    final initialRoute =
        configStorage.isOnboardingComplete ? '/chat' : '/onboard';

    return MaterialApp(
      title: 'DroidClaw',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      initialRoute: initialRoute,
      routes: {
        '/onboard': (context) => const OnboardScreen(),
        '/chat': (context) => const ChatScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings/provider': (context) => const ProviderConfigScreen(),
        '/settings/skills': (context) => const SkillsScreen(),
        '/settings/telegram': (context) => const TelegramConfigScreen(),
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
