import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'tool.dart';

/// Tool that creates and manages local notifications and reminders.
class NotificationsTool extends Tool {
  final bool canRequestPermission;
  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  NotificationsTool({this.canRequestPermission = true});

  @override
  String get name => 'notifications';

  @override
  String get description =>
      'Create, schedule, cancel, or list local notifications. '
      'Use for reminders like "remind me at 3pm to call the dentist". '
      'Different from crons — notifications are lightweight user-facing alerts.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['show', 'schedule', 'cancel', 'list'],
            'description':
                'show: instant notification, schedule: at a future time, '
                    'cancel: remove by id, list: show pending',
          },
          'title': {
            'type': 'string',
            'description':
                'Notification title (required for show and schedule)',
          },
          'body': {
            'type': 'string',
            'description':
                'Notification body text (required for show and schedule)',
          },
          'schedule_at': {
            'type': 'string',
            'description':
                'ISO 8601 local datetime for schedule operation. '
                    'Example: 2026-02-17T15:00:00',
          },
          'id': {
            'type': 'integer',
            'description':
                'Notification ID for cancel; auto-generated for show/schedule',
          },
        },
        'required': ['operation'],
      };

  Future<FlutterLocalNotificationsPlugin> _getPlugin() async {
    if (_initialized && _plugin != null) return _plugin!;

    tz.initializeTimeZones();

    _plugin = FlutterLocalNotificationsPlugin();
    await _plugin!.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
    return _plugin!;
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) {
      return ToolResult.error('Missing required parameter: operation');
    }

    try {
      final plugin = await _getPlugin();

      switch (operation) {
        case 'show':
          return await _show(plugin, arguments);
        case 'schedule':
          return await _schedule(plugin, arguments);
        case 'cancel':
          return await _cancel(plugin, arguments);
        case 'list':
          return await _list(plugin);
        default:
          return ToolResult.error(
              'Unknown operation: $operation. '
              'Use show, schedule, cancel, or list.');
      }
    } catch (e) {
      return ToolResult.error('Notification operation failed: $e');
    }
  }

  Future<ToolResult> _show(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> arguments,
  ) async {
    final title = arguments['title'] as String?;
    final body = arguments['body'] as String?;
    if (title == null || body == null) {
      return ToolResult.error(
          'Missing required parameters: title and body');
    }

    final id = (arguments['id'] as int?) ??
        DateTime.now().millisecondsSinceEpoch % 100000;

    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'droidclaw_default',
          'DroidClaw Notifications',
          channelDescription: 'Notifications from DroidClaw assistant',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    return ToolResult.dual(
      forLLM: 'Notification shown: id=$id, title="$title"',
      forUser: 'Notification: $title',
    );
  }

  Future<ToolResult> _schedule(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> arguments,
  ) async {
    final title = arguments['title'] as String?;
    final body = arguments['body'] as String?;
    final scheduleAt = arguments['schedule_at'] as String?;
    if (title == null || body == null || scheduleAt == null) {
      return ToolResult.error(
          'Missing required parameters: title, body, schedule_at');
    }

    final dateTime = DateTime.tryParse(scheduleAt);
    if (dateTime == null) {
      return ToolResult.error(
          'Invalid schedule_at format. Use ISO 8601: 2026-02-17T15:00:00');
    }

    final tzDateTime = tz.TZDateTime.from(dateTime, tz.local);
    if (tzDateTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return ToolResult.error('schedule_at must be in the future');
    }

    final id = (arguments['id'] as int?) ??
        DateTime.now().millisecondsSinceEpoch % 100000;

    await plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDateTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'droidclaw_scheduled',
          'DroidClaw Reminders',
          channelDescription: 'Scheduled reminders from DroidClaw',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    return ToolResult.dual(
      forLLM: 'Notification scheduled: id=$id, title="$title", at=$scheduleAt',
      forUser: 'Reminder set: "$title" at $scheduleAt',
    );
  }

  Future<ToolResult> _cancel(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> arguments,
  ) async {
    final id = arguments['id'] as int?;
    if (id == null) {
      return ToolResult.error('Missing required parameter: id');
    }

    await plugin.cancel(id: id);
    return ToolResult.dual(
      forLLM: 'Notification cancelled: id=$id',
      forUser: 'Notification #$id cancelled',
    );
  }

  Future<ToolResult> _list(
      FlutterLocalNotificationsPlugin plugin) async {
    final pending = await plugin.pendingNotificationRequests();
    if (pending.isEmpty) {
      return ToolResult.simple('No pending notifications.');
    }

    final lines = pending
        .map((n) => '- id=${n.id}: "${n.title}" — ${n.body}')
        .join('\n');
    return ToolResult.dual(
      forLLM: 'Pending notifications (${pending.length}):\n$lines',
      forUser: '${pending.length} pending notification(s)',
    );
  }
}
