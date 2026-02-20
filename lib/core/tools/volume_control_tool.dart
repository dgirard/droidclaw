import '../services/audio_manager_channel.dart';
import 'tool.dart';

/// Tool that reads and adjusts device volume levels per audio stream.
class VolumeControlTool extends Tool {
  @override
  String get name => 'volume_control';

  @override
  String get description =>
      'Read or adjust the device volume for alarm, media, ringtone, or '
      'notification streams. Also reports the ringer mode (normal/vibrate/silent). '
      'Use before setting an alarm to verify the alarm sound is audible.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['get', 'set'],
            'description':
                '"get" returns all stream volumes + ringer mode. '
                    '"set" adjusts volume for a specific stream.',
          },
          'stream': {
            'type': 'string',
            'enum': ['alarm', 'media', 'ring', 'notification'],
            'description': 'Audio stream to adjust (required for "set")',
          },
          'level': {
            'type': 'string',
            'enum': ['mute', 'low', 'medium', 'high', 'max'],
            'description':
                'Volume level to set (required for "set"): '
                    'mute=0%, low=25%, medium=50%, high=75%, max=100%',
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
      return switch (operation) {
        'get' => await _get(),
        'set' => await _set(arguments),
        _ => ToolResult.error('Unknown operation: $operation. Use "get" or "set".'),
      };
    } catch (e) {
      return ToolResult.error('Volume control failed: $e');
    }
  }

  Future<ToolResult> _get() async {
    final streams = {
      'alarm': AudioStream.alarm,
      'media': AudioStream.music,
      'ring': AudioStream.ring,
      'notification': AudioStream.notification,
    };

    final lines = <String>[];
    String? alarmSummary;

    for (final entry in streams.entries) {
      final vol = await AudioManagerChannel.getStreamVolume(entry.value);
      final max = await AudioManagerChannel.getStreamMaxVolume(entry.value);
      final pct = max > 0 ? (vol * 100 / max).round() : 0;
      lines.add('${entry.key}: $vol/$max ($pct%)');
      if (entry.key == 'alarm') {
        alarmSummary = '$pct%';
      }
    }

    final ringerMode = await AudioManagerChannel.getRingerMode();
    final ringerLabel = RingerMode.label(ringerMode);
    lines.add('ringer_mode: $ringerLabel');

    final forLLM = 'Volume levels:\n${lines.join('\n')}';
    final forUser = 'Alarm: $alarmSummary, Ringer: $ringerLabel';

    return ToolResult.dual(forLLM: forLLM, forUser: forUser);
  }

  Future<ToolResult> _set(Map<String, dynamic> arguments) async {
    final streamName = arguments['stream'] as String?;
    final levelName = arguments['level'] as String?;

    if (streamName == null) {
      return ToolResult.error('Missing required parameter: stream');
    }
    if (levelName == null) {
      return ToolResult.error('Missing required parameter: level');
    }

    final streamId = switch (streamName) {
      'alarm' => AudioStream.alarm,
      'media' => AudioStream.music,
      'ring' => AudioStream.ring,
      'notification' => AudioStream.notification,
      _ => null,
    };
    if (streamId == null) {
      return ToolResult.error(
          'Unknown stream: $streamName. '
          'Use "alarm", "media", "ring", or "notification".');
    }

    final fraction = switch (levelName) {
      'mute' => 0.0,
      'low' => 0.25,
      'medium' => 0.5,
      'high' => 0.75,
      'max' => 1.0,
      _ => null,
    };
    if (fraction == null) {
      return ToolResult.error(
          'Unknown level: $levelName. '
          'Use "mute", "low", "medium", "high", or "max".');
    }

    final max = await AudioManagerChannel.getStreamMaxVolume(streamId);
    final target = (max * fraction).round();
    await AudioManagerChannel.setStreamVolume(streamId, target);

    // Read back actual value (may differ due to rounding or system limits)
    final actual = await AudioManagerChannel.getStreamVolume(streamId);
    final pct = max > 0 ? (actual * 100 / max).round() : 0;

    return ToolResult.dual(
      forLLM: '$streamName volume set to $actual/$max ($pct%) '
          '[requested: $levelName]',
      forUser: '${streamName[0].toUpperCase()}${streamName.substring(1)} '
          'volume: $pct%',
    );
  }
}
