---
title: Enable get_location and get_address in service isolate crons
date: 2026-02-17
category: architecture
tags: [service-isolate, location, geolocation, reverse-geocoding, cron, background-service, platform-channels, flutter-foreground-task]
component: ServiceAgentFactory
related_components: [LocationTool, ReverseGeocodeTool, BackgroundServiceNotifier, AndroidManifest]
severity: high
symptoms:
  - Crons requiring location data fail silently in the service isolate
  - LocationTool and ReverseGeocodeTool excluded from ServiceAgentFactory
  - ReverseGeocodeTool excluded despite being pure HTTP (no platform channel dependency)
root_cause: Service isolate runs on a separate FlutterEngine with GeneratedPluginRegistrant — platform channels ARE available. Tools were unnecessarily excluded based on the false assumption that it was a plain Dart isolate.
files_changed:
  - android/app/src/main/AndroidManifest.xml
  - lib/core/tools/location_tool.dart
  - lib/core/agent/service_agent_factory.dart
  - lib/providers/background_service_provider.dart
  - README.md
related_docs:
  - docs/solutions/architecture/decouple-cron-from-telegram-autonomous-service.md
  - docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md
  - docs/plans/2026-02-17-feat-autonomous-cron-service-isolate-plan.md
  - docs/plans/2026-02-16-feat-location-tool-plan.md
  - docs/plans/2026-02-16-feat-reverse-geocoding-tool-plan.md
---

# Enable get_location and get_address in service isolate crons

## Problem

**Symptoms:**
- Cron jobs (scheduled prompts) that required location data (`get_location`, `get_address`) failed when executed by the service isolate
- Both tools were completely unavailable in the autonomous cron execution context
- Users could not schedule prompts like "What is my current address?" or location-aware recurring tasks

## Root Cause

### The Wrong Assumption

The service isolate was incorrectly assumed to be a "plain Dart isolate" with no access to platform channels. This led to `LocationTool` and `ReverseGeocodeTool` being excluded from the service isolate's tool registry.

### The Discovery

`flutter_foreground_task` runs the service isolate on a **separate FlutterEngine** with `GeneratedPluginRegistrant.registerWith()` — platform channels ARE fully available.

**Proof**: `SharedPreferences` (itself a platform channel plugin) already worked perfectly in `BackgroundTaskHandler`, demonstrating that the isolate had full platform channel access all along.

### Why Each Exclusion Was Wrong

1. **LocationTool** — Uses `geolocator` (platform channels). The exclusion was justified only by the false "plain Dart isolate" assumption. The real constraint is narrower: can't show permission dialogs from background, but the plugin itself works fine.

2. **ReverseGeocodeTool** — Uses pure HTTP (`package:http` to Nominatim API). No platform channels at all. Excluded entirely by mistake.

## Solution

### 1. AndroidManifest.xml — Add Location Service Type

Added `FOREGROUND_SERVICE_LOCATION` permission and updated `foregroundServiceType` (required on Android 14+ / API 34):

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="remoteMessaging|location"
    android:exported="false" />
```

### 2. LocationTool — Conditional Permission Request

Added `canRequestPermission` constructor parameter (default `true`):
- `true` (main isolate): current behavior — shows permission dialog if needed
- `false` (service isolate): skip `requestPermission()`, return clear error if not pre-granted

```dart
class LocationTool extends Tool {
  final bool canRequestPermission;
  LocationTool({this.canRequestPermission = true});

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    // ...
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!canRequestPermission) {
        return ToolResult.error(
            'Location permission not granted. '
            'Please open the app and use get_location once to grant permission.');
      }
      permission = await Geolocator.requestPermission();
      // ...
    }
  }
}
```

### 3. ServiceAgentFactory — Register Both Tools

```dart
if (!disabled.contains('get_location')) {
  registry.register(LocationTool(canRequestPermission: false));
}
if (!disabled.contains('get_address')) {
  registry.register(ReverseGeocodeTool());
}
// Excluded from service isolate:
// - WebScrapeJsTool (WebView needs Activity)
// - SubagentTool (self-referential, complex lifecycle)
// - MessageTool (no UI in service isolate)
```

### 4. BackgroundServiceNotifier — Declare Location Service Type

```dart
final result = await FlutterForegroundTask.startService(
  serviceId: 256,
  serviceTypes: [
    ForegroundServiceTypes.remoteMessaging,
    ForegroundServiceTypes.location,
  ],
  // ...
);
```

## Edge Case: Permission Not Granted

If the user has never used `get_location` from the app (never granted permission), the cron gets:

> "Location permission not granted. Please open the app and use get_location once to grant permission."

This is correct and intentional — there's no way to show a permission dialog from a background service. The error is clear and actionable.

## Key Insight: Corrected Mental Model

Replace:
> "Service isolate is a plain Dart isolate without platform channels"

With:
> "Service isolate runs on a separate FlutterEngine with GeneratedPluginRegistrant. Tool exclusion should be based on: (1) Android background restrictions (can't show dialogs), (2) unavailability of Flutter UI context (no Activity for WebView), (3) self-referential complexity — NOT on isolate type or plugin availability."

### Updated Tool Availability

| Tool | Main Isolate | Service Isolate | Reason |
|------|:---:|:---:|--------|
| `web_search` | Yes | Yes | Pure HTTP |
| `web_scrape` | Yes | Yes | Pure HTTP |
| `web_scrape_js` | Yes | **No** | WebView needs Activity |
| `file` | Yes | Yes | Dart I/O |
| `get_location` | Yes | Yes | Platform channel works; permission must be pre-granted |
| `get_address` | Yes | Yes | Pure HTTP (Nominatim) |
| `subagent` | Yes | **No** | Self-referential lifecycle |
| `message` | Yes | **No** | No UI in service isolate |

## Prevention: Checklist for Adding Tools to Service Isolate

1. **Does the tool require UI?** (dialogs, permission requests) → Add a `canRequestPermission`-style flag
2. **Does the tool use platform channels?** → Check if the plugin is in pubspec.yaml (it will work)
3. **Is the tool pure HTTP/Dart?** → Safe for service isolate, register it
4. **Does the tool need a WebView or Activity?** → Exclude from service isolate
5. **Does it need Android permissions?** → Update AndroidManifest (permission + foregroundServiceType)
6. **Does it need `serviceTypes` in startService()?** → Update BackgroundServiceNotifier
