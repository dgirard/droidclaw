import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
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
  bool _testPassed = false;

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
    final l = AppLocalizations.of(context);
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _testResult = l.telegramEnterTokenError;
        _testPassed = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testPassed = false;
    });

    try {
      final username =
          await ref.read(telegramProvider.notifier).testConnection(token);
      setState(() {
        _testResult = l.telegramTestSuccess(username);
        _testPassed = true;
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testResult = l.commonFailed(e.toString());
        _testPassed = false;
        _testing = false;
      });
    }
  }

  Future<void> _toggleBot(bool enable) async {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(telegramProvider.notifier);

    if (enable) {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.telegramEnterToken)),
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
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.telegramUsersUpdated)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final telegramState = ref.watch(telegramProvider);
    final theme = Theme.of(context);
    final hasToken = _tokenController.text.trim().isNotEmpty;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.telegramTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          if (telegramState.isRunning) _buildStatusCard(context, telegramState, theme),

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
              labelText: l.telegramBotToken,
              helperText: l.telegramBotTokenHelper,
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
                : Text(l.telegramTestConnection),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResult!,
              style: TextStyle(
                color: _testPassed ? Colors.green : Colors.red,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Enable/disable toggle
          SwitchListTile(
            title: Text(l.telegramEnableBot),
            subtitle: Text(
              telegramState.isRunning
                  ? l.telegramBotRunning
                  : telegramState.isEnabled
                      ? l.telegramBotStarting
                      : l.telegramBotDisabled,
            ),
            value: telegramState.isEnabled,
            onChanged: hasToken ? _toggleBot : null,
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(height: 32),

          // Allowed users
          TextField(
            controller: _allowedUsersController,
            decoration: InputDecoration(
              labelText: l.telegramAllowedUsers,
              helperText: l.telegramAllowedUsersHelper,
              hintText: l.telegramAllowedUsersHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveAllowedUsers(),
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saveAllowedUsers,
              child: Text(l.telegramSaveUsers),
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
                Text(l.telegramHowToSetup, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(l.telegramSetupSteps),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, TelegramState state, ThemeData theme) {
    final l = AppLocalizations.of(context);
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
                  l.telegramBotActive,
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
                  label: l.telegramMessages(state.messageCount),
                ),
                const SizedBox(width: 12),
                if (state.lastMessageTime != null)
                  _StatChip(
                    icon: Icons.access_time,
                    label: l.telegramLastMessage(
                        timeFormat.format(state.lastMessageTime!)),
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
