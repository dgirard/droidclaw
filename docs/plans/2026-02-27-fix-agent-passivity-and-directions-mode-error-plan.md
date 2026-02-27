---
title: "fix: Agent too passive after acknowledge rule + get_directions mode error"
type: fix
date: 2026-02-27
---

# fix: Agent Too Passive After Acknowledge Rule + get_directions Mode Error

## Problem

Screenshot evidence from post-deploy test:

### Bug 1: Agent asks permission instead of acting

User asks about travel time. Agent responds:
> "Pour vous donner une estimation du temps nécessaire, j'ai besoin de savoir où vous vous trouvez actuellement..."

Instead of directly calling `get_location` + KB lookup + `get_directions`.

**Root cause**: The `agentKeyBehaviors` bullet "When the user shares new personal information, ONLY acknowledge and store it. Do NOT suggest, offer, or perform any further action — wait for the user to ask." is being interpreted too broadly. The model now treats ANY situation as "don't be proactive", even when the user explicitly asks a question requiring tools.

**The conflict**: Two bullets contradict each other:
- "call the appropriate tool(s) immediately without asking permission" (act!)
- "Do NOT suggest, offer, or perform any further action — wait for the user to ask" (don't act!)

The model resolves the ambiguity by choosing the safer path: ask.

### Bug 2: get_directions first call fails with 'unknown' profile

Error: `ORS API error (400): Parameter 'profile' has incorrect value of 'unknown'.`

The LLM passed an invalid transport mode to `get_directions`. The tool has a `_profiles` map (car, bike, walk, hike, etc.) and a null check, but somehow 'unknown' reached the ORS API URL.

The retry succeeded with mode 'hike' (26.9 km, 5h23).

## Fix

### Fix 1: Narrow the "acknowledge only" rule (5 ARB files)

Replace the overly broad bullet with a narrow, unambiguous one. The key change: specify it only applies when the user is TELLING you something to remember, not when they're asking a question.

**Current** (all 5 ARBs, same English text):
```
- When the user shares new personal information, ONLY acknowledge and store it. Do NOT suggest, offer, or perform any further action — wait for the user to ask.
```

**New** (all 5 ARBs):
```
- When the user tells you personal information to remember (e.g. "I live at...", "my dentist is..."), just acknowledge and store it via knowledge_store. Do NOT call other tools or suggest actions in response.
```

This is narrower: it only triggers for "telling info to remember", not for questions or requests.

### Fix 2: Add default mode fallback in directions_tool.dart

Add a defensive fallback so invalid modes default to 'car' instead of reaching ORS:

**File**: `lib/core/tools/directions_tool.dart`

In `_directions()` (line ~125) and `_isochrones()` (line ~218), after the profile lookup:

```dart
final mode = (args['mode'] as String?) ?? 'car';
final profile = _profiles[mode] ?? _profiles['car']!;
// Remove the null check + error return — just use fallback
```

This ensures any invalid mode silently defaults to 'car' instead of crashing or reaching ORS with garbage.

Also improve the tool description to make the enum clearer to the LLM:

```
'description': 'Transport mode: car (default), bike, walk, hike, wheelchair'
```

## Files to Modify

1. `lib/l10n/app_en.arb` — narrow the acknowledge bullet
2. `lib/l10n/app_fr.arb` — same
3. `lib/l10n/app_es.arb` — same
4. `lib/l10n/app_de.arb` — same
5. `lib/l10n/app_it.arb` — same
6. `lib/core/tools/directions_tool.dart` — fallback mode + clearer description

Then: `flutter gen-l10n && flutter analyze`

## Acceptance Criteria

- [ ] "j'habite 9 rue Raimu" → agent acknowledges, no extra actions
- [ ] "combien de temps pour rentrer chez moi à pied" → agent calls get_location + geocode + get_directions directly, no permission asked
- [ ] get_directions with invalid mode defaults to 'car' instead of ORS error
- [ ] `flutter analyze` — 0 issues
