import 'package:intl/intl.dart';

import 'tool.dart';

/// Tool that returns the current date and time.
/// Pure Dart — no API key, no platform channel, service isolate compatible.
class DateTimeTool extends Tool {
  final String locale;

  DateTimeTool({this.locale = 'en'});

  @override
  String get name => 'get_datetime';

  @override
  String get description =>
      'Get the current date and time on the device. '
      'Returns date, time, day of week, timezone, and Unix timestamp.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': <String, dynamic>{},
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final intlLocale = locale == 'fr' ? 'fr_FR' : 'en_US';
    final dayFormat = DateFormat('EEEE', intlLocale);
    final dateFormat = DateFormat('dd MMMM yyyy', intlLocale);
    final timeFormat = DateFormat('HH:mm:ss');

    final dayOfWeek = dayFormat.format(now);
    final date = dateFormat.format(now);
    final time = timeFormat.format(now);
    final timezone = now.timeZoneName;
    final utcOffset = now.timeZoneOffset;
    final offsetStr = '${utcOffset.isNegative ? '-' : '+'}${utcOffset.inHours.abs().toString().padLeft(2, '0')}:${(utcOffset.inMinutes.abs() % 60).toString().padLeft(2, '0')}';
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;

    final forLLM = 'Current date and time:\n'
        'Date: $date\n'
        'Time: $time\n'
        'Day: $dayOfWeek\n'
        'Timezone: $timezone (UTC$offsetStr)\n'
        'Unix timestamp: $timestamp\n'
        'ISO 8601: ${now.toIso8601String()}';

    final forUser = '$dayOfWeek $date, $time ($timezone)';

    return ToolResult.dual(forLLM: forLLM, forUser: forUser);
  }
}
