import 'package:android_intent_plus/android_intent.dart';

import 'tool.dart';

/// Tool that sets alarms and timers via the system Clock app.
class SetAlarmTool extends Tool {
  @override
  String get name => 'set_alarm';

  @override
  String get description =>
      'Set an alarm or timer on the device using the system Clock app. '
      'The Clock app opens for user confirmation. '
      'Use "alarm" for a specific time, "timer" for a countdown.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['alarm', 'timer'],
            'description': 'Type of alarm to set',
          },
          'hour': {
            'type': 'integer',
            'description': 'Hour (0-23) for alarm type',
          },
          'minutes': {
            'type': 'integer',
            'description': 'Minutes (0-59) for alarm type',
          },
          'message': {
            'type': 'string',
            'description': 'Label or message for the alarm/timer',
          },
          'duration_seconds': {
            'type': 'integer',
            'description': 'Duration in seconds for timer type',
          },
        },
        'required': ['type'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final type = arguments['type'] as String?;
    if (type == null) {
      return ToolResult.error('Missing required parameter: type');
    }

    try {
      switch (type) {
        case 'alarm':
          return await _setAlarm(arguments);
        case 'timer':
          return await _setTimer(arguments);
        default:
          return ToolResult.error(
              'Unknown type: $type. Use "alarm" or "timer".');
      }
    } catch (e) {
      return ToolResult.error('Failed to set $type: $e');
    }
  }

  Future<ToolResult> _setAlarm(Map<String, dynamic> arguments) async {
    final hour = arguments['hour'] as int?;
    final minutes = arguments['minutes'] as int?;
    if (hour == null || minutes == null) {
      return ToolResult.error(
          'Alarm requires "hour" (0-23) and "minutes" (0-59).');
    }
    if (hour < 0 || hour > 23) {
      return ToolResult.error('Invalid hour: $hour. Must be 0-23.');
    }
    if (minutes < 0 || minutes > 59) {
      return ToolResult.error('Invalid minutes: $minutes. Must be 0-59.');
    }

    final message = arguments['message'] as String? ?? '';
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minutes,
        if (message.isNotEmpty)
          'android.intent.extra.alarm.MESSAGE': message,
      },
    );
    await intent.launch();

    return ToolResult.dual(
      forLLM: 'Alarm requested for $timeStr'
          '${message.isNotEmpty ? " ($message)" : ""}. '
          'The Clock app opened for user confirmation.',
      forUser: 'Alarm $timeStr — confirm in Clock app',
    );
  }

  Future<ToolResult> _setTimer(Map<String, dynamic> arguments) async {
    final seconds = arguments['duration_seconds'] as int?;
    if (seconds == null || seconds <= 0) {
      return ToolResult.error('Timer requires "duration_seconds" > 0.');
    }

    final message = arguments['message'] as String? ?? '';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final durationStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_TIMER',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.LENGTH': seconds,
        if (message.isNotEmpty)
          'android.intent.extra.alarm.MESSAGE': message,
      },
    );
    await intent.launch();

    return ToolResult.dual(
      forLLM: 'Timer requested for $durationStr'
          '${message.isNotEmpty ? " ($message)" : ""}. '
          'The Clock app opened for user confirmation.',
      forUser: 'Timer $durationStr — confirm in Clock app',
    );
  }
}
