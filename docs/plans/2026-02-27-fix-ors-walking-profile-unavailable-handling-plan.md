---
title: "fix: Handle ORS walking profile unavailability gracefully"
type: fix
date: 2026-02-27
---

# fix: Handle ORS Walking Profile Unavailability Gracefully

## Problem

Walking directions fail with `ORS API error (400): Parameter 'profile' has incorrect value of 'unknown'.` while car directions work perfectly.

## Root Cause: ORS Server-Side Maintenance (NOT a code bug)

The `foot-walking` profile is **temporarily down** on OpenRouteService servers due to [server maintenance on February 27, 2026](https://ask.openrouteservice.org/t/profile-foot-walking-down-was-server-maintenance-27-02-2026/7843).

Key facts:
- Maintenance started **February 27, 2026 at 09:00 CET**
- Graph rebuilding "can take a day or two" — expected back late Feb / early March 2026
- Only `foot-walking` is affected; other profiles (`driving-car`, `cycling-regular`, etc.) work
- When a profile is down, ORS returns `400: Parameter 'profile' has incorrect value of 'unknown'` — even though the profile name we send (`foot-walking`) is valid
- This [same error pattern was reported by others](https://ask.openrouteservice.org/t/parameter-profile-has-incorrect-value-of-unknown-when-set-profile-as-foot-hiking/7818) during previous maintenance events

**Our code is correct** — `_profiles['walk']` correctly maps to `'foot-walking'`, the URL is correct (`/v2/directions/foot-walking`). The ORS API simply rejects the request because the profile is not loaded on their servers.

Status page: https://status.openrouteservice.org/

## Why This Needs a Code Fix Anyway

Even though the root cause is server-side, our tool should handle this gracefully because:

1. **Confusing error message** — "Parameter 'profile' has incorrect value of 'unknown'" is meaningless to the user/LLM
2. **No fallback** — if walking fails, the agent should offer car as an alternative rather than just failing
3. **This will happen again** — ORS does regular maintenance, profiles go down periodically
4. **The `foot-hiking` profile may work** as an alternative when `foot-walking` is down (different graph)

## Proposed Solution

### Change 1: Add profile fallback with retry in `directions_tool.dart`

When a directions request returns 400, retry with a fallback profile and flag it to the LLM:

```dart
// In _directions():
final response = await http.post(...);

if (response.statusCode == 400 && mode != 'car') {
  // Profile might be down (ORS maintenance). Retry with car as fallback.
  final carProfile = _profiles['car']!;
  final retryResponse = await http.post(
    Uri.parse('$_baseUrl/directions/$carProfile'),
    headers: { ... },
    body: body,
  );
  if (retryResponse.statusCode == 200) {
    // Parse and return with a note about the fallback
    // forLLM: "NOTE: $mode directions unavailable (ORS maintenance). Showing car route instead. Route (car): ..."
    // forUser: "29.1 km, 31 min (car — mode $mode indisponible)"
  }
}
```

### Change 2: Improve error message for profile unavailability

When the ORS error contains "incorrect value of 'unknown'", translate it to a human-readable message:

```dart
// In _parseError():
if (message.contains("incorrect value of 'unknown'")) {
  return ToolResult.error(
    'The $mode routing profile is currently unavailable on OpenRouteService '
    '(server maintenance). Try "car" mode, or wait and retry later.');
}
```

### Change 3: Try `foot-hiking` as walking fallback

When `foot-walking` fails with 400, try `foot-hiking` before falling back to `car`:

```dart
static const _walkingFallbacks = ['foot-hiking', 'driving-car'];
```

## Files to Modify

1. `lib/core/tools/directions_tool.dart` — retry logic + error message improvement
2. `lib/core/tools/directions_tool.dart` — walking fallback chain (foot-walking → foot-hiking → car)

## Acceptance Criteria

- [x] When `foot-walking` is down, `get_directions` with mode `walk` retries with `foot-hiking`
- [x] If `foot-hiking` also fails, falls back to `car` with a clear note in the result
- [x] Error message for "incorrect value of 'unknown'" explains the profile is temporarily unavailable
- [x] `forLLM` result includes a NOTE about the fallback so the agent can inform the user
- [x] `forUser` result shows the actual mode used with a marker (e.g., "car — walk indisponible")
- [x] Car directions continue to work unchanged
- [x] `flutter analyze` — 0 issues
- [x] Same pattern applied in `_isochrones()` method

## References

- ORS maintenance announcement: https://ask.openrouteservice.org/t/profile-foot-walking-down-was-server-maintenance-27-02-2026/7843
- Similar error report (foot-hiking): https://ask.openrouteservice.org/t/parameter-profile-has-incorrect-value-of-unknown-when-set-profile-as-foot-hiking/7818
- ORS status page: https://status.openrouteservice.org/
- Previous fix plan: `docs/plans/2026-02-27-fix-ors-api-unknown-profile-error-plan.md`
- Code: `lib/core/tools/directions_tool.dart:111-203` (_directions method)
