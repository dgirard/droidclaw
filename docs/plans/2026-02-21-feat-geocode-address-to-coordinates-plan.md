---
title: "feat: Add geocode tool (address to GPS coordinates via ORS)"
type: feat
date: 2026-02-21
---

# Add geocode tool (address to GPS coordinates via ORS)

## Overview

Add a `geocode` tool that converts a text address into GPS coordinates using the OpenRouteService Geocoding API (`/geocode/search`). This is the complement of the existing `get_address` tool (reverse geocoding: coords to address). It reuses the same ORS API key already configured for `get_directions`.

## Motivation

The agent currently can:
- Get the device's GPS position (`get_location`)
- Convert GPS coords to address (`get_address` via Nominatim)
- Route between two GPS points (`get_directions` via ORS)
- Find transit routes (`get_transit` via Navitia)

Missing link: the agent cannot convert a user-provided address (e.g. "Tour Eiffel, Paris") into GPS coordinates. This forces the user to provide lat/lon manually for routing. With `geocode`, the agent can chain: geocode("Tour Eiffel") -> get_directions(origin, dest).

## API

**Endpoint**: `GET https://api.openrouteservice.org/geocode/search`

**Auth**: `Authorization: {orsApiKey}` header (same as `get_directions`)

**Parameters**:
- `api_key` or `Authorization` header
- `text` — the address to search
- `size` — max results (default 1)
- `boundary.country` — optional country filter (ISO 3166-1 alpha-2)

**Response**: GeoJSON FeatureCollection. Coordinates in `[longitude, latitude]` order.

**Key fields per feature**:
- `geometry.coordinates` — `[lon, lat]`
- `properties.label` — full formatted address
- `properties.confidence` — match confidence (0-1)
- `properties.country`, `properties.region`, `properties.locality`

**Rate limits (free tier)**: 1,000 requests/day, 100/minute.

## Technical Approach

### Pattern: follows `DirectionsTool` exactly

| Aspect | DirectionsTool | GeocodeTool (new) |
|--------|---------------|-------------------|
| API key | `orsApiKey` via constructor | Same `orsApiKey` via constructor |
| Base URL | `api.openrouteservice.org/v2` | `api.openrouteservice.org/geocode/search` |
| HTTP method | POST | GET |
| Auth header | `Authorization: apiKey` | `Authorization: apiKey` |
| Service isolate | Yes (pure HTTP) | Yes (pure HTTP) |

### File: `lib/core/tools/geocode_tool.dart` (NEW)

```dart
class GeocodeTool extends Tool {
  final String? apiKey;
  GeocodeTool({this.apiKey});

  @override String get name => 'geocode';
  @override String get description => ...;
  @override Map<String, dynamic> get parameters => {
    'address': { 'type': 'string', required },
    'country': { 'type': 'string', optional, description: 'ISO country code' },
    'max_results': { 'type': 'integer', optional, default: 3 },
  };

  @override Future<ToolResult> execute(...) async {
    // GET https://api.openrouteservice.org/geocode/search?text=...&size=...
    // Authorization: apiKey
    // Parse GeoJSON, return top results with lat, lon, label, confidence
  }
}
```

**Output format** (dual ToolResult):
- `forLLM`: structured text with lat, lon, label, confidence for each result
- `forUser`: "Tour Eiffel, Paris (48.8584, 2.2945) confidence: 0.95"

### Registration: `lib/providers/app_providers.dart`

```dart
if (!disabled.contains('geocode')) {
  registry.register(GeocodeTool(apiKey: orsApiKey));
}
```

No new API key needed — reuses `orsApiKey` already fetched on line ~47.

### Registration: `lib/core/agent/service_agent_factory.dart`

```dart
if (!disabled.contains('geocode')) {
  registry.register(GeocodeTool(apiKey: orsApiKey));
}
```

Reuses `orsApiKey` already passed as parameter.

### Registration: `lib/core/services/background_task_handler.dart`

No changes — `orsApiKey` is already cached and passed to `ServiceAgentFactory.create()`.

### Toggle: `lib/features/settings/tools_config_screen.dart`

Add entry in `_tools` list:
```dart
_ToolInfo(
  name: 'geocode',
  label: 'Geocode',
  description: 'Convert address to GPS coordinates (ORS)',
  icon: Icons.pin_drop_outlined,
),
```

### Test button: `lib/features/settings/routing_config_screen.dart`

Add a test button in the ORS section to test geocoding (e.g. "Tour Eiffel, Paris").

### README.md

- Update tool count (22 -> 23)
- Add `geocode` row to tools table
- Add to service isolate availability table

## Acceptance Criteria

- [x] `GeocodeTool` created in `lib/core/tools/geocode_tool.dart`
- [x] Returns top N results with lat, lon, formatted label, confidence
- [x] Handles missing API key with clear error message
- [x] Handles API errors (429 rate limit, 4xx/5xx)
- [x] Registered in `app_providers.dart` (main isolate)
- [x] Registered in `service_agent_factory.dart` (service isolate)
- [x] Toggle added in `tools_config_screen.dart`
- [x] Test button added in `routing_config_screen.dart` ORS section
- [x] README.md updated (count, table, availability)
- [x] `flutter analyze` passes with 0 issues
- [x] APK builds successfully

## Files

| File | Change |
|------|--------|
| `lib/core/tools/geocode_tool.dart` | **NEW** — GeocodeTool implementation |
| `lib/providers/app_providers.dart` | Register GeocodeTool |
| `lib/core/agent/service_agent_factory.dart` | Register GeocodeTool |
| `lib/features/settings/tools_config_screen.dart` | Add toggle |
| `lib/features/settings/routing_config_screen.dart` | Add test button |
| `README.md` | Update counts and tables |

## Notes

- Coordinate order: ORS returns `[lon, lat]` (GeoJSON) — tool must present as `lat, lon` to user/LLM
- No new dependency needed — uses `package:http` already in pubspec
- No new API key — reuses existing ORS key from Settings > Routing
- Service isolate compatible — pure HTTP, no platform channels
