import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/cron_config.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../providers/background_service_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCrons();
  }

  void _loadCrons() {
    final configStorage = ref.read(configStorageProvider);
    setState(() {
      _crons = configStorage.getCronDefinitions();
    });
  }

  Future<void> _saveCrons() async {
    final configStorage = ref.read(configStorageProvider);
    await configStorage.saveCronDefinitions(_crons);
    // Notify the background service to reload cron definitions
    final bgService = ref.read(backgroundServiceProvider.notifier);
    await bgService.ensureServiceRunning();
  }

  Future<void> _toggleEnabled(int index, bool enabled) async {
    setState(() {
      _crons[index] = _crons[index].copyWith(enabled: enabled);
    });
    await _saveCrons();
  }

  Future<void> _deleteCron(int index) async {
    final l = AppLocalizations.of(context);
    final cron = _crons[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cronDeleteTitle),
        content: Text(l.cronDeleteContent(cron.name)),
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
      setState(() => _crons.removeAt(index));
      await _saveCrons();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final serviceRunning = ref.watch(backgroundServiceProvider).isRunning;

    return Scaffold(
      appBar: AppBar(title: Text(l.cronTitle)),
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
                _buildServiceStatus(context, serviceRunning),
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
                          ? '${cron.schedule.localizedDisplayText(l)} - ${l.cronLastRun(DateFormat('MMM d HH:mm').format(cron.lastRun!))}'
                          : '${cron.schedule.localizedDisplayText(l)} - ${l.cronNeverRan}',
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
                          tooltip: l.cronViewExecutions,
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

  Widget _buildServiceStatus(BuildContext context, bool serviceRunning) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasEnabledCrons = _crons.any((c) => c.enabled);
    final ok = serviceRunning && hasEnabledCrons;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ok
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 20,
            color: ok
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              !hasEnabledCrons
                  ? l.cronNoPromptsEnabled
                  : serviceRunning
                      ? l.cronServiceRunning
                      : l.cronServiceNotRunning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ok
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
    final l = AppLocalizations.of(context);
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
            Text(l.cronEmpty,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l.cronEmptySubtitle,
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
