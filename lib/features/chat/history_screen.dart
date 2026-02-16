import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/session/session.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_provider.dart';
import '../../shared/constants.dart';

/// Screen showing all past conversations.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionManagerAsync = ref.watch(sessionManagerProvider);
    final currentSessionKey = ref.watch(chatProvider).sessionKey;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: sessionManagerAsync.when(
        data: (sm) {
          final allSessions = sm.getAllSessions();
          final chatSessions = allSessions
              .where((s) =>
                  !s.key.startsWith(AppConstants.telegramSessionPrefix) &&
                  !s.key.startsWith(AppConstants.cronSessionPrefix))
              .toList();
          final cronSessions = allSessions
              .where(
                  (s) => s.key.startsWith(AppConstants.cronSessionPrefix))
              .toList();
          final telegramSessions = allSessions
              .where(
                  (s) => s.key.startsWith(AppConstants.telegramSessionPrefix))
              .toList();

          // Group cron sessions by cron ID
          final cronGroups = _groupCronSessions(cronSessions, ref);

          if (chatSessions.isEmpty &&
              cronGroups.isEmpty &&
              telegramSessions.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView(
            children: [
              if (chatSessions.isNotEmpty) ...[
                _SectionHeader(title: 'Chat'),
                ...chatSessions.map((s) => _SessionTile(
                      session: s,
                      isCurrent: s.key == currentSessionKey,
                      onTap: () => _loadSession(context, ref, s.key),
                      onDelete: () => _confirmDelete(context, ref, s),
                    )),
              ],
              if (cronGroups.isNotEmpty) ...[
                _SectionHeader(title: 'Scheduled Prompts'),
                ...cronGroups.entries.map((entry) {
                  final cronName = entry.value.name;
                  final sessions = entry.value.sessions;
                  final lastSession = sessions.first;
                  return ListTile(
                    leading: Icon(Icons.schedule,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(cronName, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${sessions.length} executions - Last: ${_formatDate(lastSession.updated)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (sessions.length == 1) {
                        _loadSession(context, ref, sessions.first.key);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _CronExecutionsScreen(
                              cronName: cronName,
                              sessions: sessions,
                            ),
                          ),
                        );
                      }
                    },
                  );
                }),
              ],
              if (telegramSessions.isNotEmpty) ...[
                _SectionHeader(title: 'Telegram'),
                ...telegramSessions.map((s) => _SessionTile(
                      session: s,
                      isCurrent: s.key == currentSessionKey,
                      isTelegram: true,
                      onTap: () => _loadSession(context, ref, s.key),
                      onDelete: () => _confirmDelete(context, ref, s),
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  /// Group cron sessions by cron ID, with name from config.
  Map<String, _CronGroup> _groupCronSessions(
      List<Session> sessions, WidgetRef ref) {
    final configStorage = ref.read(configStorageProvider);
    final cronDefs = configStorage.getCronDefinitions();
    final cronNameMap = {for (final c in cronDefs) c.id: c.name};

    final groups = <String, _CronGroup>{};
    for (final session in sessions) {
      // Key format: cron_{cronId} or cron_{cronId}_{timestamp}
      final keyWithoutPrefix =
          session.key.substring(AppConstants.cronSessionPrefix.length);
      // Extract cronId (first part before _ if newEach, or entire if sameThread)
      String cronId;
      final underscoreIdx = keyWithoutPrefix.indexOf('_');
      if (underscoreIdx > 0 &&
          keyWithoutPrefix.length > underscoreIdx + 1) {
        // Could be UUID with dashes — check if last part is a timestamp
        final parts = keyWithoutPrefix.split('_');
        final lastPart = parts.last;
        if (int.tryParse(lastPart) != null && lastPart.length > 10) {
          // Last part is a timestamp — cronId is everything before
          cronId = parts.sublist(0, parts.length - 1).join('_');
        } else {
          cronId = keyWithoutPrefix;
        }
      } else {
        cronId = keyWithoutPrefix;
      }

      final name = cronNameMap[cronId] ?? 'Scheduled prompt';
      groups.putIfAbsent(cronId, () => _CronGroup(name: name, sessions: []));
      groups[cronId]!.sessions.add(session);
    }

    return groups;
  }

  void _loadSession(BuildContext context, WidgetRef ref, String key) {
    ref.read(chatProvider.notifier).loadSession(key);
    Navigator.pop(context);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
            'Delete "${_sessionTitle(session)}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(chatProvider.notifier).deleteSession(session.key);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No conversations yet',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _CronGroup {
  final String name;
  final List<Session> sessions;
  _CronGroup({required this.name, required this.sessions});
}

/// Sub-screen showing individual executions of a cron.
class _CronExecutionsScreen extends ConsumerWidget {
  final String cronName;
  final List<Session> sessions;

  const _CronExecutionsScreen({
    required this.cronName,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(cronName)),
      body: ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          return ListTile(
            leading: const Icon(Icons.play_arrow_outlined),
            title: Text(_sessionTitle(session),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${_formatDate(session.updated)} ${DateFormat('HH:mm').format(session.updated)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {
              ref.read(chatProvider.notifier).loadSession(session.key);
              // Pop back to chat (pop this screen + history screen)
              Navigator.of(context)
                ..pop()
                ..pop();
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final bool isCurrent;
  final bool isTelegram;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isCurrent,
    this.isTelegram = false,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userMessageCount = session.messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .length;

    return ListTile(
      selected: isCurrent,
      leading: Icon(
        isTelegram ? Icons.telegram : Icons.chat_outlined,
        color: isCurrent ? theme.colorScheme.primary : null,
      ),
      title: Text(
        _sessionTitle(session),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatDate(session.updated)} - $userMessageCount messages',
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

String _sessionTitle(Session session) {
  final firstUserMsg =
      session.messages.where((m) => m.role == 'user').firstOrNull;
  if (firstUserMsg == null) return 'New conversation';
  final text = firstUserMsg.content.replaceAll('\n', ' ').trim();
  return text.length > 60 ? '${text.substring(0, 60)}...' : text;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sessionDay = DateTime(date.year, date.month, date.day);
  if (sessionDay == today) return 'Today';
  if (sessionDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return DateFormat('MMM d').format(date);
}
