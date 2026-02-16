import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/telegram_provider.dart';
import '../../shared/constants.dart';

/// Settings screen with provider config, skills, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Provider section
          _SectionHeader(title: 'LLM Provider'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Provider'),
            subtitle: Text(config.agent.provider),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/provider'),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Model'),
            subtitle: Text(config.agent.model),
          ),

          const Divider(),

          // Agent section
          _SectionHeader(title: 'Agent'),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Max tokens'),
            subtitle: Text('${config.agent.maxTokens}'),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat_outlined),
            title: const Text('Temperature'),
            subtitle: Text('${config.agent.temperature}'),
          ),
          ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: const Text('Max tool iterations'),
            subtitle: Text('${config.agent.maxToolIterations}'),
          ),

          const Divider(),

          // Tools section
          _SectionHeader(title: 'Tools'),
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: const Text('Manage Tools'),
            subtitle: const Text('Enable or disable agent tools'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/tools'),
          ),
          ListTile(
            leading: const Icon(Icons.search_outlined),
            title: const Text('Web Search'),
            subtitle: Text(
              config.tools.webSearchMaxResults > 0
                  ? 'Configure Brave Search API'
                  : 'Configure Brave Search API',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/web-search'),
          ),

          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Scheduled Prompts'),
            subtitle: const Text('Automated recurring tasks'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, '/settings/crons'),
          ),

          const Divider(),

          // Telegram section
          _SectionHeader(title: 'Channels'),
          Builder(
            builder: (context) {
              final telegramState = ref.watch(telegramProvider);
              return ListTile(
                leading: const Icon(Icons.telegram),
                title: const Text('Telegram Bot'),
                subtitle: Text(
                  telegramState.isRunning ? 'Running' : 'Disabled',
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
            title: const Text('Skills'),
            subtitle: const Text('Manage installed skills'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/skills'),
          ),

          const Divider(),

          // About
          _SectionHeader(title: 'About'),
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
