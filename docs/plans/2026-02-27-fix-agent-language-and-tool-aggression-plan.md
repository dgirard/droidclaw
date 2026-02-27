---
title: "fix: Agent responds in English and calls GPS unnecessarily"
type: fix
date: 2026-02-27
---

# fix: Agent responds in English and calls GPS unnecessarily

## Overview

Two bugs observed when user says "j'habite 9 rue Raimu a Montigny-le-Bretonneux" with French locale configured:

1. Agent responds in English instead of French
2. Agent asks for GPS location instead of simply acknowledging the user's address statement

## Bug 1: Agent responds in English

### Root Cause

The system prompt is ~95% English. The single French instruction at the end (`IMPORTANT: Reponds toujours en francais...`) is overwhelmed by:
- English identity section (~500 chars) — `context_builder.dart:91-105`
- English "Key behaviors" instructions — `context_builder.dart:98-104`
- English tool descriptions for 20+ tools (~1500+ chars) — `context_builder.dart:126-136`
- English memory/skills/bootstrap context (variable)

The previous fix (reposition to end + strengthen text — `docs/solutions/logic-errors/llm-agent-locale-prompt-engineering.md`) was necessary but insufficient.

### Fix

"Sandwich" approach — add language directive at BOTH start and end of system prompt:

- [x] Add a brief language directive in `_buildIdentity()` right after the identity line:
  ```
  "You MUST respond in {languageName} at all times."
  ```
  This sets the language expectation early, before the English tools/behaviors overwhelm.
- [x] Keep the existing strong `IMPORTANT:` instruction at the end (line 86)
- [x] Localize the "Key behaviors" bullet points via new ARB keys so they match the user's language

**Files:**
- `lib/core/agent/context_builder.dart` — `_buildIdentity()` method (line 91)
- `lib/l10n/app_en.arb`, `app_fr.arb`, `app_es.arb`, `app_de.arb`, `app_it.arb` — new ARB keys for localized key behaviors

## Bug 2: Agent calls GPS/geocode tools unnecessarily

### Root Cause (3 compounding factors)

**A. Over-aggressive tool instructions** (`context_builder.dart:98-104`):
```
Use them proactively to answer the user's request — do NOT ask for permission.
- When the user asks a question that requires information, call the appropriate tool(s) immediately.
- Chain tools when needed: call geocode first to get coordinates, then pass them to the next tool.
```
There is ZERO negative guidance about when NOT to call tools. The chaining example specifically mentions geocode + address.

**B. Ambiguous tool descriptions:**
- `get_location`: "Use when the user asks about their location" — matches "j'habite..." (I live at...)
- `geocode`: "when the user provides an address" — directly matches the input

**C. `knowledge_store` disabled by default** (`app_config.dart:197-202`):
The LLM has no tool to store personal facts, so when the user shares their address, the only relevant tools are GPS/geocode ones.

### Fix

- [x] Add negative guidance to "Key behaviors" in `_buildIdentity()`:
  ```
  - When the user shares personal information (address, preferences, etc.), acknowledge and remember it. Do NOT call location or geocoding tools for information the user is giving you.
  - Only call tools when the user asks a question or makes a request that requires external information.
  ```
- [x] Refine `get_location` description in `location_tool.dart`:
  ```
  Use ONLY when you need the device's real-time GPS coordinates (e.g., nearby places, weather, directions from current position). Do NOT use when the user tells you their address — they already know where they live.
  ```
- [x] Refine `geocode` description in `geocode_tool.dart`:
  ```
  Use ONLY before get_directions or get_transit when you need coordinates for routing. Do NOT use when the user is simply sharing their address.
  ```

**Files:**
- `lib/core/agent/context_builder.dart` — `_buildIdentity()` key behaviors
- `lib/core/tools/location_tool.dart` — tool description
- `lib/core/tools/geocode_tool.dart` — tool description

## Acceptance Criteria

- [x] Agent responds in French when French locale is configured
- [x] Agent acknowledges "j'habite [address]" without calling GPS/geocode tools
- [x] `flutter analyze` passes, APK builds
- [x] Language sandwich works for all 5 locales (EN/FR/ES/DE/IT)

## References

- `docs/solutions/logic-errors/llm-agent-locale-prompt-engineering.md` — previous fix (necessary but insufficient)
- `docs/solutions/architecture/implement-i18n-with-dual-isolate-support.md` — i18n architecture
- Screenshot: `/tmp/droidclaw_screenshot.png`
