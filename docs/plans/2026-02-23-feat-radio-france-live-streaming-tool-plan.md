---
title: "feat: Add Radio France live streaming tool"
type: feat
date: 2026-02-23
---

# feat: Add Radio France live streaming tool

## Overview

New `radio` tool that plays live Radio France HLS audio streams in the background. The agent can tune to a station, pause, resume, stop, and query playback status. A native Android media notification provides play/pause/stop controls. Playback survives app backgrounding thanks to Android's `MediaSessionService`.

No API key required — Radio France streams are public HLS URLs.

## Problem Statement / Motivation

DroidClaw has 25 tools but no media playback capability. Radio France provides free, public HLS streams for all its stations. Adding a `radio` tool:

- Turns the phone into a voice-controlled radio ("mets France Inter", "arrête la radio")
- Leverages the existing MethodChannel pattern (same as `volume_control`)
- Chains naturally with `volume_control` ("monte le volume et mets FIP")
- Demonstrates agent-controlled background media — a capability no web-based assistant has

## Proposed Solution

### Architecture: MediaSessionService + FlutterPlugin

```
Flutter (Dart)                    Android (Kotlin)

RadioTool                         RadioPlayerPlugin
  |                                 |  (MethodChannel + EventChannel)
  v                                 v
RadioPlayerChannel  ---------->  MediaController
  (MethodChannel)                   |
  (EventChannel)                    v
                               RadioPlaybackService
                                 (MediaSessionService)
                                   |
                                   v
                                ExoPlayer (HLS)
                                   |
                                   v
                              Media Notification
                              [Play/Pause] [Stop]
```

Two separate Android services coexist:
1. **Existing**: `flutter_foreground_task` ForegroundService (`remoteMessaging|location`) — Telegram + cron
2. **New**: `RadioPlaybackService` (`mediaPlayback`) — radio streaming with auto-managed media notification

They are fully independent — different service types, different notification IDs, different lifecycles.

### Stations

| Station | Stream URL |
|---------|-----------|
| France Inter | `https://stream.radiofrance.fr/franceinter/franceinter_hifi.m3u8` |
| France Info | `https://stream.radiofrance.fr/franceinfo/franceinfo_hifi.m3u8` |
| France Culture | `https://stream.radiofrance.fr/franceculture/franceculture_hifi.m3u8` |
| France Musique | `https://stream.radiofrance.fr/francemusique/francemusique_hifi.m3u8` |
| FIP | `https://stream.radiofrance.fr/fip/fip_hifi.m3u8` |

### Tool Interface

```
Name: radio
Operations: play, stop, pause, resume, status
Parameters:
  - operation: string (required) — play, stop, pause, resume, status
  - station: string (required for play) — france_inter, france_info, france_culture, france_musique, fip
```

## Technical Approach

### Phase 1: Native Android layer (Kotlin)

#### 1a. Dependencies — `android/app/build.gradle.kts`

```kotlin
val media3Version = "1.9.2"
implementation("androidx.media3:media3-exoplayer:$media3Version")
implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
implementation("androidx.media3:media3-session:$media3Version")
```

#### 1b. RadioPlaybackService — `android/app/src/main/kotlin/com/droidclaw/app/RadioPlaybackService.kt`

`MediaSessionService` subclass:
- Creates `ExoPlayer` with `AudioAttributes(USAGE_MEDIA, CONTENT_TYPE_MUSIC)` and `handleAudioFocus=true`
- Sets `handleAudioBecomingNoisy=true` (pause on headphone disconnect)
- Creates `MediaSession` with custom callback that removes seek commands from notification (no seek on live radio)
- `onTaskRemoved()`: stop + clear + `stopSelf()` (no resume point for live radio)
- `onDestroy()`: release player + session

The `MediaSessionService` automatically manages:
- Foreground service promotion/demotion
- Media-style notification with play/pause/stop buttons
- Notification removal when `clearMediaItems()` is called

#### 1c. RadioPlayerPlugin — `android/app/src/main/kotlin/com/droidclaw/app/RadioPlayerPlugin.kt`

`FlutterPlugin` with:
- **MethodChannel** (`com.droidclaw.app/radio`): `play(url, title)`, `pause()`, `resume()`, `stop()`, `getState()`
- **EventChannel** (`com.droidclaw.app/radio_events`): streams playback state changes + errors to Dart
- Uses `MediaController.Builder` to connect to `RadioPlaybackService` on first `play()` call
- `Player.Listener` on the controller pushes state changes to `EventSink`
- State map: `{type: "state", state: "playing"|"paused"|"buffering"|"idle", isPlaying: bool}` or `{type: "error", code: ..., message: ...}`

#### 1d. AndroidManifest.xml

```xml
<!-- New permission -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<!-- New service (alongside existing ForegroundService) -->
<service
    android:name=".RadioPlaybackService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="androidx.media3.session.MediaSessionService" />
    </intent-filter>
</service>
```

#### 1e. MainActivity.kt — register plugin

```kotlin
flutterEngine.plugins.add(RadioPlayerPlugin())
```

### Phase 2: Dart channel wrapper

#### 2a. RadioPlayerChannel — `lib/core/services/radio_player_channel.dart`

Thin wrapper matching the `AudioManagerChannel` pattern:
- `static const _method = MethodChannel('com.droidclaw.app/radio')`
- `static const _events = EventChannel('com.droidclaw.app/radio_events')`
- Static methods: `play(url, title)`, `pause()`, `resume()`, `stop()`, `getState()`
- `stateStream` getter: maps EventChannel broadcast to sealed `RadioPlayerEvent` (state or error)
- Enum `RadioPlaybackState { idle, buffering, playing, paused, ended, unknown }`

### Phase 3: Tool implementation

#### 3a. RadioTool — `lib/core/tools/radio_tool.dart`

```dart
class RadioTool extends Tool {
  @override String get name => 'radio';

  // Station map: name -> (url, display name)
  static const _stations = {
    'france_inter': ('https://stream.radiofrance.fr/franceinter/franceinter_hifi.m3u8', 'France Inter'),
    'france_info': ('https://stream.radiofrance.fr/franceinfo/franceinfo_hifi.m3u8', 'France Info'),
    'france_culture': ('https://stream.radiofrance.fr/franceculture/franceculture_hifi.m3u8', 'France Culture'),
    'france_musique': ('https://stream.radiofrance.fr/francemusique/francemusique_hifi.m3u8', 'France Musique'),
    'fip': ('https://stream.radiofrance.fr/fip/fip_hifi.m3u8', 'FIP'),
  };
}
```

Operations:
- **`play`**: validates station name, calls `RadioPlayerChannel.play(url, title)`, returns `ToolResult.dual(forLLM: "Now playing France Inter...", forUser: "France Inter")`
- **`stop`**: calls `RadioPlayerChannel.stop()`, returns confirmation
- **`pause`**: calls `RadioPlayerChannel.pause()`
- **`resume`**: calls `RadioPlayerChannel.resume()`
- **`status`**: calls `RadioPlayerChannel.getState()`, returns current state + station info
- **Unknown station**: returns `ToolResult.error()` listing available stations

Dual ToolResult:
- `forLLM`: structured (operation, station, state, available stations)
- `forUser`: compact ("France Inter", "Radio stopped", etc.)

### Phase 4: Integration

#### 4a. app_providers.dart — register tool

```dart
if (!disabled.contains('radio')) {
  registry.register(RadioTool());
}
```

#### 4b. service_agent_factory.dart — exclude + comment

```dart
// - RadioTool (MethodChannel registered on Activity FlutterEngine only)
```

#### 4c. app_config.dart — disabled by default

Add `'radio'` to `_defaultDisabledTools`.

#### 4d. tools_config_screen.dart — add toggle

Add entry to `_tools` list with i18n label/description.

#### 4e. i18n — add keys to all 5 ARB files

Keys needed:
- `toolRadio` / `toolRadioDesc` (tool name/description for settings toggle)
- `radioPlaying` / `radioStopped` / `radioPaused` / `radioResumed` (forUser messages)
- `radioStationNotFound` / `radioAvailableStations` (error messages)

### Phase 5: README update

- Add `radio` to tools table (tool #26)
- Add to "No Key Required" list
- Add row in service isolate availability table (main: Yes, service: **No** — MethodChannel on Activity engine)

## Edge Cases & Audio Focus

| Scenario | Behavior |
|----------|----------|
| Phone call | ExoPlayer auto-pauses, resumes after call |
| Headphones unplugged | Auto-pauses (`handleAudioBecomingNoisy`) |
| Network loss | ExoPlayer retries with exponential backoff |
| `speak` tool (TTS) while radio plays | TTS requests audio focus → radio ducks or pauses, resumes after TTS |
| Swipe app from recents | `onTaskRemoved()` stops playback + `stopSelf()` |
| Android kills process (memory pressure) | `START_STICKY` restarts service, but no auto-resume (live radio) |
| Rapid play/stop commands | MediaController queues commands; last state wins |
| Unknown station name | Tool returns error with list of valid stations |
| Play while already playing | Seamless switch — `setMediaItem()` replaces current item |
| `volume_control` + `radio` chain | Agent can check/set volume, then play radio — natural tool chaining |

## Files

### New files (5)

| File | Purpose |
|------|---------|
| `android/app/src/main/kotlin/com/droidclaw/app/RadioPlaybackService.kt` | MediaSessionService + ExoPlayer |
| `android/app/src/main/kotlin/com/droidclaw/app/RadioPlayerPlugin.kt` | FlutterPlugin (MethodChannel + EventChannel) |
| `lib/core/services/radio_player_channel.dart` | Dart channel wrapper |
| `lib/core/tools/radio_tool.dart` | Tool implementation |

### Modified files (8)

| File | Change |
|------|--------|
| `android/app/build.gradle.kts` | Add Media3 dependencies (exoplayer, hls, session) |
| `android/app/src/main/AndroidManifest.xml` | Add `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission + RadioPlaybackService declaration |
| `android/app/src/main/kotlin/com/droidclaw/app/MainActivity.kt` | Register `RadioPlayerPlugin` |
| `lib/providers/app_providers.dart` | Register `RadioTool` |
| `lib/core/agent/service_agent_factory.dart` | Add exclusion comment |
| `lib/core/config/app_config.dart` | Add `'radio'` to `_defaultDisabledTools` |
| `lib/features/settings/tools_config_screen.dart` | Add toggle |
| `lib/l10n/app_*.arb` (5 files) | Add i18n keys |

### No change to

- `config_storage.dart` (no API key)
- `background_service_provider.dart` (no secret caching)
- `background_task_handler.dart` (radio is main isolate only)

## Acceptance Criteria

- [x] `flutter analyze` passes with 0 issues
- [x] Release APK builds and installs
- [x] "mets FIP" starts audio playback with media notification
- [x] Notification shows station name + play/pause buttons
- [ ] Tapping pause on notification pauses audio
- [ ] "arrête la radio" stops audio and removes notification
- [ ] "mets France Culture" while playing FIP switches seamlessly
- [ ] Phone call auto-pauses radio, resumes after
- [ ] Headphone disconnect auto-pauses
- [ ] "quelle radio ?" returns current station and state
- [ ] Unknown station returns error with available stations list
- [x] Radio tool disabled by default, toggleable in Settings > Tools
- [ ] App kill (swipe from recents) stops radio cleanly

## Dependencies

- **AndroidX Media3 1.9.2** (exoplayer + hls + session) — new Gradle dependency
- No new Flutter/Dart package needed
- No API key needed

## References

- [Background playback with MediaSessionService](https://developer.android.com/media/media3/session/background-playback)
- [HLS — Android Developers](https://developer.android.com/media/media3/exoplayer/hls)
- [Foreground service types (Android 14+)](https://developer.android.com/about/versions/14/changes/fgs-types-required)
- Existing pattern: `AudioChannelPlugin.kt` + `AudioManagerChannel` (volume_control)
- Existing pattern: `VolumeControlTool` (MethodChannel-based tool, main isolate only)
