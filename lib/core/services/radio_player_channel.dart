import 'package:flutter/services.dart';

/// Playback state reported by the native radio player.
enum RadioPlaybackState {
  idle,
  buffering,
  playing,
  paused,
  ended,
  unknown;

  static RadioPlaybackState fromString(String value) => switch (value) {
        'idle' => idle,
        'buffering' => buffering,
        'playing' => playing,
        'paused' => paused,
        'ended' => ended,
        _ => unknown,
      };
}

/// Playback state snapshot from the native layer.
class RadioState {
  final RadioPlaybackState state;
  final bool isPlaying;
  final String? station;

  const RadioState({
    required this.state,
    required this.isPlaying,
    this.station,
  });

  factory RadioState.fromMap(Map<String, dynamic> map) => RadioState(
        state: RadioPlaybackState.fromString(map['state'] as String? ?? 'idle'),
        isPlaying: map['isPlaying'] as bool? ?? false,
        station: map['station'] as String?,
      );
}

/// Thin Dart wrapper around the native radio player MethodChannel/EventChannel.
class RadioPlayerChannel {
  static const _method = MethodChannel('com.droidclaw.app/radio');
  static const _events = EventChannel('com.droidclaw.app/radio_events');

  /// Start playing an HLS stream URL with the given display [title].
  static Future<void> play(String url, String title) async {
    await _method.invokeMethod<void>('play', {'url': url, 'title': title});
  }

  /// Pause playback (keeps stream connection alive).
  static Future<void> pause() async {
    await _method.invokeMethod<void>('pause');
  }

  /// Resume after pause.
  static Future<void> resume() async {
    await _method.invokeMethod<void>('resume');
  }

  /// Stop playback and clear media (removes notification).
  static Future<void> stop() async {
    await _method.invokeMethod<void>('stop');
  }

  /// Get current playback state snapshot.
  static Future<RadioState> getState() async {
    final result = await _method.invokeMethod<Map>('getState');
    return RadioState.fromMap(Map<String, dynamic>.from(result ?? {}));
  }

  /// Broadcast stream of playback state changes from the native layer.
  static Stream<Map<String, dynamic>> get stateStream =>
      _events.receiveBroadcastStream().map(
            (event) => Map<String, dynamic>.from(event as Map),
          );
}
