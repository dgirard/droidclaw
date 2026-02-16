import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/cron_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/telegram_provider.dart';
import '../../shared/constants.dart';
import '../chat/history_screen.dart';

/// Screen listing all configured crons with add/edit/delete.
class CronConfigScreen extends ConsumerStatefulWidget {
  const CronConfigScreen({super.key});

  @override
  ConsumerState<CronConfigScreen> createState() => _CronConfigScreenState();
}

class _CronConfigScreenState extends ConsumerState<CronConfigScreen> {
  List<CronDefinition> _crons = [];
  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();
    _loadCrons();
    _checkServiceStatus();
  }

  void _loadCrons() {
    final configStorage = ref.read(configStorageProvider);
    setState(() {
      _crons = configStorage.getCronDefinitions();
    });
  }

  Future<void> _checkServiceStatus() async {
    final running = await FlutterForegroundTask.isRunningService;
    if (mounted) setState(() => _serviceRunning = running);
  }

  Future<void> _saveCrons() async {
    final configStorage = ref.read(configStorageProvider);
    await configStorage.saveCronDefinitions(_crons);
    // Notify the background service to reload cron definitions
    final telegramNotifier = ref.read(telegramProvider.notifier);
    await telegramNotifier.ensureServiceRunning();
  }

  Future<void> _toggleEnabled(int index, bool enabled) async {
    setState(() {
      _crons[index] = _crons[index].copyWith(enabled: enabled);
    });
    await _saveCrons();
  }

  Future<void> _deleteCron(int index) async {
    final cron = _crons[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete scheduled prompt?'),
        content: Text('Delete "${cron.name}"? This cannot be undone.'),
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
      setState(() => _crons.removeAt(index));
      await _saveCrons();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Prompts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/settings/crons/edit',
          );
          if (result is CronDefinition) {
            setState(() => _crons.add(result));
            await _saveCrons();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _crons.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              children: [
                _buildServiceStatus(context),
                ...List.generate(_crons.length, (index) {
                  final cron = _crons[index];
                  final hasRun = cron.lastRun != null;
                  return ListTile(
                    leading: Icon(
                      Icons.schedule,
                      color: cron.enabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    title: Text(cron.name),
                    subtitle: Text(
                      hasRun
                          ? '${cron.schedule.displayText} - Last: ${DateFormat('MMM d HH:mm').format(cron.lastRun!)}'
                          : '${cron.schedule.displayText} - Never ran',
                      style: !hasRun && cron.enabled
                          ? TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error)
                          : null,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history, size: 20),
                          tooltip: 'View executions',
                          onPressed: () => _viewExecutions(cron),
                        ),
                        Switch(
                          value: cron.enabled,
                          onChanged: (v) => _toggleEnabled(index, v),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteCron(index),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/settings/crons/edit',
                        arguments: cron,
                      );
                      if (result is CronDefinition) {
                        setState(() => _crons[index] = result);
                        await _saveCrons();
                      }
                    },
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildServiceStatus(BuildContext context) {
    final theme = Theme.of(context);
    final hasEnabledCrons = _crons.any((c) => c.enabled);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _serviceRunning && hasEnabledCrons
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _serviceRunning && hasEnabledCrons
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            size: 20,
            color: _serviceRunning && hasEnabledCrons
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              !hasEnabledCrons
                  ? 'No prompts enabled'
                  : _serviceRunning
                      ? 'Background service running'
                      : 'Background service not running',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _serviceRunning && hasEnabledCrons
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewExecutions(CronDefinition cron) async {
    final sm = await ref.read(sessionManagerProvider.future);

    final prefix = '${AppConstants.cronSessionPrefix}${cron.id}';
    final allSessions = sm.getAllSessions();
    final cronSessions = allSessions
        .where((s) => s.key.startsWith(prefix))
        .toList()
      ..sort((a, b) => b.updated.compareTo(a.updated));

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CronExecutionsScreen(
          cronName: cron.name,
          sessions: cronSessions,
          popCount: 1,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No scheduled prompts',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a recurring prompt.\n'
              'The AI will run it automatically on schedule.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
