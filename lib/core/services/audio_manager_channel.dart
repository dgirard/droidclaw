import 'package:flutter/services.dart';

/// Android AudioManager stream constants.
abstract final class AudioStream {
  static const int voiceCall = 0; // AudioManager.STREAM_VOICE_CALL
  static const int ring = 2; // AudioManager.STREAM_RING
  static const int music = 3; // AudioManager.STREAM_MUSIC
  static const int alarm = 4; // AudioManager.STREAM_ALARM
  static const int notification = 5; // AudioManager.STREAM_NOTIFICATION
}

/// Android AudioManager ringer mode constants.
abstract final class RingerMode {
  static const int silent = 0; // AudioManager.RINGER_MODE_SILENT
  static const int vibrate = 1; // AudioManager.RINGER_MODE_VIBRATE
  static const int normal = 2; // AudioManager.RINGER_MODE_NORMAL

  static String label(int mode) => switch (mode) {
        silent => 'silent',
        vibrate => 'vibrate',
        normal => 'normal',
        _ => 'unknown($mode)',
      };
}

/// Thin Dart wrapper around the native AudioManager MethodChannel.
class AudioManagerChannel {
  static const _channel = MethodChannel('com.droidclaw.app/audio');

  /// Get current volume for [stream] (0..maxVolume).
  static Future<int> getStreamVolume(int stream) async {
    final result = await _channel
        .invokeMethod<int>('getStreamVolume', {'stream': stream});
    return result!;
  }

  /// Get max volume for [stream].
  static Future<int> getStreamMaxVolume(int stream) async {
    final result = await _channel
        .invokeMethod<int>('getStreamMaxVolume', {'stream': stream});
    return result!;
  }

  /// Set volume for [stream] to [volume] (0..maxVolume).
  static Future<void> setStreamVolume(int stream, int volume) async {
    await _channel.invokeMethod<void>(
        'setStreamVolume', {'stream': stream, 'volume': volume});
  }

  /// Get ringer mode: 0=silent, 1=vibrate, 2=normal.
  static Future<int> getRingerMode() async {
    final result = await _channel.invokeMethod<int>('getRingerMode');
    return result!;
  }
}
