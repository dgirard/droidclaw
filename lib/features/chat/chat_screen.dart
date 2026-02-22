import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_provider.dart';
import 'agent_status_indicator.dart';
import 'input_bar.dart';
import 'message_bubble.dart';

/// Main chat screen.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final chatNotifier = ref.read(chatProvider.notifier);

    // Auto-scroll when messages change
    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).chatTitle),
        actions: [
          _LocaleSwitcher(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppLocalizations.of(context).chatConversations,
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: AppLocalizations.of(context).chatNewSession,
            onPressed: () => chatNotifier.newSession(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context).chatSettings,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(
                          message: chatState.messages[index]);
                    },
                  ),
          ),

          // Agent status
          if (chatState.isProcessing)
            AgentStatusIndicator(event: chatState.currentEvent),

          // Input bar
          InputBar(
            onSend: (text) => chatNotifier.sendMessage(text),
            enabled: !chatState.isProcessing,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l.chatEmptyTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.chatEmptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact locale switcher: shows current language flag, tap to cycle.
class _LocaleSwitcher extends ConsumerWidget {
  static const _locales = ['system', 'en', 'fr', 'es', 'de', 'it'];

  static String _flag(String locale) => switch (locale) {
        'en' => '\u{1F1EC}\u{1F1E7}',
        'fr' => '\u{1F1EB}\u{1F1F7}',
        'es' => '\u{1F1EA}\u{1F1F8}',
        'de' => '\u{1F1E9}\u{1F1EA}',
        'it' => '\u{1F1EE}\u{1F1F9}',
        _ => '\u{1F310}', // globe for system
      };

  static String _label(String locale) => switch (locale) {
        'en' => 'English',
        'fr' => 'Français',
        'es' => 'Español',
        'de' => 'Deutsch',
        'it' => 'Italiano',
        _ => 'System',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final current = config.locale;
    final resolved = config.resolvedLocale;
    // Show the resolved flag (actual language), but with a globe overlay for 'system'
    final displayFlag =
        current == 'system' ? _flag('system') : _flag(resolved);

    return PopupMenuButton<String>(
      tooltip: AppLocalizations.of(context).localeSettingsTitle,
      onSelected: (locale) {
        final newConfig = config.copyWith(locale: locale);
        ref.read(configStorageProvider).save(newConfig);
        ref.read(appConfigProvider.notifier).update(newConfig);
      },
      itemBuilder: (context) => _locales.map((locale) {
        return PopupMenuItem<String>(
          value: locale,
          child: Row(
            children: [
              Text(_flag(locale), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(_label(locale)),
              if (locale == current) ...[
                const Spacer(),
                Icon(Icons.check,
                    size: 18, color: Theme.of(context).colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(displayFlag, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
