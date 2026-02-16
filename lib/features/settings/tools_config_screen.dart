import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// Metadata for each toggleable tool.
class _ToolInfo {
  final String name;
  final String label;
  final String description;
  final IconData icon;

  const _ToolInfo({
    required this.name,
    required this.label,
    required this.description,
    required this.icon,
  });
}

const _tools = [
  _ToolInfo(
    name: 'web_search',
    label: 'Web Search',
    description: 'Search the web via Brave API',
    icon: Icons.search,
  ),
  _ToolInfo(
    name: 'web_fetch',
    label: 'Web Fetch',
    description: 'Fetch and read web pages',
    icon: Icons.language,
  ),
  _ToolInfo(
    name: 'file',
    label: 'File Access',
    description: 'Read and write files in workspace',
    icon: Icons.folder_outlined,
  ),
  _ToolInfo(
    name: 'get_location',
    label: 'GPS Location',
    description: 'Access device GPS coordinates',
    icon: Icons.location_on_outlined,
  ),
  _ToolInfo(
    name: 'subagent',
    label: 'Sub-agent',
    description: 'Spawn sub-tasks for complex queries',
    icon: Icons.account_tree_outlined,
  ),
];

/// Screen to enable/disable individual agent tools.
class ToolsConfigScreen extends ConsumerWidget {
  const ToolsConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final disabled = config.tools.disabledTools;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tools')),
      body: ListView.builder(
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final tool = _tools[index];
          final enabled = !disabled.contains(tool.name);

          return SwitchListTile(
            secondary: Icon(tool.icon),
            title: Text(tool.label),
            subtitle: Text(tool.description),
            value: enabled,
            onChanged: (value) => _toggle(ref, tool.name, value),
          );
        },
      ),
    );
  }

  void _toggle(WidgetRef ref, String toolName, bool enabled) {
    final config = ref.read(appConfigProvider);
    final disabled = Set<String>.from(config.tools.disabledTools);
    if (enabled) {
      disabled.remove(toolName);
    } else {
      disabled.add(toolName);
    }
    final newConfig = config.copyWith(
      tools: config.tools.copyWith(disabledTools: disabled),
    );
    ref.read(configStorageProvider).save(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);
  }
}
