import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:intl/intl.dart';

import 'tool.dart';

/// Tool that reads and creates calendar events.
class CalendarTool extends Tool {
  final bool canRequestPermission;

  CalendarTool({this.canRequestPermission = true});

  @override
  String get name => 'calendar';

  @override
  String get description =>
      'Read and create calendar events. '
      'List calendars, get events in a date range, or create new events. '
      'Use for "what\'s on my calendar today" or '
      '"add a meeting tomorrow at 2pm".';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['list_calendars', 'get_events', 'create_event'],
            'description': 'Operation to perform',
          },
          'calendar_id': {
            'type': 'string',
            'description':
                'Calendar ID (required for get_events and create_event; '
                    'use list_calendars to find IDs)',
          },
          'start': {
            'type': 'string',
            'description':
                'Start date/time ISO 8601 (required for get_events '
                    'and create_event). Example: 2026-02-17T09:00:00',
          },
          'end': {
            'type': 'string',
            'description':
                'End date/time ISO 8601 (required for get_events '
                    'and create_event). Example: 2026-02-17T18:00:00',
          },
          'title': {
            'type': 'string',
            'description': 'Event title (required for create_event)',
          },
          'description': {
            'type': 'string',
            'description': 'Event description (optional for create_event)',
          },
          'location': {
            'type': 'string',
            'description': 'Event location (optional for create_event)',
          },
        },
        'required': ['operation'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) {
      return ToolResult.error('Missing required parameter: operation');
    }

    try {
      final plugin = DeviceCalendar.instance;

      // Check permissions
      var status = await plugin.hasPermissions();
      if (status != CalendarPermissionStatus.granted) {
        if (!canRequestPermission) {
          return ToolResult.error(
              'Calendar permission not granted. '
              'Please open the app and use the calendar tool once '
              'to grant permission.');
        }
        status = await plugin.requestPermissions();
        if (status != CalendarPermissionStatus.granted) {
          return ToolResult.error('Calendar permission denied by user.');
        }
      }

      switch (operation) {
        case 'list_calendars':
          return await _listCalendars(plugin);
        case 'get_events':
          return await _getEvents(plugin, arguments);
        case 'create_event':
          return await _createEvent(plugin, arguments);
        default:
          return ToolResult.error(
              'Unknown operation: $operation. '
              'Use list_calendars, get_events, or create_event.');
      }
    } catch (e) {
      return ToolResult.error('Calendar operation failed: $e');
    }
  }

  Future<ToolResult> _listCalendars(DeviceCalendar plugin) async {
    final calendars = await plugin.listCalendars();
    if (calendars.isEmpty) {
      return ToolResult.simple('No calendars found on device.');
    }

    final lines = calendars
        .map((c) => '- ${c.name} (id: ${c.id}, '
            '${c.readOnly ? "read-only" : "writable"}'
            '${c.isPrimary ? ", primary" : ""})')
        .join('\n');
    return ToolResult.dual(
      forLLM: 'Calendars (${calendars.length}):\n$lines',
      forUser: '${calendars.length} calendar(s) found',
    );
  }

  Future<ToolResult> _getEvents(
    DeviceCalendar plugin,
    Map<String, dynamic> arguments,
  ) async {
    final start = _parseDateTime(arguments['start'] as String?);
    final end = _parseDateTime(arguments['end'] as String?);
    if (start == null || end == null) {
      return ToolResult.error(
          'Missing or invalid start/end dates. Use ISO 8601 format.');
    }

    final calendarId = arguments['calendar_id'] as String?;
    final events = await plugin.listEvents(
      start,
      end,
      calendarIds: calendarId != null ? [calendarId] : null,
    );

    if (events.isEmpty) {
      return ToolResult.simple(
          'No events found in the specified range.');
    }

    final lines = events.map(_formatEvent).join('\n');
    return ToolResult.dual(
      forLLM: 'Events (${events.length}):\n$lines',
      forUser: '${events.length} event(s) found',
    );
  }

  Future<ToolResult> _createEvent(
    DeviceCalendar plugin,
    Map<String, dynamic> arguments,
  ) async {
    final calendarId = arguments['calendar_id'] as String?;
    final title = arguments['title'] as String?;
    final start = _parseDateTime(arguments['start'] as String?);
    final end = _parseDateTime(arguments['end'] as String?);
    if (calendarId == null ||
        title == null ||
        start == null ||
        end == null) {
      return ToolResult.error(
          'Missing required parameters: calendar_id, title, start, end');
    }

    final eventId = await plugin.createEvent(
      calendarId: calendarId,
      title: title,
      startDate: start,
      endDate: end,
      description: arguments['description'] as String?,
      location: arguments['location'] as String?,
    );

    return ToolResult.dual(
      forLLM: 'Event created: id=$eventId, title="$title", '
          'start=$start, end=$end',
      forUser: 'Event "$title" created',
    );
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  static final _dateFmt = DateFormat('MMM d, HH:mm');

  String _formatEvent(Event e) {
    final parts = <String>['- ${e.title}'];
    parts.add('  ${_dateFmt.format(e.startDate)}'
        ' — ${_dateFmt.format(e.endDate)}');
    if (e.location != null && e.location!.isNotEmpty) {
      parts.add('  Location: ${e.location}');
    }
    if (e.isAllDay) parts.add('  All-day event');
    return parts.join('\n');
  }
}
