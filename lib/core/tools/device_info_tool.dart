import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../l10n/l10n.dart';
import 'tool.dart';

/// Tool that returns device information: battery, connectivity, and hardware.
class DeviceInfoTool extends Tool {
  final String locale;

  DeviceInfoTool({this.locale = 'en'});

  @override
  String get name => 'device_info';

  @override
  String get description =>
      'Get device information: battery level and charging status, '
      'network connectivity type, device model, manufacturer, and Android version.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final parts = <String>[];
    final userParts = <String>[];

    // Battery
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      final l = tr(locale);
      final stateStr = switch (state) {
        BatteryState.charging => l.batteryCharging,
        BatteryState.discharging => l.batteryDischarging,
        BatteryState.full => l.batteryFull,
        BatteryState.connectedNotCharging => l.batteryConnectedNotCharging,
        _ => l.batteryUnknown,
      };
      parts.add('Battery: $level% ($stateStr)');
      userParts.add('Battery: $level% ($stateStr)');
    } catch (e) {
      parts.add('Battery: unavailable ($e)');
    }

    // Connectivity
    try {
      final results = await Connectivity().checkConnectivity();
      final types = results.map((r) => r.name).join(', ');
      parts.add('Connectivity: $types');
      userParts.add('Network: $types');
    } catch (e) {
      parts.add('Connectivity: unavailable ($e)');
    }

    // Device info
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      parts.add('Device: ${info.manufacturer} ${info.model}');
      parts.add(
          'Android: ${info.version.release} (SDK ${info.version.sdkInt})');
      parts.add('Product: ${info.product}');
      userParts.add(
          '${info.manufacturer} ${info.model} — Android ${info.version.release}');
    } catch (e) {
      parts.add('Device info: unavailable ($e)');
    }

    if (parts.isEmpty) {
      return ToolResult.error('Failed to retrieve any device information.');
    }

    return ToolResult.dual(
      forLLM: parts.join('\n'),
      forUser: userParts.join(' | '),
    );
  }
}
