import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
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

List<_ToolInfo> _tools(AppLocalizations l) => [
  _ToolInfo(
    name: 'web_search',
    label: l.toolWebSearch,
    description: l.toolWebSearchDesc,
    icon: Icons.search,
  ),
  _ToolInfo(
    name: 'web_scrape',
    label: l.toolWebScrape,
    description: l.toolWebScrapeDesc,
    icon: Icons.language,
  ),
  _ToolInfo(
    name: 'web_scrape_js',
    label: l.toolWebScrapeJs,
    description: l.toolWebScrapeJsDesc,
    icon: Icons.web,
  ),
  _ToolInfo(
    name: 'file',
    label: l.toolFile,
    description: l.toolFileDesc,
    icon: Icons.folder_outlined,
  ),
  _ToolInfo(
    name: 'get_location',
    label: l.toolLocation,
    description: l.toolLocationDesc,
    icon: Icons.location_on_outlined,
  ),
  _ToolInfo(
    name: 'get_address',
    label: l.toolAddress,
    description: l.toolAddressDesc,
    icon: Icons.pin_drop_outlined,
  ),
  _ToolInfo(
    name: 'subagent',
    label: l.toolSubagent,
    description: l.toolSubagentDesc,
    icon: Icons.account_tree_outlined,
  ),
  _ToolInfo(
    name: 'clipboard',
    label: l.toolClipboard,
    description: l.toolClipboardDesc,
    icon: Icons.content_paste,
  ),
  _ToolInfo(
    name: 'get_datetime',
    label: l.toolDatetime,
    description: l.toolDatetimeDesc,
    icon: Icons.schedule,
  ),
  _ToolInfo(
    name: 'device_info',
    label: l.toolDeviceInfo,
    description: l.toolDeviceInfoDesc,
    icon: Icons.phone_android,
  ),
  _ToolInfo(
    name: 'speak',
    label: l.toolSpeak,
    description: l.toolSpeakDesc,
    icon: Icons.volume_up,
  ),
  _ToolInfo(
    name: 'open_app',
    label: l.toolOpenApp,
    description: l.toolOpenAppDesc,
    icon: Icons.open_in_new,
  ),
  _ToolInfo(
    name: 'set_alarm',
    label: l.toolAlarm,
    description: l.toolAlarmDesc,
    icon: Icons.alarm,
  ),
  _ToolInfo(
    name: 'notifications',
    label: l.toolNotifications,
    description: l.toolNotificationsDesc,
    icon: Icons.notifications_outlined,
  ),
  _ToolInfo(
    name: 'contacts',
    label: l.toolContacts,
    description: l.toolContactsDesc,
    icon: Icons.contacts_outlined,
  ),
  _ToolInfo(
    name: 'calendar',
    label: l.toolCalendar,
    description: l.toolCalendarDesc,
    icon: Icons.calendar_month_outlined,
  ),
  _ToolInfo(
    name: 'ocr',
    label: l.toolOcr,
    description: l.toolOcrDesc,
    icon: Icons.document_scanner_outlined,
  ),
  _ToolInfo(
    name: 'qr_generate',
    label: l.toolQrGenerate,
    description: l.toolQrGenerateDesc,
    icon: Icons.qr_code,
  ),
  _ToolInfo(
    name: 'pick_image',
    label: l.toolPickImage,
    description: l.toolPickImageDesc,
    icon: Icons.image_outlined,
  ),
  _ToolInfo(
    name: 'volume_control',
    label: l.toolVolumeControl,
    description: l.toolVolumeControlDesc,
    icon: Icons.volume_up_outlined,
  ),
  _ToolInfo(
    name: 'geocode',
    label: l.toolGeocode,
    description: l.toolGeocodeDesc,
    icon: Icons.location_searching,
  ),
  _ToolInfo(
    name: 'get_directions',
    label: l.toolDirections,
    description: l.toolDirectionsDesc,
    icon: Icons.directions_outlined,
  ),
  _ToolInfo(
    name: 'get_transit',
    label: l.toolTransit,
    description: l.toolTransitDesc,
    icon: Icons.directions_transit_outlined,
  ),
  _ToolInfo(
    name: 'weather',
    label: l.toolWeather,
    description: l.toolWeatherDesc,
    icon: Icons.cloud_outlined,
  ),
];

/// Screen to enable/disable individual agent tools.
class ToolsConfigScreen extends ConsumerWidget {
  const ToolsConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final disabled = config.tools.disabledTools;
    final tools = _tools(AppLocalizations.of(context));

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).toolsTitle)),
      body: ListView.builder(
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
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
