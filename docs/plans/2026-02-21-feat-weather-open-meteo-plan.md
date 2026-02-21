---
title: "feat: Add weather tool (Open-Meteo with Météo-France models)"
type: feat
date: 2026-02-21
---

# Add weather tool (Open-Meteo with Météo-France models)

## Overview

Add a `weather` tool that fetches weather forecasts using the Open-Meteo API with Météo-France models (AROME 1.3km + ARPEGE). No API key required, pure HTTP GET, free for non-commercial use.

## API

**Endpoint**: `GET https://api.open-meteo.com/v1/meteofrance`

**No authentication required.**

**Parameters**:
- `latitude`, `longitude` — GPS coordinates
- `hourly` — comma-separated variable list
- `daily` — comma-separated daily aggregates
- `timezone=auto` — auto-detect from coordinates
- `forecast_days` — number of days (1-16, default 2)

**Hourly variables**: `temperature_2m`, `relative_humidity_2m`, `precipitation`, `wind_speed_10m`, `weather_code`

**Daily variables**: `temperature_2m_max`, `temperature_2m_min`, `precipitation_sum`, `wind_speed_10m_max`, `weather_code`

**WMO Weather Codes**:
- 0: Clear sky
- 1-3: Partly cloudy / Overcast
- 45-48: Fog
- 51-57: Drizzle
- 61-67: Rain
- 71-77: Snow
- 80-82: Rain showers
- 85-86: Snow showers
- 95-99: Thunderstorm

## Technical Approach

### Pattern: follows `ReverseGeocodeTool` (pure HTTP, no API key)

| Aspect | ReverseGeocodeTool | WeatherTool (new) |
|--------|-------------------|-------------------|
| API key | None | None |
| Endpoint | Nominatim (OSM) | Open-Meteo (Météo-France) |
| HTTP method | GET | GET |
| Service isolate | Yes | Yes |
| Dependencies | `package:http` | `package:http` (already in pubspec) |

### File: `lib/core/tools/weather_tool.dart` (NEW)

```dart
class WeatherTool extends Tool {
  @override String get name => 'weather';

  @override Map<String, dynamic> get parameters => {
    'latitude': { 'type': 'number', required },
    'longitude': { 'type': 'number', required },
    'days': { 'type': 'integer', optional, default: 2, description: '1-7' },
  };
}
```

**Two operations in one call**:
- **Daily summary** (default): min/max temp, precipitation, wind, weather condition per day
- **Hourly detail**: temperature, humidity, precipitation, wind, weather code per period (morning/afternoon/evening)

**Output** (dual ToolResult):
- `forLLM`: Full structured data — daily summaries + hourly breakdown for all requested days
- `forUser`: Compact summary — "Today: 8-15°C, Rain, 12mm | Tomorrow: 5-11°C, Cloudy"

**WMO code interpretation**: Static map from code to French description (Soleil, Nuageux, Pluie, Neige, Orage, etc.)

### Registration

Same as `get_address` (no constructor params, no API key):

**`app_providers.dart`**:
```dart
if (!disabled.contains('weather')) {
  registry.register(WeatherTool());
}
```

**`service_agent_factory.dart`**: Same pattern — pure HTTP, service isolate safe.

**`tools_config_screen.dart`**: Toggle with `Icons.cloud_outlined`.

### No new dependency needed

Uses `package:http` already in pubspec.yaml.

## Acceptance Criteria

- [x] `WeatherTool` created in `lib/core/tools/weather_tool.dart`
- [x] Returns daily forecast (min/max temp, precipitation, wind, weather condition)
- [x] Returns hourly breakdown by period (morning/afternoon/evening)
- [x] WMO weather codes interpreted to human-readable French descriptions
- [x] Handles API errors gracefully
- [x] Registered in `app_providers.dart` (main isolate)
- [x] Registered in `service_agent_factory.dart` (service isolate)
- [x] Toggle added in `tools_config_screen.dart`
- [x] README.md updated (count, tables)
- [x] `flutter analyze` passes with 0 issues
- [x] APK builds successfully

## Files

| File | Change |
|------|--------|
| `lib/core/tools/weather_tool.dart` | **NEW** — WeatherTool implementation |
| `lib/providers/app_providers.dart` | Register WeatherTool |
| `lib/core/agent/service_agent_factory.dart` | Register WeatherTool |
| `lib/features/settings/tools_config_screen.dart` | Add toggle |
| `README.md` | Update counts and tables |

## Notes

- No API key — Open-Meteo is free for non-commercial use
- Uses `/v1/meteofrance` endpoint for AROME/ARPEGE models (high precision for France)
- Coordinates come from `get_location` or `geocode` — the LLM chains tools naturally
- Rate limits: generous (no strict limit published), but avoid excessive polling
- Service isolate compatible — pure HTTP, no platform channels
