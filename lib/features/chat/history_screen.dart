import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/session/session_metadata.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../providers/background_service_provider.dart';
import '../../providers/chat_provider.dart';
import '../../shared/constants.dart';

/// Screen showing all past conversations, split into tabs.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionManagerAsync = ref.watch(sessionManagerProvider);
    final currentSessionKey = ref.watch(chatProvider).sessionKey;
    // Rebuild when cron executions complete (sessions updated by service isolate)
    ref.watch(backgroundServiceProvider.select((s) => s.cronCompletionCount));
    final l = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.historyTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.historyTabConversations),
              Tab(text: l.historyTabScheduled),
            ],
          ),
        ),
        body: sessionManagerAsync.when(
          data: (sm) {
            final allSessions = sm.getAllSessionMetadata();
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

            final cronGroups = _groupCronSessions(cronSessions, ref);

            return TabBarView(
              children: [
                // Tab 0: Conversations (chat + telegram)
                _buildConversationsTab(
                  context, ref, l,
                  chatSessions, telegramSessions, currentSessionKey,
                ),
                // Tab 1: Scheduled Tasks (cron)
                _buildScheduledTab(context, ref, l, cronGroups),
              ],
            );
          },
          loading: () => TabBarView(
            children: [
              const Center(child: CircularProgressIndicator()),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => TabBarView(
            children: [
              Center(child: Text(l.historyError(e.toString()))),
              Center(child: Text(l.historyError(e.toString()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsTab(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    List<SessionMetadata> chatSessions,
    List<SessionMetadata> telegramSessions,
    String currentSessionKey,
  ) {
    if (chatSessions.isEmpty && telegramSessions.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.chat_bubble_outline,
        message: l.historyEmpty,
      );
    }

    // Precompute the flat row list once per build (cheap descriptors, no
    // widgets); tiles are then created lazily by ListView.builder so only
    // visible rows are instantiated.
    final rows = <_ConversationRow>[
      if (chatSessions.isNotEmpty) ...[
        _HeaderRow(l.historySectionChat),
        for (final s in chatSessions) _SessionRow(s, isTelegram: false),
      ],
      if (telegramSessions.isNotEmpty) ...[
        _HeaderRow(l.historySectionTelegram),
        for (final s in telegramSessions) _SessionRow(s, isTelegram: true),
      ],
    ];

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        _HeaderRow(:final title) => _SectionHeader(title: title),
        _SessionRow(:final session, :final isTelegram) => _SessionTile(
            session: session,
            isCurrent: session.key == currentSessionKey,
            isTelegram: isTelegram,
            onTap: () => _loadSession(context, ref, session.key),
            onDelete: () => _confirmDelete(context, ref, session),
          ),
      },
    );
  }

  Widget _buildScheduledTab(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    Map<String, _CronGroup> cronGroups,
  ) {
    if (cronGroups.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.schedule,
        message: l.historyEmptyScheduled,
      );
    }

    // Group list precomputed once per build; tiles built lazily.
    final groups = cronGroups.values.toList();

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final cronName = group.name;
        final sessions = group.sessions;
        final lastSession = sessions.first;
        final prompt = group.prompt;
        return ListTile(
          leading: Icon(Icons.schedule,
              color: Theme.of(context).colorScheme.primary),
          title:
              Text(cronName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            l.historyExecutions(
                sessions.length, _formatDate(context, lastSession.updated)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prompt != null)
                IconButton(
                  icon: Icon(Icons.play_arrow,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary),
                  tooltip: l.cronRunNow,
                  onPressed: () => runCronNow(context, ref, prompt),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDeleteCronGroup(
                    context, ref, cronName, sessions),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {
            if (sessions.length == 1) {
              _loadSession(context, ref, sessions.first.key);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CronExecutionsScreen(
                    cronName: cronName,
                    sessions: sessions,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  /// Group cron sessions by cron ID, with name and prompt from config.
  Map<String, _CronGroup> _groupCronSessions(
      List<SessionMetadata> sessions, WidgetRef ref) {
    final configStorage = ref.read(configStorageProvider);
    final cronDefs = configStorage.getCronDefinitions();
    final cronNameMap = {for (final c in cronDefs) c.id: c.name};
    final cronPromptMap = {for (final c in cronDefs) c.id: c.prompt};

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

      final name = cronNameMap[cronId] ?? cronId;
      groups.putIfAbsent(
          cronId,
          () => _CronGroup(
              name: name, prompt: cronPromptMap[cronId], sessions: []));
      groups[cronId]!.sessions.add(session);
    }

    return groups;
  }

  void _loadSession(BuildContext context, WidgetRef ref, String key) {
    ref.read(chatProvider.notifier).loadSession(key);
    Navigator.pop(context);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SessionMetadata session) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.historyDeleteTitle),
        content: Text(l.historyDeleteContent(_sessionTitle(session))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(chatProvider.notifier).deleteSession(session.key);
    }
  }

  Future<void> _confirmDeleteCronGroup(BuildContext context, WidgetRef ref,
      String cronName, List<SessionMetadata> sessions) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cronDeleteGroup),
        content: Text(l.cronDeleteGroupCount(sessions.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (confirmed == true) {
      final chatNotifier = ref.read(chatProvider.notifier);
      for (final session in sessions) {
        chatNotifier.deleteSession(session.key);
      }
    }
  }

  Widget _buildEmptyState(BuildContext context,
      {required IconData icon, required String message}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _CronGroup {
  final String name;
  final String? prompt;
  final List<SessionMetadata> sessions;
  _CronGroup({required this.name, this.prompt, required this.sessions});
}

/// Lightweight row descriptor for the conversations tab, so the flat list
/// (headers + tiles) is computed once per build and rendered lazily.
sealed class _ConversationRow {
  const _ConversationRow();
}

class _HeaderRow extends _ConversationRow {
  final String title;
  const _HeaderRow(this.title);
}

class _SessionRow extends _ConversationRow {
  final SessionMetadata session;
  final bool isTelegram;
  const _SessionRow(this.session, {required this.isTelegram});
}

/// Sub-screen showing individual executions of a cron.
class CronExecutionsScreen extends ConsumerStatefulWidget {
  final String cronName;
  final List<SessionMetadata> sessions;
  final int popCount;

  const CronExecutionsScreen({
    super.key,
    required this.cronName,
    required this.sessions,
    this.popCount = 2,
  });

  @override
  ConsumerState<CronExecutionsScreen> createState() =>
      _CronExecutionsScreenState();
}

class _CronExecutionsScreenState extends ConsumerState<CronExecutionsScreen> {
  late final List<SessionMetadata> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.of(widget.sessions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cronName)),
      body: _sessions.isEmpty
          ? Center(
              child: Text(AppLocalizations.of(context).historyNoExecutions,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
            )
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return ListTile(
                  leading: const Icon(Icons.play_arrow_outlined),
                  title: Text(_sessionTitle(session),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_formatDate(context, session.updated)} ${_timeFormat.format(session.updated)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () =>
                        _confirmDeleteExecution(context, session),
                  ),
                  onTap: () {
                    ref
                        .read(chatProvider.notifier)
                        .loadSession(session.key);
                    for (var i = 0; i < widget.popCount; i++) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
    );
  }

  Future<void> _confirmDeleteExecution(
      BuildContext context, SessionMetadata session) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cronDeleteExecution),
        content: Text(_sessionTitle(session)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(chatProvider.notifier).deleteSession(session.key);
      if (mounted) setState(() => _sessions.remove(session));
    }
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
  final SessionMetadata session;
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
    final userMessageCount = session.conversationMessageCount;

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
        '${_formatDate(context, session.updated)} - ${AppLocalizations.of(context).historyMessages(userMessageCount)}',
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

/// Start a new chat session with the given prompt and navigate to chat.
/// Shared by CronConfigScreen and HistoryScreen "Run Now" buttons.
Future<void> runCronNow(
    BuildContext context, WidgetRef ref, String prompt) async {
  final navigator = Navigator.of(context);
  final chatNotifier = ref.read(chatProvider.notifier);
  await chatNotifier.newSession();
  chatNotifier.sendMessage(prompt);
  navigator.pushNamedAndRemoveUntil('/chat', (route) => false);
}

// Hoisted formatters: never allocate DateFormat inside per-item builders.
final DateFormat _timeFormat = DateFormat('HH:mm');
final DateFormat _monthDayFormat = DateFormat('MMM d');

String _sessionTitle(SessionMetadata session) {
  // Previews are pre-normalized at save time (SessionMetadata.fromSession).
  final text = session.preview ?? session.summaryPreview;
  if (text != null) {
    return text.length > 60 ? '${text.substring(0, 60)}...' : text;
  }
  return session.key;
}

String _formatDate(BuildContext context, DateTime date) {
  final l = AppLocalizations.of(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sessionDay = DateTime(date.year, date.month, date.day);
  if (sessionDay == today) return l.historyToday;
  if (sessionDay == today.subtract(const Duration(days: 1))) {
    return l.historyYesterday;
  }
  return _monthDayFormat.format(date);
}
