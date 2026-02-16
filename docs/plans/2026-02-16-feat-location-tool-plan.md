---
title: "feat: Add location tool for GPS/network geolocation"
type: feat
date: 2026-02-16
---

# Add Location Tool for GPS/Network Geolocation

## Overview

When the user asks "where am I?" or any location-related question, the LLM should be able to call a `get_location` tool that returns the device's current GPS coordinates. The LLM decides autonomously when to call this tool based on context — no special keyword detection needed.

## How It Works

The tool system already handles this elegantly:
1. The `get_location` tool is registered with a clear description in the tool registry
2. The LLM sees it in the available tools list and decides when to call it
3. When called, it requests device location via the `geolocator` package
4. Returns coordinates as a `ToolResult.dual()` — coords for LLM, friendly message for user

The LLM naturally understands that "where am I?", "my location", "nearby restaurants", etc. require location data and will call the tool.

## Implementation

### 1. Add dependency

**`pubspec.yaml`**

```yaml
geolocator: ^14.0.0
```

### 2. Add Android permission

**`android/app/src/main/AndroidManifest.xml`**

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

`ACCESS_FINE_LOCATION` gives GPS + network. Geolocator uses Android's `FusedLocationProviderClient` which automatically falls back to network if GPS is unavailable.

### 3. Create the tool

**`lib/core/tools/location_tool.dart`**

```dart
class LocationTool extends Tool {
  @override
  String get name => 'get_location';

  @override
  String get description =>
      'Get the device current GPS location (latitude, longitude). '
      'Use when the user asks about their location or needs nearby information.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},  // No arguments needed
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    // 1. Check if location services are enabled
    // 2. Check/request permission
    // 3. Get current position (timeout 10s, high accuracy)
    // 4. Return ToolResult.dual(
    //      forLLM: 'Current location: lat=48.8566, lon=2.3522, accuracy=12m',
    //      forUser: 'Location acquired (48.8566, 2.3522)',
    //    )
    // On error: ToolResult.error('Location unavailable: ...')
  }
}
```

### 4. Register the tool

**`lib/providers/app_providers.dart`** — in `toolRegistryProvider`:

```dart
registry.register(LocationTool());
```

### 5. No UI changes needed

The tool integrates into the existing agent loop. The LLM calls it, gets coordinates, and can then answer location-related questions or combine with web_search for nearby info.

## Acceptance Criteria

- [ ] `geolocator` package added to pubspec.yaml
- [ ] `ACCESS_FINE_LOCATION` permission in AndroidManifest.xml
- [ ] `LocationTool` created in `lib/core/tools/location_tool.dart`
- [ ] Tool registered in `toolRegistryProvider`
- [ ] Handles permission denied gracefully (returns error ToolResult)
- [ ] Handles location services disabled gracefully
- [ ] Handles timeout (10s max)
- [ ] Uses `ToolResult.dual()` pattern: full coords for LLM, short summary for user
- [ ] `flutter analyze` passes
- [ ] APK builds and installs
- [ ] Asking "where am I?" triggers the tool and returns coordinates

## Files Changed

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `geolocator: ^14.0.0` |
| `android/app/src/main/AndroidManifest.xml` | Add `ACCESS_FINE_LOCATION` permission |
| `lib/core/tools/location_tool.dart` | **NEW** — LocationTool implementation |
| `lib/providers/app_providers.dart` | Register LocationTool in toolRegistryProvider |

## References

- `lib/core/tools/tool.dart` — Tool abstract class, ToolResult
- `lib/core/tools/web_search_tool.dart` — Example tool to follow
- `lib/providers/app_providers.dart:74-92` — Tool registration
- Package: [geolocator ^14.0.0](https://pub.dev/packages/geolocator)
