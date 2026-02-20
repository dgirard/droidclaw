---
title: "feat: Add routing tools (ORS directions + Navitia transit)"
type: feat
date: 2026-02-17
---

# feat: Add routing tools (ORS directions + Navitia transit)

## Overview

Add two routing tools to DroidClaw:
1. **`get_directions`** — Car/bike/walk routing via OpenRouteService (ORS) API v2
2. **`get_transit`** — Public transit routing via Navitia.io API (RATP, SNCF, regional buses)

Both are pure HTTP tools (service isolate compatible), follow the Brave API key pattern, and chain naturally with the existing `get_location` + `get_address` tools.

## Motivation

The agent can already get GPS coordinates (`get_location`) and resolve addresses (`get_address`), but cannot calculate routes. Users need:
- "How long to drive from here to Lyon?"
- "Best cycling route from home to work?"
- "What metro should I take to get to Gare de Lyon?"
- "Can I walk there in 15 minutes?" (isochrones)

## Technical Approach

### Phase 1: `get_directions` tool (OpenRouteService)

**API**: `POST https://api.openrouteservice.org/v2/directions/{profile}`

**Authentication**: `Authorization: API_KEY` header (free tier: 2,000 directions/day, 40/min)

**Profiles**: `driving-car`, `cycling-regular`, `cycling-road`, `cycling-mountain`, `foot-walking`, `foot-hiking`, `wheelchair`

#### Files to Create

##### `lib/core/tools/directions_tool.dart`

```dart
class DirectionsTool extends Tool {
  final String? apiKey;
  DirectionsTool({this.apiKey});

  @override String get name => 'get_directions';
  @override String get description =>
    'Calculate a route between two points by car, bike, or foot. '
    'Returns distance, duration, and turn-by-turn instructions. '
    'Coordinates: use get_location for current position or provide lat/lon. '
    'Requires an OpenRouteService API key (free at openrouteservice.org).';

  // Parameters:
  //   origin_lat, origin_lon (required)
  //   dest_lat, dest_lon (required)
  //   mode: "car" | "bike" | "walk" | "wheelchair" (default: "car")
  //   language: "fr" | "en" | ... (default: "fr")
}
```

**Operations**:
- `directions` (default): route between two points with summary + instructions
- `isochrones`: what's reachable in N minutes from a point

**Mode mapping**:

| User-facing mode | ORS profile |
|---|---|
| `car` | `driving-car` |
| `bike` | `cycling-regular` |
| `road_bike` | `cycling-road` |
| `mtb` | `cycling-mountain` |
| `walk` | `foot-walking` |
| `hike` | `foot-hiking` |
| `wheelchair` | `wheelchair` |

**Request** (directions):
```json
{
  "coordinates": [[origin_lon, origin_lat], [dest_lon, dest_lat]],
  "instructions": true,
  "language": "fr",
  "units": "km",
  "elevation": true
}
```

**ToolResult.dual** format:
- `forLLM`: Full structured data — distance, duration, steps with names, elevation gain/loss, warnings
- `forUser`: Clean summary — "Paris → Lyon: 465 km, 4h12 by car"

**Error handling**:
- No API key → `ToolResult.error('OpenRouteService API key not configured. Set it in Settings > Routing.')`
- HTTP error → parse ORS error JSON (`{"error": {"code": 2004, "message": "..."}}`)
- Rate limit (429) → `ToolResult.error('Rate limit exceeded. Try again in a minute.')`

**Isochrones operation**:
```json
{
  "locations": [[lon, lat]],
  "range": [900],
  "range_type": "time",
  "attributes": ["area"]
}
```
Returns: "From this point, you can reach 12.5 km² in 15 minutes by car."

##### `lib/features/settings/routing_config_screen.dart`

Modeled on `web_search_config_screen.dart`:
- TextFormField for ORS API key
- "Test" button: calls ORS with a short Paris→Versailles route
- "Save" button: persists key, invalidates `toolRegistryProvider`
- Link to registration: `https://openrouteservice.org/dev/#/home`
- Section for Navitia key (Phase 2, initially hidden/disabled)

#### Files to Modify

| File | Change |
|------|--------|
| `lib/core/config/config_storage.dart` | Add `getOrsApiKey()` / `setOrsApiKey()` |
| `lib/shared/constants.dart` | Add `cachedOrsApiKeyKey` |
| `lib/providers/app_providers.dart` | Import tool, fetch ORS key, register in `toolRegistryProvider` |
| `lib/providers/background_service_provider.dart` | Cache ORS key in `_cacheSecretsForService()` |
| `lib/core/agent/service_agent_factory.dart` | Add `orsApiKey` param, register `DirectionsTool` |
| `lib/core/services/background_task_handler.dart` | Pass `cachedOrsApiKeyKey` to factory |
| `lib/features/settings/tools_config_screen.dart` | Add toggle for `get_directions` |
| `lib/features/settings/settings_screen.dart` | Add ListTile for routing config |
| `lib/app.dart` | Add route `/settings/routing` |
| `README.md` | Update tool count, descriptions, availability table |

### Phase 2: `get_transit` tool (Navitia.io)

**API**: `GET https://api.navitia.io/v1/journeys?from={lon};{lat}&to={lon};{lat}`

**Authentication**: HTTP Basic Auth (`Authorization: Basic base64(TOKEN:)`) — free tier: ~5,000 req/month

**Coverage**: All of France (5 regions: `fr-idf`, `fr-ne`, `fr-nw`, `fr-se`, `fr-sw`) — RATP (metro, bus, tram, RER), SNCF (TGV, TER, Transilien), regional bus networks.

##### `lib/core/tools/transit_tool.dart`

```dart
class TransitTool extends Tool {
  final String? apiKey;
  TransitTool({this.apiKey});

  @override String get name => 'get_transit';
  @override String get description =>
    'Find public transit routes in France (metro, bus, train, RER, tram). '
    'Covers all French regions including Ile-de-France (RATP), national trains (SNCF), '
    'and regional networks. Returns departure times, transfers, and walking sections. '
    'Requires a Navitia.io API key (free at navitia.io).';

  // Parameters:
  //   origin_lat, origin_lon (required)
  //   dest_lat, dest_lon (required)
  //   datetime (optional, ISO 8601, default: now)
  //   datetime_represents: "departure" | "arrival" (default: "departure")
  //   wheelchair: bool (default: false)
}
```

**Request**:
```
GET /v1/journeys?from={lon};{lat}&to={lon};{lat}&datetime=20260220T080000&data_freshness=realtime
```

**ToolResult.dual** format:
- `forLLM`: Full journey data — sections (walk, metro line 6, transfer, RER C, walk), departure/arrival times, duration, transfers count, CO2, fare
- `forUser`: "Metro 6 + RER C, 44 min, 1 transfer, 1.90 EUR"

**Multimodal**: Navitia natively combines walking + transit. `first_section_mode[]` and `last_section_mode[]` support bike, bike-share (`bss`), car.

##### Files to Modify (Phase 2)

Same pattern as Phase 1:
- `config_storage.dart` → `getNavitiaApiKey()` / `setNavitiaApiKey()`
- `constants.dart` → `cachedNavitiaApiKeyKey`
- `routing_config_screen.dart` → add Navitia key section
- Full service isolate plumbing (same pattern)

### Future: IDFM/PRIM API (Optional Enhancement)

For higher quota in Ile-de-France (1,000 req/day vs Navitia's 5,000/month), the tool could auto-detect Paris-region coordinates and route to the PRIM API instead:

```
GET https://prim.iledefrance-mobilites.fr/marketplace/v2/navitia/journeys?from=...&to=...
```

Same Navitia response format, different base URL and auth header (`apikey: KEY`). This is a transparent optimization — no user-facing change.

## Acceptance Criteria

### Phase 1 (MVP)

- [x] `get_directions` tool with directions + isochrones operations
- [x] Supports car, bike (3 variants), walk, hike, wheelchair modes
- [x] Returns distance, duration, elevation gain/loss, turn-by-turn instructions (French)
- [x] ORS API key stored in FlutterSecureStorage, cached for service isolate
- [x] Settings screen with key input, test button, save
- [x] Works in service isolate (pure HTTP — cron can use it)
- [x] Tool toggle in Settings > Tools
- [x] Graceful error on missing key, rate limit, invalid coordinates
- [x] `flutter analyze` passes

### Phase 2

- [ ] `get_transit` tool with Navitia.io integration
- [ ] Returns journey sections (walk + transit lines + transfers)
- [ ] Shows departure times, line names/colors, transfer count, fare, CO2
- [ ] Navitia API key in settings screen (second section on routing config)
- [ ] Service isolate compatible
- [ ] Wheelchair-accessible route option

## LLM Chaining Examples

The agent naturally chains tools:

1. **"How long to drive to Lyon?"**
   → `get_location` → `get_directions(origin=here, dest=Lyon, mode=car)`

2. **"What's the fastest way to Gare du Nord?"**
   → `get_location` → `get_transit(origin=here, dest=Gare du Nord)` + `get_directions(origin=here, dest=Gare du Nord, mode=car)` → compare

3. **"Set an alarm for 6:30 AM, I need to be at work by 8:00"**
   → `get_transit(origin=home, dest=work, datetime_represents=arrival, datetime=08:00)` → verify departure time → `volume_control(get)` → check alarm volume → `set_alarm(hour=6, minutes=30)`

4. **"What can I reach in 15 minutes on foot?"**
   → `get_location` → `get_directions(operation=isochrones, origin=here, mode=walk, range=900)`

## Dependencies & Risks

- **No new packages**: both APIs use standard `http.get`/`http.post` (already in project via `package:http`)
- **Rate limits**: ORS free tier (2,000/day) is generous for personal use. Navitia (5,000/month) is tighter — may need IDFM/PRIM fallback for heavy Paris usage
- **Coordinates order**: ORS uses `[longitude, latitude]` (GeoJSON standard), NOT `[lat, lon]`. The tool must handle this internally
- **API key registration**: Users must create accounts on openrouteservice.org and navitia.io. Both are free and instant.

## References

### Internal
- `lib/core/tools/web_search_tool.dart` — API key injection pattern
- `lib/core/tools/reverse_geocode_tool.dart` — HTTP GET tool pattern (Nominatim)
- `lib/core/tools/location_tool.dart` — GPS coordinates source
- `lib/features/settings/web_search_config_screen.dart` — API key settings screen pattern
- `lib/core/config/config_storage.dart` — secure key storage methods
- `lib/providers/background_service_provider.dart:_cacheSecretsForService()` — secret caching pattern

### External
- [OpenRouteService API v2 — Directions](https://giscience.github.io/openrouteservice/api-reference/endpoints/directions/)
- [OpenRouteService API v2 — Isochrones](https://giscience.github.io/openrouteservice/api-reference/endpoints/isochrones/)
- [OpenRouteService Free Tier Limits](https://openrouteservice.org/plans/)
- [Navitia.io Documentation](https://doc.navitia.io/)
- [Navitia.io Pricing](https://navitia.io/en/tarifs/)
- [IDFM/PRIM API](https://prim.iledefrance-mobilites.fr/en/apis/idfm-navitia-general-v2)
