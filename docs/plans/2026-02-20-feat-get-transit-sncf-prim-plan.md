---
title: "feat: Add get_transit tool (SNCF + PRIM/IDFM public transit)"
type: feat
date: 2026-02-20
---

# feat: Add get_transit tool (SNCF + PRIM/IDFM public transit)

## Overview

Add a `get_transit` tool for public transit routing in France using two complementary Navitia-based APIs:

- **PRIM/IDFM** — Île-de-France transit (Metro, RER, Bus, Tram, Transilien). Higher precision, real-time data for Paris region.
- **SNCF** — National routes (TGV, Intercités, TER). Covers all of France.

Both APIs return identical Navitia v1 JSON, so the parsing code is shared. The tool auto-routes requests based on GPS coordinates: IDF-only trips use PRIM, everything else uses SNCF.

## Motivation

The agent can already calculate car/bike/walk routes (`get_directions`), get GPS coordinates (`get_location`), and resolve addresses (`get_address`). Adding transit completes the mobility picture:

- "How do I get to Gare du Nord by metro?"
- "What time is the next train to Lyon?"
- "Set an alarm for my morning commute — I need to arrive at 8:00"
- Cron: "Check my commute every morning at 6:30 and notify me of delays"

## Technical Approach

### API Configuration

| | SNCF | PRIM (IDFM) |
|---|---|---|
| **Base URL** | `https://api.sncf.com/v1/coverage/sncf/journeys` | `https://prim.iledefrance-mobilites.fr/marketplace/v2/navitia/journeys` |
| **Auth header** | `Authorization: {token}` | `apiKey: {token}` |
| **Free quota** | 5,000 req/day | 1,000 req/day |
| **Coverage** | All France (TGV, TER, Intercités) | Île-de-France (Metro, RER, Bus, Tram, Transilien) |
| **Coordinate format** | `lon;lat` (semicolon, GeoJSON order) | `lon;lat` (same) |

### Auto-Routing Logic

The tool decides which API to call based on coordinates:

```
If BOTH origin AND destination are within IDF bounding box:
  → Use PRIM (if key configured)
  → Fallback to SNCF (if no PRIM key)
Else:
  → Use SNCF (if key configured)
  → Fallback to PRIM (if no SNCF key, IDF trip)
  → Error if no key at all
```

**Île-de-France bounding box** (generous, includes suburban rail endpoints):
- Latitude: 48.1 — 49.25
- Longitude: 1.4 — 3.6

### Navitia `/journeys` Request

Both APIs accept the same parameters:

```
GET {base_url}?from={origin_lon};{origin_lat}&to={dest_lon};{dest_lat}&datetime={YYYYMMDDTHHMMSS}&datetime_represents={departure|arrival}&wheelchair={true|false}&data_freshness=realtime
```

### Navitia Journey Response Structure

```json
{
  "journeys": [{
    "duration": 2671,
    "nb_transfers": 1,
    "departure_date_time": "20260220T080000",
    "arrival_date_time": "20260220T084431",
    "co2_emission": {"unit": "gEC", "value": 24.6},
    "sections": [
      {
        "type": "street_network",
        "mode": "walking",
        "duration": 300,
        "from": {"name": "Rue Abel"},
        "to": {"name": "Gare de Lyon"}
      },
      {
        "type": "public_transport",
        "duration": 1200,
        "from": {"name": "Gare de Lyon", "stop_point": {...}},
        "to": {"name": "Bir-Hakeim", "stop_point": {...}},
        "display_informations": {
          "physical_mode": "Métro",
          "commercial_mode": "Metro",
          "label": "6",
          "code": "6",
          "direction": "Charles de Gaulle — Étoile",
          "color": "79BB92",
          "network": "RATP"
        },
        "stop_date_times": [...]
      },
      {
        "type": "transfer",
        "duration": 180
      },
      {
        "type": "public_transport",
        "duration": 600,
        "display_informations": {
          "physical_mode": "RapidTransit",
          "label": "C",
          "direction": "Pontoise",
          "color": "FFCD00"
        }
      }
    ]
  }]
}
```

### Physical Mode Mapping (for display)

| Navitia `physical_mode` | French display |
|---|---|
| `Métro` / `Metro` | Métro |
| `RapidTransit` | RER |
| `Bus` | Bus |
| `Tramway` | Tram |
| `Train` / `LocalTrain` | Train |
| `LongDistanceTrain` | TGV/Intercités |
| `Funicular` | Funiculaire |

### ToolResult.dual() Format

**forUser** (clean one-line summary):
```
Métro 6 → RER C, 44 min, 1 correspondance
Départ 08:00 → Arrivée 08:44
```

**forLLM** (full structured data):
```
Route: Rue Abel → Bir-Hakeim Tour Eiffel
Duration: 44 min (2671 seconds)
Transfers: 1
CO2: 24.6 gEC
API: PRIM (Île-de-France)

Sections:
1. [walking] 5 min — Rue Abel → Gare de Lyon
2. [Métro 6] 20 min — Gare de Lyon → Bir-Hakeim (direction: Charles de Gaulle — Étoile)
3. [transfer] 3 min
4. [RER C] 10 min — Bir-Hakeim → Destination (direction: Pontoise)
5. [walking] 6 min — Station → Destination
```

## Files to Create

### `lib/core/tools/transit_tool.dart`

```dart
class TransitTool extends Tool {
  final String? sncfApiKey;
  final String? primApiKey;
  TransitTool({this.sncfApiKey, this.primApiKey});

  @override String get name => 'get_transit';
  @override String get description =>
    'Find public transit routes in France (metro, RER, bus, tram, train). '
    'Covers Île-de-France (RATP, Transilien) and national trains (TGV, TER, Intercités). '
    'Auto-selects the best API based on trip location. '
    'Coordinates: use get_location for current position or provide lat/lon. '
    'Chains with get_address to resolve place names to coordinates.';

  // Parameters:
  //   origin_lat, origin_lon (required)
  //   dest_lat, dest_lon (required)
  //   datetime (optional, ISO 8601 YYYYMMDDTHHMMSS, default: now)
  //   datetime_represents: "departure" | "arrival" (default: "departure")
  //   wheelchair: bool (default: false)

  static const _idfBounds = (
    minLat: 48.1, maxLat: 49.25,
    minLon: 1.4, maxLon: 3.6,
  );

  bool _isInIdf(double lat, double lon) =>
    lat >= _idfBounds.minLat && lat <= _idfBounds.maxLat &&
    lon >= _idfBounds.minLon && lon <= _idfBounds.maxLon;
}
```

**Key implementation details**:

1. **API selection**: `_chooseApi()` method returns `(baseUrl, headers, apiName)` tuple
2. **Shared response parsing**: `_parseJourneys()` works for both SNCF and PRIM
3. **Section formatting**: Maps `display_informations.physical_mode` to French labels
4. **Multiple journeys**: Return the best 3 options (Navitia returns several alternatives)
5. **Error handling**: Missing key → settings redirect, 429 → rate limit message, no routes → clear message

## Files to Modify

### 1. `lib/core/config/config_storage.dart`

Add two getter/setter pairs:

```dart
Future<String?> getSncfApiKey() => _storage.getSecure('sncf_api_key');
Future<void> setSncfApiKey(String apiKey) => _storage.setSecure('sncf_api_key', apiKey);

Future<String?> getPrimApiKey() => _storage.getSecure('prim_api_key');
Future<void> setPrimApiKey(String apiKey) => _storage.setSecure('prim_api_key', apiKey);
```

### 2. `lib/shared/constants.dart`

```dart
static const String cachedSncfApiKeyKey = 'cached_sncf_api_key';
static const String cachedPrimApiKeyKey = 'cached_prim_api_key';
```

### 3. `lib/providers/app_providers.dart`

```dart
import '../core/tools/transit_tool.dart';
// ...
final sncfApiKey = await configStorage.getSncfApiKey();
final primApiKey = await configStorage.getPrimApiKey();
// ...
if (!disabled.contains('get_transit')) {
  registry.register(TransitTool(sncfApiKey: sncfApiKey, primApiKey: primApiKey));
}
```

### 4. `lib/providers/background_service_provider.dart`

In `_cacheSecretsForService()`:

```dart
// Cache SNCF API key
final sncfKey = await configStorage.getSncfApiKey();
if (sncfKey != null && sncfKey.isNotEmpty) {
  await prefs.setString(AppConstants.cachedSncfApiKeyKey, sncfKey);
}

// Cache PRIM API key
final primKey = await configStorage.getPrimApiKey();
if (primKey != null && primKey.isNotEmpty) {
  await prefs.setString(AppConstants.cachedPrimApiKeyKey, primKey);
}
```

### 5. `lib/core/agent/service_agent_factory.dart`

Add `sncfApiKey` and `primApiKey` parameters:

```dart
static Future<AgentLoop> create({
  // ... existing params ...
  String? orsApiKey,
  String? sncfApiKey,
  String? primApiKey,
}) async {
  // ...
  if (!disabled.contains('get_transit')) {
    registry.register(TransitTool(sncfApiKey: sncfApiKey, primApiKey: primApiKey));
  }
}
```

### 6. `lib/core/services/background_task_handler.dart`

```dart
_agentLoop = await ServiceAgentFactory.create(
  // ... existing params ...
  orsApiKey: prefs.getString(AppConstants.cachedOrsApiKeyKey),
  sncfApiKey: prefs.getString(AppConstants.cachedSncfApiKeyKey),
  primApiKey: prefs.getString(AppConstants.cachedPrimApiKeyKey),
);
```

### 7. `lib/features/settings/routing_config_screen.dart`

Add two new sections below the existing ORS API key:

- **SNCF API key** field with test button (test: Paris → Lyon journey)
- **PRIM/IDFM API key** field with test button (test: Gare de Lyon → Châtelet journey)

Each section has its own TextEditingController, obscure toggle, and save action. Single "Save" button at top persists all three keys and calls `ref.invalidate(toolRegistryProvider)` once.

### 8. `lib/features/settings/tools_config_screen.dart`

```dart
_ToolInfo(
  name: 'get_transit',
  label: 'Public Transit',
  description: 'Metro, RER, bus, train routes (SNCF + IDFM)',
  icon: Icons.directions_transit_outlined,
),
```

### 9. `lib/features/settings/settings_screen.dart`

Update the Routing ListTile subtitle:

```dart
subtitle: const Text('Configure routing & transit APIs'),
```

### 10. `README.md`

- Tool count: 21 → 22
- Add `get_transit` to tools list, tools table, and availability table
- Add to mermaid diagram tools list
- Update Dart file count (70 → 71)

## Edge Cases

| Scenario | Behavior |
|---|---|
| Neither API key configured | `ToolResult.error('No transit API key configured. Set SNCF or PRIM key in Settings > Routing.')` |
| Only SNCF key, IDF trip | Use SNCF (covers IDF too, just less precise) |
| Only PRIM key, national trip | `ToolResult.error('SNCF API key needed for trips outside Île-de-France. Set it in Settings > Routing.')` |
| Only PRIM key, IDF trip | Use PRIM |
| Origin in IDF, dest outside | Use SNCF (cross-region trip) |
| Rate limit (429) | `ToolResult.error('Transit API rate limit reached. Try again later.')` |
| No routes found | `ToolResult.error('No transit routes found between these locations.')` |
| Coordinates outside France | API returns empty journeys → "No routes found" |
| API returns error JSON | Parse `error.message` field, return as `ToolResult.error()` |
| Wheelchair requested | Pass `wheelchair=true` parameter, API filters accessible routes |

## Service Isolate Compatibility

**Yes** — pure HTTP, no platform dependencies. Both SNCF and PRIM are GET requests with API key headers. Registered in `ServiceAgentFactory` alongside `DirectionsTool`.

Cron example: "Every weekday at 6:30 AM, check my commute from home to office and send a notification if there are delays or disruptions."

## Acceptance Criteria

- [x] `get_transit` tool created with auto-routing (PRIM for IDF, SNCF for national)
- [x] Two API keys: SNCF + PRIM, stored in FlutterSecureStorage
- [x] Both keys cached in SharedPreferences for service isolate
- [x] Shared Navitia response parsing for both APIs
- [x] ToolResult.dual() with French section descriptions (forUser) and full data (forLLM)
- [x] Returns top 3 journey options
- [x] Routing config screen expanded with SNCF + PRIM key inputs and test buttons
- [x] Tool toggle in Settings > Tools
- [x] Registered in both main isolate and service isolate
- [x] Graceful degradation: works with only one API key
- [x] Error handling: missing key, rate limit, no routes, API errors
- [x] `flutter analyze` passes
- [x] README updated (tool count, descriptions, availability table)

## LLM Chaining Examples

1. **"How to get to Gare du Nord?"**
   → `get_location` → `get_address` → `get_transit(origin=here, dest=Gare du Nord)`

2. **"Train to Lyon tomorrow at 8am?"**
   → `get_transit(origin=Paris, dest=Lyon, datetime=20260221T080000)`

3. **"Set alarm for my commute, I need to arrive at 9:00"**
   → `get_location` → `get_transit(dest=office, datetime_represents=arrival, datetime=09:00)` → check departure → `volume_control(get)` → `set_alarm(hour=X, minutes=Y)`

4. **Cron: "Morning commute check"**
   → `get_transit(origin=home, dest=office)` → compare with normal time → `notifications(schedule)` if delays

## File Summary

| # | File | Change |
|---|------|--------|
| 1 | `lib/core/tools/transit_tool.dart` | **NEW** — TransitTool with SNCF + PRIM auto-routing |
| 2 | `lib/core/config/config_storage.dart` | Add `getSncfApiKey/setSncfApiKey` + `getPrimApiKey/setPrimApiKey` |
| 3 | `lib/shared/constants.dart` | Add `cachedSncfApiKeyKey` + `cachedPrimApiKeyKey` |
| 4 | `lib/providers/app_providers.dart` | Import, fetch keys, register TransitTool |
| 5 | `lib/providers/background_service_provider.dart` | Cache both keys in `_cacheSecretsForService()` |
| 6 | `lib/core/agent/service_agent_factory.dart` | Add `sncfApiKey/primApiKey` params, register TransitTool |
| 7 | `lib/core/services/background_task_handler.dart` | Pass cached SNCF/PRIM keys to factory |
| 8 | `lib/features/settings/routing_config_screen.dart` | Add SNCF + PRIM key sections with test buttons |
| 9 | `lib/features/settings/tools_config_screen.dart` | Add toggle for `get_transit` |
| 10 | `lib/features/settings/settings_screen.dart` | Update Routing subtitle |
| 11 | `README.md` | Tool count 22, add descriptions, availability table row |

## References

### Internal
- `lib/core/tools/directions_tool.dart` — Closest tool pattern (ORS HTTP API)
- `lib/core/config/config_storage.dart:46` — API key getter/setter pattern
- `lib/providers/background_service_provider.dart:164` — Secret caching pattern
- `lib/features/settings/routing_config_screen.dart` — Config screen to extend
- `docs/plans/2026-02-17-feat-routing-directions-transit-plan.md` — Original Phase 2 plan

### External
- [Navitia.io Documentation](https://doc.navitia.io/) — Journey response format
- [SNCF Open Data](https://ressources.data.sncf.com/explore/dataset/api-sncf/) — SNCF API access
- [PRIM IDFM Calculator v2](https://prim.iledefrance-mobilites.fr/en/apis/idfm-navitia-general-v2) — PRIM/IDFM API
- [PRIM Documentation](https://prim.iledefrance-mobilites.fr/en/aide-et-contact/documentation/) — PRIM playground and guides
