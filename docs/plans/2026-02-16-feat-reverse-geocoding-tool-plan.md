---
title: "feat: Add reverse geocoding tool (GPS coords to address)"
type: feat
date: 2026-02-16
---

# Add Reverse Geocoding Tool

## Overview

Add a `get_address` tool that converts GPS coordinates (latitude, longitude) into a human-readable address using the Nominatim (OpenStreetMap) reverse geocoding API. Free, no API key, no new dependency (`http` already present).

The LLM can chain this with `get_location`: first get GPS coords, then resolve to an address.

## Implementation

### 1. Create the tool

**`lib/core/tools/reverse_geocode_tool.dart`** — NEW

```dart
class ReverseGeocodeTool extends Tool {
  @override String get name => 'get_address';

  @override String get description =>
      'Convert GPS coordinates (latitude, longitude) into a human-readable '
      'street address using reverse geocoding. '
      'Use after get_location to know the actual address of the device.';

  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'latitude': {'type': 'number', 'description': 'Latitude'},
      'longitude': {'type': 'number', 'description': 'Longitude'},
    },
    'required': ['latitude', 'longitude'],
  };
}
```

**Pipeline:**
1. Call Nominatim: `GET https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat={lat}&lon={lon}`
2. Headers: `User-Agent: DroidClaw/1.0`, `Accept-Language: fr` (for French results)
3. Parse JSON response: extract `display_name` for full address, `address` object for structured details
4. Return `ToolResult.dual()`:
   - `forLLM`: full address + structured details (city, road, postcode, country)
   - `forUser`: short display address

### 2. Register the tool

**`lib/providers/app_providers.dart`** — in `toolRegistryProvider`:

```dart
if (!disabled.contains('get_address')) {
  registry.register(ReverseGeocodeTool());
}
```

### 3. Add to settings UI

**`lib/features/settings/tools_config_screen.dart`** — add entry:

```dart
_ToolInfo(
  name: 'get_address',
  label: 'Reverse Geocoding',
  description: 'Convert GPS coordinates to address',
  icon: Icons.pin_drop_outlined,
),
```

### 4. No new dependencies

Uses `http` (already in pubspec) + `dart:convert` (built-in). Nominatim is free, no API key required.

### 5. Rate limiting note

Nominatim usage policy: max 1 request per second. Since the LLM only calls this tool occasionally (after `get_location`), this is not an issue. No rate limiting code needed.

## Acceptance Criteria

- [x] `ReverseGeocodeTool` created in `lib/core/tools/reverse_geocode_tool.dart`
- [x] Tool registered in `toolRegistryProvider` with disable check
- [x] Tool added to settings UI
- [x] Uses Nominatim API with proper `User-Agent` header
- [x] Returns structured address in `forLLM`, short address in `forUser`
- [x] Handles errors (network, invalid coords, no result)
- [x] `flutter analyze` passes
- [x] APK builds and installs
- [ ] Test: after `get_location`, LLM can chain `get_address` to tell user their address

## Files Changed

| File | Change |
|------|--------|
| `lib/core/tools/reverse_geocode_tool.dart` | **NEW** — Nominatim reverse geocoding |
| `lib/providers/app_providers.dart` | Register tool + add import |
| `lib/features/settings/tools_config_screen.dart` | Add toggle entry |

## References

- `lib/core/tools/location_tool.dart` — existing GPS tool (provides coords)
- `lib/core/tools/tool.dart` — Tool, ToolResult
- `lib/providers/app_providers.dart:82-107` — tool registration pattern
- [Nominatim Reverse Geocoding API](https://nominatim.org/release-docs/develop/api/Reverse/)
- [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/) — max 1 req/s, requires User-Agent
