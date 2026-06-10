import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/knowledge/services/knowledge_service.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/data_wiper.dart';
import '../../core/services/llm_trace_logger.dart';
import '../../core/session/isolate_persistence/hive_path_resolver.dart';
import '../../core/session/session.dart';
import '../../core/session/session_manager.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../providers/background_service_provider.dart';
import '../../providers/telegram_provider.dart';
import '../../shared/constants.dart';

/// Settings screen with provider config, skills, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          // Provider section
          _SectionHeader(title: l.settingsSectionProvider),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l.settingsProvider),
            subtitle: Text(config.agent.provider),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/provider'),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: Text(l.settingsModel),
            subtitle: Text(config.agent.model),
          ),

          const Divider(),

          // Agent section
          _SectionHeader(title: l.settingsSectionAgent),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: Text(l.settingsMaxTokens),
            subtitle: Text('${config.agent.maxTokens}'),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat_outlined),
            title: Text(l.settingsTemperature),
            subtitle: Text('${config.agent.temperature}'),
          ),
          ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: Text(l.settingsMaxToolIterations),
            subtitle: Text('${config.agent.maxToolIterations}'),
          ),

          const Divider(),

          // Tools section
          _SectionHeader(title: l.settingsSectionTools),
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: Text(l.settingsManageTools),
            subtitle: Text(l.settingsManageToolsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/tools'),
          ),
          ListTile(
            leading: const Icon(Icons.search_outlined),
            title: Text(l.settingsWebSearch),
            subtitle: Text(l.settingsWebSearchSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/web-search'),
          ),

          ListTile(
            leading: const Icon(Icons.directions_outlined),
            title: Text(l.settingsRouting),
            subtitle: Text(l.settingsRoutingSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/routing'),
          ),

          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l.settingsScheduledPrompts),
            subtitle: Text(l.settingsScheduledPromptsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/crons'),
          ),

          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: Text(l.settingsKnowledge),
            subtitle: Text(l.settingsKnowledgeSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/knowledge'),
          ),

          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(l.settingsEmbedding),
            subtitle: Text(l.settingsEmbeddingSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/embedding'),
          ),

          const Divider(),

          // Channels section
          _SectionHeader(title: l.settingsSectionChannels),
          Builder(
            builder: (context) {
              final telegramState = ref.watch(telegramProvider);
              return ListTile(
                leading: const Icon(Icons.telegram),
                title: Text(l.settingsTelegramBot),
                subtitle: Text(
                  telegramState.isRunning ? l.settingsTelegramRunning : l.settingsTelegramDisabled,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pushNamed(context, '/settings/telegram'),
              );
            },
          ),

          const Divider(),

          // Skills section
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: Text(l.settingsSkills),
            subtitle: Text(l.settingsSkillsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/skills'),
          ),

          // Language section
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l.localeSettingsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/locale'),
          ),

          // Logs
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l.logsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/logs'),
          ),

          // LLM Traces
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: Text(l.settingsLlmTraces),
            subtitle: Text(l.settingsLlmTracesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/llm-traces'),
          ),

          const Divider(),

          // About
          _SectionHeader(title: l.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(l.settingsExportConversations),
            subtitle: Text(l.settingsExportSubtitle),
            onTap: () => _exportConversations(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(AppConstants.appName),
            subtitle: const Text('v${AppConstants.appVersion}'),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l.settingsResetAll,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(l.settingsResetAllSubtitle),
            onTap: () => _resetAllData(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Confirm, then wipe every local data store and return to onboarding.
Future<void> _resetAllData(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.resetConfirmTitle),
      content: Text(l.resetConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.resetConfirmButton),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    // Stop the foreground service first so the service isolate cannot
    // re-cache secrets or write sessions/KB data mid-wipe.
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Best-effort: the service may not be running. The wipe must proceed
      // even if stopping fails — DataWiper deletes the underlying files.
    }

    final storage = ref.read(storageServiceProvider);

    SessionManager? sessions;
    try {
      sessions = await ref.read(sessionManagerProvider.future);
    } catch (_) {
      // If sessions can't be opened (e.g. corrupt Hive box), wipe proceeds
      // without graceful close; DataWiper removes the files directly.
    }

    KnowledgeService? knowledge;
    try {
      knowledge = await ref.read(knowledgeServiceProvider.future);
    } catch (_) {
      // Same as above: a KB that fails to open is wiped at the file level.
    }

    final workspacePath = await storage.workspacePath;
    final wiper = DataWiper(
      storage: storage,
      configStorage: ref.read(configStorageProvider),
      sessions: sessions,
      // File-level fallback for a degraded sessions box (same rationale as
      // knowledgeDbPath): the box file lives in the Hive home directory.
      sessionsBoxPath:
          '${HivePathResolver.hiveDirFromWorkspace(workspacePath)}'
          '/${SessionManager.boxName}',
      knowledge: knowledge,
      knowledgeDbPath: '$workspacePath/${AppConstants.knowledgeDbFilename}',
      workspacePath: workspacePath,
      clearLlmTraces: () => LlmTraceLogger.instance.clearAll(),
      clearLogs: () => AppLogger.instance.clearAll(),
    );
    final failures = await wiper.wipeAll();

    // Rebuild everything downstream from a now-empty config.
    ref.invalidate(appConfigProvider);
    ref.invalidate(sessionManagerProvider);
    ref.invalidate(knowledgeGraphDbProvider);
    ref.invalidate(telegramProvider);
    ref.invalidate(backgroundServiceProvider);

    navigator.pushNamedAndRemoveUntil('/onboard', (route) => false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(failures.isEmpty
            ? l.resetDone
            : l.commonFailed(failures.join(', '))),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.commonFailed(e.toString()))),
    );
  }
}

Future<void> _exportConversations(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  messenger.showSnackBar(SnackBar(content: Text(l.exportProgress)));

  try {
    final sessions = await ref.read(sessionManagerProvider.future);
    // Export needs full histories: decode each session via get() (lazy
    // manager only indexes metadata at startup).
    final allSessions = sessions
        .getAllSessionMetadata()
        .map((m) => sessions.get(m.key))
        .whereType<Session>()
        .toList();

    if (allSessions.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l.exportEmpty)));
      return;
    }

    final export = {
      'app': AppConstants.appName,
      'version': AppConstants.appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sessionCount': allSessions.length,
      'sessions': allSessions.map((s) => s.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(export);
    final dir = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/droidclaw_export_$date.json');
    await file.writeAsString(json);

    messenger.hideCurrentSnackBar();

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );

    messenger.showSnackBar(
      SnackBar(content: Text(l.exportSuccess(allSessions.length))),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(l.exportFailed(e.toString()))),
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
