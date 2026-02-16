import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../providers/telegram_provider.dart';
import '../../shared/constants.dart';

/// Settings screen for Telegram bot configuration.
class TelegramConfigScreen extends ConsumerStatefulWidget {
  const TelegramConfigScreen({super.key});

  @override
  ConsumerState<TelegramConfigScreen> createState() =>
      _TelegramConfigScreenState();
}

class _TelegramConfigScreenState extends ConsumerState<TelegramConfigScreen> {
  final _tokenController = TextEditingController();
  final _allowedUsersController = TextEditingController();
  bool _obscureToken = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final storage = ref.read(storageServiceProvider);
    final token =
        await storage.getSecure(AppConstants.telegramBotTokenKey) ?? '';
    final allowedUsers =
        storage.getString(AppConstants.telegramAllowedUsersKey) ?? '';

    setState(() {
      _tokenController.text = token;
      _allowedUsersController.text = allowedUsers;
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _allowedUsersController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _testResult = 'Please enter a bot token');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final username =
          await ref.read(telegramProvider.notifier).testConnection(token);
      setState(() {
        _testResult = 'Connected! Bot: @$username';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testResult = 'Failed: $e';
        _testing = false;
      });
    }
  }

  Future<void> _toggleBot(bool enable) async {
    final notifier = ref.read(telegramProvider.notifier);

    if (enable) {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a bot token first')),
        );
        return;
      }

      // Save allowed users before enabling
      await notifier.setAllowedUsers(_allowedUsersController.text.trim());
      await notifier.enable(token);
    } else {
      await notifier.disable();
    }
  }

  Future<void> _saveAllowedUsers() async {
    await ref
        .read(telegramProvider.notifier)
        .setAllowedUsers(_allowedUsersController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allowed users updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final telegramState = ref.watch(telegramProvider);
    final theme = Theme.of(context);
    final hasToken = _tokenController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Telegram Bot')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          if (telegramState.isRunning) _buildStatusCard(telegramState, theme),

          // Error display
          if (telegramState.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      telegramState.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Bot token
          TextField(
            controller: _tokenController,
            obscureText: _obscureToken,
            decoration: InputDecoration(
              labelText: 'Bot Token',
              helperText: 'Get one from @BotFather on Telegram',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureToken ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscureToken = !_obscureToken),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Test connection
          FilledButton.tonal(
            onPressed: _testing ? null : _testConnection,
            child: _testing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test Connection'),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResult!,
              style: TextStyle(
                color: _testResult!.startsWith('Connected')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Enable/disable toggle
          SwitchListTile(
            title: const Text('Enable Bot'),
            subtitle: Text(
              telegramState.isRunning
                  ? 'Bot is running'
                  : telegramState.isEnabled
                      ? 'Starting...'
                      : 'Bot is disabled',
            ),
            value: telegramState.isEnabled,
            onChanged: hasToken ? _toggleBot : null,
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(height: 32),

          // Allowed users
          TextField(
            controller: _allowedUsersController,
            decoration: const InputDecoration(
              labelText: 'Allowed Users (optional)',
              helperText:
                  'Comma-separated Telegram usernames. Leave empty for all.',
              hintText: 'alice, bob, charlie',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveAllowedUsers(),
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saveAllowedUsers,
              child: const Text('Save Users'),
            ),
          ),

          const SizedBox(height: 24),

          // Help text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to set up', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                const Text(
                  '1. Open Telegram and search for @BotFather\n'
                  '2. Send /newbot and follow the instructions\n'
                  '3. Copy the bot token and paste it above\n'
                  '4. Test the connection, then enable the bot\n'
                  '5. Send a message to your bot on Telegram!',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(TelegramState state, ThemeData theme) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bot Active',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.green,
                  ),
                ),
                if (state.botUsername != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '@${state.botUsername}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  icon: Icons.message_outlined,
                  label: '${state.messageCount} messages',
                ),
                const SizedBox(width: 12),
                if (state.lastMessageTime != null)
                  _StatChip(
                    icon: Icons.access_time,
                    label:
                        'Last: ${timeFormat.format(state.lastMessageTime!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
