import '../services/radio_player_channel.dart';
import 'tool.dart';

/// Tool that plays live Radio France HLS streams in the background.
///
/// Uses native MediaSessionService for background playback with a media
/// notification. Audio focus and noisy headphone handling are automatic.
class RadioTool extends Tool {
  @override
  String get name => 'radio';

  @override
  String get description =>
      'Play or stop live Radio France streams. '
      'Stations: france_inter, france_info, france_culture, france_musique, fip. '
      'Operations: play (requires station), stop, pause, resume, status.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['play', 'stop', 'pause', 'resume', 'status'],
            'description':
                '"play" starts a station, "stop" stops and removes notification, '
                    '"pause" pauses, "resume" resumes, "status" returns current state.',
          },
          'station': {
            'type': 'string',
            'enum': [
              'france_inter',
              'france_info',
              'france_culture',
              'france_musique',
              'fip',
            ],
            'description': 'Station to play (required for "play").',
          },
        },
        'required': ['operation'],
      };

  static const _stations = {
    'france_inter': (
      url: 'https://stream.radiofrance.fr/franceinter/franceinter_hifi.m3u8',
      label: 'France Inter',
    ),
    'france_info': (
      url: 'https://stream.radiofrance.fr/franceinfo/franceinfo_hifi.m3u8',
      label: 'France Info',
    ),
    'france_culture': (
      url: 'https://stream.radiofrance.fr/franceculture/franceculture_hifi.m3u8',
      label: 'France Culture',
    ),
    'france_musique': (
      url: 'https://stream.radiofrance.fr/francemusique/francemusique_hifi.m3u8',
      label: 'France Musique',
    ),
    'fip': (
      url: 'https://stream.radiofrance.fr/fip/fip_hifi.m3u8',
      label: 'FIP',
    ),
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    if (operation == null) {
      return ToolResult.error('Missing required parameter: operation');
    }

    try {
      return switch (operation) {
        'play' => await _play(arguments),
        'stop' => await _stop(),
        'pause' => await _pause(),
        'resume' => await _resume(),
        'status' => await _status(),
        _ => ToolResult.error(
            'Unknown operation: $operation. '
            'Use "play", "stop", "pause", "resume", or "status".'),
      };
    } catch (e) {
      return ToolResult.error('Radio failed: $e');
    }
  }

  Future<ToolResult> _play(Map<String, dynamic> arguments) async {
    final stationId = arguments['station'] as String?;
    if (stationId == null) {
      return ToolResult.error(
          'Missing required parameter: station. '
          'Available: ${_stations.keys.join(", ")}');
    }

    final station = _stations[stationId];
    if (station == null) {
      return ToolResult.error(
          'Unknown station: $stationId. '
          'Available: ${_stations.keys.join(", ")}');
    }

    // Check if already playing this station
    final current = await RadioPlayerChannel.getState();
    if (current.isPlaying && current.station == station.label) {
      return ToolResult.dual(
        forLLM: '${station.label} is already playing.',
        forUser: station.label,
      );
    }

    await RadioPlayerChannel.play(station.url, station.label);

    return ToolResult.dual(
      forLLM: 'Now playing ${station.label} (${station.url})',
      forUser: station.label,
    );
  }

  Future<ToolResult> _stop() async {
    final current = await RadioPlayerChannel.getState();
    if (current.state == RadioPlaybackState.idle) {
      return ToolResult.dual(
        forLLM: 'No radio is currently playing.',
        forUser: 'Radio stopped',
      );
    }

    await RadioPlayerChannel.stop();

    return ToolResult.dual(
      forLLM: 'Radio stopped (was playing: ${current.station ?? "unknown"}).',
      forUser: 'Radio stopped',
    );
  }

  Future<ToolResult> _pause() async {
    await RadioPlayerChannel.pause();
    return ToolResult.dual(
      forLLM: 'Radio paused.',
      forUser: 'Radio paused',
    );
  }

  Future<ToolResult> _resume() async {
    await RadioPlayerChannel.resume();
    return ToolResult.dual(
      forLLM: 'Radio resumed.',
      forUser: 'Radio resumed',
    );
  }

  Future<ToolResult> _status() async {
    final state = await RadioPlayerChannel.getState();

    final stateName = state.state.name;
    final stationName = state.station ?? 'none';

    final forLLM = 'Radio status: state=$stateName, '
        'isPlaying=${state.isPlaying}, station=$stationName. '
        'Available stations: ${_stations.keys.join(", ")}';
    final forUser = state.isPlaying
        ? '$stationName ($stateName)'
        : 'Radio off';

    return ToolResult.dual(forLLM: forLLM, forUser: forUser);
  }
}
