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
    name: 'web_scrape',
    label: 'Web Scrape',
    description: 'Lightweight page scraping (HTTP + Markdown)',
    icon: Icons.language,
  ),
  _ToolInfo(
    name: 'web_scrape_js',
    label: 'Web Scrape (JS)',
    description: 'Heavy JS-rendered page scraping (WebView)',
    icon: Icons.web,
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
    name: 'get_address',
    label: 'Reverse Geocoding',
    description: 'Convert GPS coordinates to address',
    icon: Icons.pin_drop_outlined,
  ),
  _ToolInfo(
    name: 'subagent',
    label: 'Sub-agent',
    description: 'Spawn sub-tasks for complex queries',
    icon: Icons.account_tree_outlined,
  ),
  _ToolInfo(
    name: 'clipboard',
    label: 'Clipboard',
    description: 'Read and write device clipboard',
    icon: Icons.content_paste,
  ),
  _ToolInfo(
    name: 'device_info',
    label: 'Device Info',
    description: 'Battery, connectivity, device model',
    icon: Icons.phone_android,
  ),
  _ToolInfo(
    name: 'speak',
    label: 'Text to Speech',
    description: 'Speak text aloud (foreground only)',
    icon: Icons.volume_up,
  ),
  _ToolInfo(
    name: 'open_app',
    label: 'Open App / URL',
    description: 'Open URLs, phone, maps, email on device',
    icon: Icons.open_in_new,
  ),
  _ToolInfo(
    name: 'set_alarm',
    label: 'Alarm / Timer',
    description: 'Set alarms and timers via system Clock app',
    icon: Icons.alarm,
  ),
  _ToolInfo(
    name: 'notifications',
    label: 'Notifications',
    description: 'Create and schedule local notifications / reminders',
    icon: Icons.notifications_outlined,
  ),
  _ToolInfo(
    name: 'contacts',
    label: 'Contacts',
    description: 'Search and read device contacts (read-only)',
    icon: Icons.contacts_outlined,
  ),
  _ToolInfo(
    name: 'calendar',
    label: 'Calendar',
    description: 'Read and create calendar events',
    icon: Icons.calendar_month_outlined,
  ),
  _ToolInfo(
    name: 'ocr',
    label: 'OCR',
    description: 'Extract text from images (on-device ML Kit)',
    icon: Icons.document_scanner_outlined,
  ),
  _ToolInfo(
    name: 'qr_generate',
    label: 'QR Code',
    description: 'Generate QR code images from text or URLs',
    icon: Icons.qr_code,
  ),
  _ToolInfo(
    name: 'pick_image',
    label: 'Image Picker',
    description: 'Pick photos from gallery or take with camera',
    icon: Icons.image_outlined,
  ),
  _ToolInfo(
    name: 'volume_control',
    label: 'Volume Control',
    description: 'Read and adjust device volume levels (alarm, media, etc.)',
    icon: Icons.volume_up_outlined,
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
