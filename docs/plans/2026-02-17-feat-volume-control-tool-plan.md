---
title: "feat: Add volume_control tool for alarm sound verification"
type: feat
date: 2026-02-17
---

# feat: Add volume_control tool for alarm sound verification

## Overview

Add a `volume_control` tool that lets the agent read and set Android volume levels per audio stream (alarm, media, ringtone, notification) and read the ringer mode. The primary use case: when the user asks to set an alarm, the agent can first check that alarm volume is audible and warn/adjust if needed.

## Motivation

When using `set_alarm`, there is no way to verify that the device will actually ring. If the alarm volume is muted or very low, the user misses the alarm. The agent should be able to:
1. Check alarm volume before setting an alarm
2. Warn the user if volume is too low or ringer is on silent/vibrate
3. Optionally raise the volume to a reasonable level

## Proposed Solution

A new `volume_control` tool backed by a **custom MethodChannel** to Android's `AudioManager`.

### Why custom MethodChannel (not a package)

No Flutter package cleanly covers all requirements:
- `flutter_volume_controller` (v1.3.4): uses a global stream switch design, `setAndroidAudioStream()` requires Activity
- `volume_controller` (v3.4.1): media stream only, no per-stream control
- `real_volume` (v1.0.9): stale (Sep 2024), uncertain ALARM stream support
- `sound_mode` (v3.1.1): ringer mode only, no volume control

A custom MethodChannel is ~80 lines total (Kotlin + Dart), adds zero dependencies, works from background service, and maps 1:1 to `AudioManager` APIs.

## Technical Approach

### Files to Create

#### 1. `android/app/src/main/kotlin/com/droidclaw/app/AudioChannelPlugin.kt`

A Flutter plugin that registers a MethodChannel on any FlutterEngine (main or service). This ensures it works in both isolates.

```kotlin
// Implements FlutterPlugin so it's auto-registered via GeneratedPluginRegistrant
class AudioChannelPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val audioManager = binding.applicationContext
            .getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(binding.binaryMessenger, "com.droidclaw.app/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStreamVolume" -> ...
                    "getStreamMaxVolume" -> ...
                    "setStreamVolume" -> ...
                    "getRingerMode" -> ...
                }
            }
    }
}
```

Methods:
- `getStreamVolume(stream)` → int (0..max)
- `getStreamMaxVolume(stream)` → int
- `setStreamVolume(stream, volume, flags)` → void
- `getRingerMode()` → int (0=silent, 1=vibrate, 2=normal)

**Important**: Must be registered in `GeneratedPluginRegistrant` so it works in the service isolate's FlutterEngine. This requires either:
- (a) Manually adding to `GeneratedPluginRegistrant.java`, OR
- (b) Creating a proper plugin package structure with `pubspec.yaml` plugin declaration

Option (a) is simpler but gets overwritten by `flutter pub get`. Option (b) is cleaner — create the plugin inline in the android directory. **Simplest approach**: override `configureFlutterEngine` in `MainActivity.kt` for the main isolate, and register the channel handler as a standard `FlutterPlugin` so `GeneratedPluginRegistrant` picks it up automatically for the service isolate.

**Recommended approach**: Implement as a `FlutterPlugin` in `AudioChannelPlugin.kt` and register it in `MainActivity.kt` via `flutterEngine.plugins.add(AudioChannelPlugin())`. For the service isolate, `flutter_foreground_task` creates a new FlutterEngine that runs `GeneratedPluginRegistrant.registerWith()` — we need to add it there too. The cleanest way is to add the plugin registration in `MainActivity.configureFlutterEngine()` AND create a custom `Application` class that also registers it, or simply register it in the `BackgroundTaskHandler` initialization.

**Actually simplest**: Just override `MainActivity.configureFlutterEngine()` to set up the MethodChannel handler directly on the engine's binary messenger. For the service isolate, the `BackgroundTaskHandler` can set up its own MethodChannel since it has access to the FlutterEngine context.

#### 2. `lib/core/services/audio_manager_channel.dart`

Dart wrapper for the MethodChannel:

```dart
class AudioStream {
  static const int alarm = 4;       // AudioManager.STREAM_ALARM
  static const int music = 3;       // AudioManager.STREAM_MUSIC
  static const int ring = 2;        // AudioManager.STREAM_RING
  static const int notification = 5; // AudioManager.STREAM_NOTIFICATION
}

class RingerMode {
  static const int silent = 0;
  static const int vibrate = 1;
  static const int normal = 2;
}

class AudioManagerChannel {
  static const _channel = MethodChannel('com.droidclaw.app/audio');

  static Future<int> getStreamVolume(int stream) async { ... }
  static Future<int> getStreamMaxVolume(int stream) async { ... }
  static Future<void> setStreamVolume(int stream, int volume) async { ... }
  static Future<int> getRingerMode() async { ... }
}
```

#### 3. `lib/core/tools/volume_control_tool.dart`

The tool implementation:

```dart
class VolumeControlTool extends Tool {
  @override String get name => 'volume_control';

  // Operations:
  // - "get": returns volume levels for all streams + ringer mode
  // - "set": sets volume for a specific stream
  //
  // Parameters:
  //   operation (string, required): "get" or "set"
  //   stream (string): "alarm", "media", "ring", "notification" (required for "set")
  //   level (string): "mute", "low", "medium", "high", "max" (required for "set")
}
```

The `get` operation returns all volumes as percentages + ringer mode — the LLM gets a full picture in one call. The `set` operation uses human-readable levels ("low", "medium", "high") mapped to percentages of max volume:
- `mute` → 0
- `low` → 25% of max
- `medium` → 50% of max
- `high` → 75% of max
- `max` → 100% of max

### Files to Modify

#### 4. `android/app/src/main/AndroidManifest.xml`

- [x] Add `<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>` (normal permission, no runtime prompt)

#### 5. `android/app/src/main/kotlin/com/droidclaw/app/MainActivity.kt`

- [x] Override `configureFlutterEngine()` to register the audio MethodChannel

#### 6. `lib/providers/app_providers.dart`

- [x] Import `VolumeControlTool`
- [x] Register in `toolRegistryProvider`: `if (!disabled.contains('volume_control')) { registry.register(VolumeControlTool()); }`

#### 7. `lib/core/agent/service_agent_factory.dart`

- [x] Add exclusion comment for `VolumeControlTool` (works from service isolate — AudioManager uses applicationContext, no Activity needed)

#### 8. `lib/features/settings/tools_config_screen.dart`

- [x] Add toggle: `_ToolInfo(name: 'volume_control', label: 'Volume Control', description: 'Read and adjust device volume levels', icon: Icons.volume_up_outlined)`

#### 9. `README.md`

- [x] Update tool count (19 → 20)
- [x] Add tool description row
- [x] Add availability table row: Yes (main) / Yes (service)
- [x] Update mermaid diagram tools list
- [x] Update Dart file count

## Acceptance Criteria

- [ ] `volume_control` tool with `get` and `set` operations
- [ ] `get` returns all stream volumes (as % + raw) and ringer mode
- [ ] `set` adjusts a specific stream using human-readable levels
- [ ] Works from both main isolate and service isolate
- [ ] `MODIFY_AUDIO_SETTINGS` permission declared in manifest
- [ ] Tool toggle in settings screen
- [ ] `flutter analyze` passes with 0 issues
- [ ] LLM can chain: check alarm volume → warn if low → set to medium → then set_alarm

## Service Isolate Compatibility

`AudioManager` is obtained from `Context.getSystemService()` — any Context works (Activity, Application, Service). The MethodChannel registered on the service isolate's FlutterEngine will work. The key consideration is ensuring the channel handler is registered for the service isolate's engine, not just the main Activity's engine.

**Approach for service isolate**: The `BackgroundTaskHandler` in `lib/core/services/background_task_handler.dart` runs on a separate FlutterEngine. We need to ensure the audio MethodChannel is available there. Options:
1. Register in a custom `Application` class (covers all engines)
2. Set up in `BackgroundTaskHandler.onStart()` via the service context

Option 1 is cleanest since it automatically covers any FlutterEngine created in the process.

## Edge Cases

- **Do Not Disturb mode**: On Android 7+, setting ringer mode to silent may require DND access. We should NOT attempt to change ringer mode — only read it and warn.
- **Volume 0 vs mute**: On some devices, alarm volume 0 still plays at minimum. We report the raw value and let the LLM interpret.
- **No permission needed for get**: Reading volumes and ringer mode requires no permissions. Only setting volume needs `MODIFY_AUDIO_SETTINGS`.

## References

- `lib/core/tools/set_alarm_tool.dart` — existing alarm tool (uses `android_intent_plus`)
- `lib/core/tools/speak_tool.dart` — existing TTS tool (`flutter_tts`, hardcoded volume 1.0)
- `lib/core/tools/device_info_tool.dart` — pattern for device-level info tool
- `docs/solutions/architecture/enable-location-tools-in-service-isolate.md` — pattern for enabling tools in service isolate
- [Android AudioManager API](https://developer.android.com/reference/android/media/AudioManager)
