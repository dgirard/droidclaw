---
title: "fix: ORS API error — invalid 'unknown' profile in get_directions"
type: fix
date: 2026-02-27
---

# fix: ORS API Error — Invalid 'unknown' Profile in get_directions

## Problem

Screenshot evidence at 18:06 shows the agent failing to compute walking directions:

1. User confirms "oui" (wants directions home)
2. Agent calls `get_location` → GPS: 48.881171, 2.266972
3. Agent calls `geocode` → "9, Rue Raimu, Montigny-le-Bretonneux..."
4. Agent calls `get_directions` → **ORS API error (400): Parameter 'profile' has incorrect value of 'unknown'.**
5. Agent retries `get_directions` → 29.1 km, 31 min (car) — success
6. Agent calls `get_directions` again → **same ORS API error (400)** — walking profile fails
7. Agent apologizes: "il y a un problème avec l'API qui ne me permet pas de calculer l'itinéraire à pied"

The LLM sends an invalid `mode` value to `get_directions`. The ORS API rejects the profile 'unknown' in the URL path (`/v2/directions/unknown`).

### Why It Happens

Two contributing factors:

**1. Weak mode description in tool schema**

The committed `mode` parameter description says only `'Transport mode (default: car)'` — no explicit list. The enum IS defined in the JSON schema, but the text description doesn't reinforce the valid values. Weaker models (Gemini Flash) sometimes ignore schema enums and invent values.

**2. No fallback for invalid modes**

The committed code returns a local error for invalid modes but relies on the LLM understanding the error and retrying. The LLM sometimes retries with a different invalid value or gives up:

```dart
// Committed code (OLD — does not protect against ORS 400):
final profile = _profiles[mode];
if (profile == null) {
  return ToolResult.error(
      'Unknown mode: $mode. Use: ${_profiles.keys.join(', ')}');
}
```

Note: The screenshot error message ("ORS API error (400)") differs from the committed code's local error ("Unknown mode: ..."). This indicates the deployed APK was built from an intermediate working directory state during the previous editing session, where the null check was temporarily removed but the fallback wasn't yet added.

## Fix Status: Uncommitted Changes Already Exist

The previous session created fixes across **19 files** that are currently **uncommitted** in the working directory on branch `fix/agent-language-and-tool-aggression`. These changes cover three issues at once:

### Change 1: Directions tool fallback + better description (`directions_tool.dart`)

```dart
// NEW — fallback to 'car' for any invalid mode:
final mode = (args['mode'] as String?) ?? 'car';
final profile = _profiles[mode] ?? _profiles['car']!;
```

Plus improved mode description: `'Transport mode: car (default), bike, walk, hike, wheelchair'`

And KB-aware tool description: `'Coordinates: geocode a known address (from knowledge context or user), or get_location for current position.'`

### Change 2: Language enforcement (`agent_loop.dart`, 5 ARB files, `context_builder.dart`)

- `_languageHint()` method + user message tagging in `agent_loop.dart`
- Bilingual `agentLanguageDirective` + `agentRespondInstructions` in all 5 ARB files
- `=== LANGUAGE REQUIREMENT ===` structured marker in `context_builder.dart`

### Change 3: KB-preference tool descriptions (6 tool files)

- `location_tool.dart` — "real-time GPS only, not for stored addresses"
- `reverse_geocode_tool.dart` — "only after get_location for current position"
- `geocode_tool.dart` — "pass addresses from knowledge context directly"
- `weather_tool.dart` — KB address → geocode first
- `transit_tool.dart` — KB address → geocode first
- `directions_tool.dart` — same pattern

## Acceptance Criteria

- [ ] All 19 uncommitted files committed to `fix/agent-language-and-tool-aggression`
- [ ] `flutter gen-l10n` succeeds
- [ ] `flutter analyze` — 0 issues
- [ ] Build release APK: `flutter build apk --release --split-per-abi`
- [ ] Deploy to device: `adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- [ ] Test: ask for directions with unspecified mode → no ORS error, defaults to car
- [ ] Test: ask "directions à pied" → walks mode works correctly
- [ ] Test: agent responds in French (language fix still works)
- [ ] Test: "où est-ce que j'habite?" → answers from KB, no GPS call

## Files Modified (19 total)

| File | Change |
|------|--------|
| `lib/core/agent/agent_loop.dart` | `_languageHint()` + message tagging |
| `lib/core/agent/context_builder.dart` | `=== LANGUAGE REQUIREMENT ===` marker |
| `lib/core/tools/directions_tool.dart` | Fallback mode + KB-aware description |
| `lib/core/tools/geocode_tool.dart` | KB-aware description |
| `lib/core/tools/location_tool.dart` | "real-time GPS only" description |
| `lib/core/tools/reverse_geocode_tool.dart` | "only after get_location" description |
| `lib/core/tools/transit_tool.dart` | KB-aware description |
| `lib/core/tools/weather_tool.dart` | KB-aware description |
| `lib/l10n/app_en.arb` | Bilingual directives + key behaviors |
| `lib/l10n/app_fr.arb` | Same |
| `lib/l10n/app_es.arb` | Same |
| `lib/l10n/app_de.arb` | Same |
| `lib/l10n/app_it.arb` | Same |
| `lib/l10n/generated/app_localizations.dart` | Regenerated |
| `lib/l10n/generated/app_localizations_en.dart` | Regenerated |
| `lib/l10n/generated/app_localizations_fr.dart` | Regenerated |
| `lib/l10n/generated/app_localizations_es.dart` | Regenerated |
| `lib/l10n/generated/app_localizations_de.dart` | Regenerated |
| `lib/l10n/generated/app_localizations_it.dart` | Regenerated |

## References

- Screenshot: `/tmp/screenshot_ors.png`
- Previous plan: `docs/plans/2026-02-27-fix-agent-language-and-tool-aggression-plan.md`
- Related plan: `docs/plans/2026-02-27-fix-agent-passivity-and-directions-mode-error-plan.md`
- Solution doc: `docs/solutions/runtime-errors/gemini-flash-ignores-system-prompt-language-instructions.md`
- ORS API docs: https://openrouteservice.org/dev/#/api-docs/v2/directions
