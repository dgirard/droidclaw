import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
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
        ],
      ),
    );
  }
}

Future<void> _exportConversations(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  messenger.showSnackBar(SnackBar(content: Text(l.exportProgress)));

  try {
    final sessions = await ref.read(sessionManagerProvider.future);
    final allSessions = sessions.getAllSessions();

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
