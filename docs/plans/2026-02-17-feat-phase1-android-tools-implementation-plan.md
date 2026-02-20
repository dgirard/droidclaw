---
title: "feat: Phase 1 — Android-native tools implementation"
type: feat
date: 2026-02-17
---

# Phase 1 — Android-Native Tools Implementation

5 new tools: `clipboard`, `device_info`, `speak`, `open_app`, `set_alarm`.

## Design Decisions

Key decisions from SpecFlow analysis — each gap addressed.

### D1: open_app safety — URL-only, no raw intents

Split into two concerns:
- `open_app` uses **`url_launcher` only** (URL schemes: `https:`, `tel:`, `mailto:`, `sms:`, `geo:`). This is safe — `url_launcher` handles package visibility, BAL restrictions, and error reporting. No `android_intent_plus` dependency needed for this tool.
- `set_alarm` uses `android_intent_plus` **only for SET_ALARM/SET_TIMER** — a tightly scoped allowlist.

Raw intent launching (`ACTION_SEND`, `ACTION_VIEW` with arbitrary data) is deferred to a future phase. Rationale: it requires an allowlist, extras type mapping, and package visibility strategy — too much scope for Phase 1.

### D2: speak — fire-and-forget, max 5000 chars

- Fire-and-forget: `flutterTts.speak()` returns immediately, agent loop continues.
- Max 5000 characters. Truncate with warning in `forLLM`.
- Check `isLanguageAvailable()` before speaking; return error listing available languages if not.
- No `stop` operation in Phase 1 (user can mute device).
- Main isolate only.

### D3: clipboard — privacy guard in description

- Tool description instructs LLM: "Only read clipboard when the user explicitly asks."
- `forUser` shows first 100 chars preview on read, so user sees what was accessed.
- Text-only (return error for non-text content).
- Max 10,000 chars on read (truncate with warning). Max 50,000 chars on write.
- Service isolate: **not registered** (read fails from background on Android 10+, write is marginal value without read).

### D4: set_alarm — always show Clock UI, validate params

- Do NOT set `EXTRA_SKIP_UI` — let Clock app show for user confirmation.
- `forLLM` says "Alarm requested (user must confirm in Clock app)" — not "alarm set."
- Validate: hour 0-23, minutes 0-59, duration_seconds > 0.
- Service isolate: **not registered** (opening Clock app from background at 3 AM is jarring).

### D5: Default enabled/disabled

- `clipboard`, `device_info` → **enabled** by default (no side effects)
- `speak`, `open_app`, `set_alarm` → **disabled** by default (real-world side effects: audio, app launches, alarms)

### D6: Service isolate registration

Only `device_info` is registered in `ServiceAgentFactory`. All others are main-isolate only. No need for `canRequestPermission`-style flags in Phase 1.

---

## Dependencies to Add

```yaml
# pubspec.yaml — add to dependencies:
battery_plus: ^6.1.0
device_info_plus: ^11.2.0
flutter_tts: ^4.2.0
android_intent_plus: ^5.1.0
# connectivity_plus already present at ^7.0.0
# url_launcher already present at ^6.3.2
```

## AndroidManifest.xml Changes

```xml
<!-- Add permission for set_alarm -->
<uses-permission android:name="com.android.alarm.permission.SET_ALARM"/>

<!-- Add to <queries> section -->
<intent>
    <action android:name="android.intent.action.SET_ALARM"/>
</intent>
<intent>
    <action android:name="android.intent.action.SET_TIMER"/>
</intent>
```

No other manifest changes needed — `url_launcher` handles its own queries, `flutter_tts` uses system TTS service, battery/device_info need no permissions.

---

## Tool 1: `clipboard`

### `lib/core/tools/clipboard_tool.dart`

```dart
import 'package:flutter/services.dart';
import 'tool.dart';

class ClipboardTool extends Tool {
  static const int _maxReadChars = 10000;
  static const int _maxWriteChars = 50000;

  @override
  String get name => 'clipboard';

  @override
  String get description =>
      'Read or write the device clipboard. '
      'Only read the clipboard when the user explicitly asks you to. '
      'Use "write" to place text in the clipboard for the user to paste elsewhere.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'operation': {
        'type': 'string',
        'enum': ['read', 'write'],
        'description': 'Whether to read from or write to the clipboard',
      },
      'text': {
        'type': 'string',
        'description': 'Text to write to clipboard (required for write operation)',
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
      switch (operation) {
        case 'read':
          final data = await Clipboard.getData('text/plain');
          if (data == null || data.text == null || data.text!.isEmpty) {
            return ToolResult.simple('Clipboard is empty or contains non-text content.');
          }
          var text = data.text!;
          final truncated = text.length > _maxReadChars;
          if (truncated) text = text.substring(0, _maxReadChars);
          final preview = text.length > 100 ? '${text.substring(0, 100)}...' : text;
          return ToolResult.dual(
            forLLM: truncated
                ? 'Clipboard content (truncated to $_maxReadChars chars, '
                  'original ${data.text!.length}):\n$text'
                : 'Clipboard content:\n$text',
            forUser: 'Clipboard: $preview',
          );

        case 'write':
          final text = arguments['text'] as String?;
          if (text == null || text.isEmpty) {
            return ToolResult.error('Missing required parameter: text (for write)');
          }
          if (text.length > _maxWriteChars) {
            return ToolResult.error(
                'Text too long for clipboard (${text.length} chars, max $_maxWriteChars)');
          }
          await Clipboard.setData(ClipboardData(text: text));
          return ToolResult.dual(
            forLLM: 'Copied ${text.length} characters to clipboard.',
            forUser: 'Copied to clipboard (${text.length} chars)',
          );

        default:
          return ToolResult.error('Unknown operation: $operation. Use "read" or "write".');
      }
    } catch (e) {
      return ToolResult.error('Clipboard operation failed: $e');
    }
  }
}
```

---

## Tool 2: `device_info`

### `lib/core/tools/device_info_tool.dart`

```dart
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'tool.dart';

class DeviceInfoTool extends Tool {
  @override
  String get name => 'device_info';

  @override
  String get description =>
      'Get device information: battery level and charging status, '
      'network connectivity type, device model, manufacturer, and Android version.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final parts = <String>[];
    final userParts = <String>[];

    // Battery
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      final stateStr = switch (state) {
        BatteryState.charging => 'charging',
        BatteryState.discharging => 'discharging',
        BatteryState.full => 'full',
        BatteryState.connectedNotCharging => 'connected (not charging)',
        _ => 'unknown',
      };
      parts.add('Battery: $level% ($stateStr)');
      userParts.add('Battery: $level% ($stateStr)');
    } catch (e) {
      parts.add('Battery: unavailable ($e)');
    }

    // Connectivity
    try {
      final results = await Connectivity().checkConnectivity();
      final types = results.map((r) => r.name).join(', ');
      parts.add('Connectivity: $types');
      userParts.add('Network: $types');
    } catch (e) {
      parts.add('Connectivity: unavailable ($e)');
    }

    // Device info
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      parts.add('Device: ${info.manufacturer} ${info.model}');
      parts.add('Android: ${info.version.release} (SDK ${info.version.sdkInt})');
      parts.add('Product: ${info.product}');
      userParts.add('${info.manufacturer} ${info.model} — Android ${info.version.release}');
    } catch (e) {
      parts.add('Device info: unavailable ($e)');
    }

    if (parts.isEmpty) {
      return ToolResult.error('Failed to retrieve any device information.');
    }

    return ToolResult.dual(
      forLLM: parts.join('\n'),
      forUser: userParts.join(' | '),
    );
  }
}
```

---

## Tool 3: `speak`

### `lib/core/tools/speak_tool.dart`

```dart
import 'package:flutter_tts/flutter_tts.dart';
import 'tool.dart';

class SpeakTool extends Tool {
  static const int _maxChars = 5000;
  FlutterTts? _tts;

  @override
  String get name => 'speak';

  @override
  String get description =>
      'Speak text aloud using the device text-to-speech engine. '
      'Use when the user asks you to read something aloud or for hands-free interaction. '
      'Audio plays on the device speaker.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'text': {
        'type': 'string',
        'description': 'The text to speak aloud',
      },
      'language': {
        'type': 'string',
        'description': 'Language code (e.g. "fr-FR", "en-US"). Defaults to device language.',
      },
    },
    'required': ['text'],
  };

  Future<FlutterTts> _getTts() async {
    if (_tts == null) {
      _tts = FlutterTts();
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
    }
    return _tts!;
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final text = arguments['text'] as String?;
    if (text == null || text.isEmpty) {
      return ToolResult.error('Missing required parameter: text');
    }

    try {
      final tts = await _getTts();

      // Handle language
      final language = arguments['language'] as String?;
      if (language != null) {
        final available = await tts.isLanguageAvailable(language);
        if (available != 1) {
          final languages = await tts.getLanguages;
          return ToolResult.error(
              'Language "$language" is not available for TTS. '
              'Available: ${(languages as List).take(20).join(", ")}');
        }
        await tts.setLanguage(language);
      }

      // Truncate if needed
      var toSpeak = text;
      final truncated = text.length > _maxChars;
      if (truncated) {
        toSpeak = text.substring(0, _maxChars);
      }

      // Fire and forget
      await tts.speak(toSpeak);

      final charInfo = truncated
          ? '${toSpeak.length} chars (truncated from ${text.length})'
          : '${toSpeak.length} chars';

      return ToolResult.dual(
        forLLM: 'Text is being spoken aloud ($charInfo).',
        forUser: 'Speaking ($charInfo)...',
      );
    } catch (e) {
      return ToolResult.error('Text-to-speech failed: $e');
    }
  }
}
```

---

## Tool 4: `open_app`

### `lib/core/tools/open_app_tool.dart`

```dart
import 'package:url_launcher/url_launcher.dart';
import 'tool.dart';

class OpenAppTool extends Tool {
  @override
  String get name => 'open_app';

  @override
  String get description =>
      'Open a URL or app on the device. Supports web URLs (https://), '
      'phone dialer (tel:+33...), email (mailto:...), SMS composer (sms:...), '
      'and map locations (geo:lat,lon or geo:0,0?q=address). '
      'The target app opens on the device screen.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'url': {
        'type': 'string',
        'description':
            'URL to open. Examples: "https://example.com", '
            '"tel:+33123456789", "mailto:user@example.com", '
            '"sms:+33123456789?body=Hello", '
            '"geo:48.8566,2.3522?q=Eiffel+Tower"',
      },
    },
    'required': ['url'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final urlStr = arguments['url'] as String?;
    if (urlStr == null || urlStr.isEmpty) {
      return ToolResult.error('Missing required parameter: url');
    }

    try {
      final uri = Uri.parse(urlStr);

      // Validate scheme
      const allowedSchemes = ['https', 'http', 'tel', 'mailto', 'sms', 'geo'];
      if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
        return ToolResult.error(
            'Unsupported URL scheme: "${uri.scheme}". '
            'Allowed: ${allowedSchemes.join(", ")}');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        return ToolResult.error(
            'Could not open "$urlStr". No app available to handle this URL.');
      }

      final schemeLabel = switch (uri.scheme.toLowerCase()) {
        'tel' => 'phone dialer',
        'mailto' => 'email app',
        'sms' => 'SMS app',
        'geo' => 'maps app',
        _ => 'browser',
      };

      return ToolResult.dual(
        forLLM: 'Opened $schemeLabel with URL: $urlStr',
        forUser: 'Opened $schemeLabel',
      );
    } catch (e) {
      return ToolResult.error('Failed to open URL: $e');
    }
  }
}
```

---

## Tool 5: `set_alarm`

### `lib/core/tools/set_alarm_tool.dart`

```dart
import 'package:android_intent_plus/android_intent.dart';
import 'tool.dart';

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
          return ToolResult.error('Unknown type: $type. Use "alarm" or "timer".');
      }
    } catch (e) {
      return ToolResult.error('Failed to set $type: $e');
    }
  }

  Future<ToolResult> _setAlarm(Map<String, dynamic> arguments) async {
    final hour = arguments['hour'] as int?;
    final minutes = arguments['minutes'] as int?;
    if (hour == null || minutes == null) {
      return ToolResult.error('Alarm requires "hour" (0-23) and "minutes" (0-59).');
    }
    if (hour < 0 || hour > 23) {
      return ToolResult.error('Invalid hour: $hour. Must be 0-23.');
    }
    if (minutes < 0 || minutes > 59) {
      return ToolResult.error('Invalid minutes: $minutes. Must be 0-59.');
    }

    final message = arguments['message'] as String? ?? '';
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

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
```

---

## Registration Changes

### `lib/providers/app_providers.dart`

Add imports (alphabetical, after existing tool imports):

```dart
import '../core/tools/clipboard_tool.dart';
import '../core/tools/device_info_tool.dart';
import '../core/tools/open_app_tool.dart';
import '../core/tools/set_alarm_tool.dart';
import '../core/tools/speak_tool.dart';
```

Add registrations inside `toolRegistryProvider` (after existing tools, before `return registry`):

```dart
if (!disabled.contains('clipboard')) {
  registry.register(ClipboardTool());
}
if (!disabled.contains('device_info')) {
  registry.register(DeviceInfoTool());
}
if (!disabled.contains('speak')) {
  registry.register(SpeakTool());
}
if (!disabled.contains('open_app')) {
  registry.register(OpenAppTool());
}
if (!disabled.contains('set_alarm')) {
  registry.register(SetAlarmTool());
}
```

### `lib/core/agent/service_agent_factory.dart`

Add import:

```dart
import '../tools/device_info_tool.dart';
```

Add registration (after `get_address` block):

```dart
if (!disabled.contains('device_info')) {
  registry.register(DeviceInfoTool());
}
// Excluded from service isolate:
// - WebScrapeJsTool (WebView needs Activity)
// - SubagentTool (self-referential, complex lifecycle)
// - MessageTool (no UI in service isolate)
// - ClipboardTool (read requires foreground on Android 10+)
// - SpeakTool (audio focus, no user context)
// - OpenAppTool (launches Activity, jarring from background)
// - SetAlarmTool (opens Clock app, jarring from background)
```

### `lib/features/settings/tools_config_screen.dart`

Add to `_tools` list:

```dart
_ToolInfo(name: 'clipboard',    label: 'Clipboard',       description: 'Read and write device clipboard',              icon: Icons.content_paste),
_ToolInfo(name: 'device_info',  label: 'Device Info',     description: 'Battery, connectivity, device model',          icon: Icons.phone_android),
_ToolInfo(name: 'speak',        label: 'Text to Speech',  description: 'Speak text aloud (foreground only)',           icon: Icons.volume_up),
_ToolInfo(name: 'open_app',     label: 'Open App / URL',  description: 'Open URLs, phone, maps, email on device',     icon: Icons.open_in_new),
_ToolInfo(name: 'set_alarm',    label: 'Alarm / Timer',   description: 'Set alarms and timers via system Clock app',   icon: Icons.alarm),
```

### Default disabled tools

In `lib/core/config/app_config.dart`, add `speak`, `open_app`, `set_alarm` to the default `disabledTools` set so they are off by default:

```dart
// In ToolsConfig.defaults() or equivalent:
disabledTools: {'speak', 'open_app', 'set_alarm'},
```

---

## Implementation Order

Each tool is independent. Implement sequentially for clean commits:

### Step 1: Add dependencies
- `flutter pub add battery_plus device_info_plus flutter_tts android_intent_plus`
- `flutter pub get`

### Step 2: AndroidManifest changes
- Add `SET_ALARM` permission
- Add `<queries>` for alarm intents

### Step 3: clipboard_tool.dart
- Create file, register in app_providers, add settings toggle

### Step 4: device_info_tool.dart
- Create file, register in app_providers AND service_agent_factory, add settings toggle

### Step 5: speak_tool.dart
- Create file, register in app_providers, add settings toggle

### Step 6: open_app_tool.dart
- Create file, register in app_providers, add settings toggle

### Step 7: set_alarm_tool.dart
- Create file, register in app_providers, add settings toggle

### Step 8: Default disabled tools
- Update ToolsConfig defaults for speak, open_app, set_alarm

### Step 9: Update README
- Add 5 new tools to tools table
- Update tool count (8 → 13)
- Add to service isolate compatibility table

### Step 10: Verify
- `flutter analyze` — 0 issues
- `flutter build apk --release --split-per-abi`

## Acceptance Criteria

- [ ] All 5 tool files created in `lib/core/tools/`
- [ ] All tools registered in `app_providers.dart` with disabled check
- [ ] `device_info` also registered in `service_agent_factory.dart`
- [ ] All 5 toggles visible in Settings > Tools
- [ ] `speak`, `open_app`, `set_alarm` disabled by default
- [ ] `clipboard`, `device_info` enabled by default
- [ ] `SET_ALARM` permission in AndroidManifest
- [ ] `<queries>` for alarm intents in AndroidManifest
- [ ] 4 new packages in pubspec.yaml
- [ ] README updated with 13 tools
- [ ] `flutter analyze` passes with 0 issues
- [ ] APK builds successfully

## References

- Tool base class: `lib/core/tools/tool.dart`
- Registration: `lib/providers/app_providers.dart:77-114`
- Settings: `lib/features/settings/tools_config_screen.dart:21`
- Service factory: `lib/core/agent/service_agent_factory.dart:67-96`
- Manifest: `android/app/src/main/AndroidManifest.xml`
- Parent plan: `docs/plans/2026-02-17-feat-new-android-native-tools-plan.md`
- Service isolate checklist: `docs/solutions/architecture/enable-location-tools-in-service-isolate.md`
