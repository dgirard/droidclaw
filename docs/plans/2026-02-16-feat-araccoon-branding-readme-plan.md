---
title: "feat: ARaccoon branding — launcher name + README mascot section"
type: feat
date: 2026-02-16
---

# ARaccoon branding — launcher name + README mascot section

## Overview

The project's internal name remains "DroidClaw" (code, packages, classes), but the application is **pronounced "ARaccoon"** and adopts the raccoon as its mascot. Two concrete changes:

1. **Android launcher**: the displayed name changes from "droidclaw" to "ARaccoon"
2. **README**: add a section explaining the ARaccoon branding (why a raccoon, the link with tool calling, the visual design concept)

## Problem Statement / Motivation

- The name "DroidClaw" in the launcher is technical and forgettable
- "ARaccoon" (A Raccoon) is the public/brand name — it's what the user sees when searching for the app in their app drawer
- The raccoon mascot gives a strong identity and coherent storytelling (claws = tool calling, nocturnal = privacy, resourcefulness = AI agent)
- The README doesn't mention the visual identity at all — a dedicated section is needed

## Proposed Solution

### 1. Rename the Android launcher

Only one file to modify: `AndroidManifest.xml` line 9.

```xml
<!-- Before -->
android:label="droidclaw"

<!-- After -->
android:label="ARaccoon"
```

That's it. The `applicationId`, namespace, Dart classes, internal constants — everything remains "DroidClaw" / "com.droidclaw.app". Only the **name displayed in the Android launcher** changes.

### 2. Add the branding section to the README

Add a "Why ARaccoon?" section after the introduction, before "Origin". Content:

- **The name**: DroidClaw is pronounced "ARaccoon" — The Raccoon
- **Why a raccoon**:
  - **Dexterous claws** = iterative tool calling (manipulating, opening, rummaging)
  - **Intelligence and resourcefulness** = AI agent that finds solutions
  - **Nocturnal and discreet** = privacy, on-device, no central server
- **Visual design concept**: techwear/cyberpunk raccoon with tactical vest, HUD visor, claws on holographic screen

### 3. Update Gemini provider in the README

The README mentions "OpenRouter, OpenAI, Groq" but not Gemini which was added. Fix in passing.

## Files to modify

| File | Change |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | `android:label="droidclaw"` -> `android:label="ARaccoon"` |
| `README.md` | Add "Why ARaccoon?" section + mention Gemini in providers |

## What does NOT change

- `pubspec.yaml` (name: droidclaw)
- `lib/shared/constants.dart` (appName: 'DroidClaw')
- `lib/app.dart` (class DroidClawApp, title: 'DroidClaw')
- `android/app/build.gradle.kts` (namespace, applicationId)
- Kotlin package (`com.droidclaw.app`)
- All internal UI text (AppBar, chat placeholder, notifications)

The internal name remains DroidClaw everywhere. Only the launcher and README change.

## Acceptance Criteria

- [x] The Android launcher displays "ARaccoon" as the app name
- [x] The README contains a "Why ARaccoon?" section with the mascot explanation
- [x] The README mentions Gemini in the providers list
- [x] `flutter analyze` passes without errors
- [x] The app builds and installs correctly

## References

### Internal References
- AndroidManifest: `android/app/src/main/AndroidManifest.xml:9`
- README: `README.md:1-30`
- Constants (unchanged): `lib/shared/constants.dart:6`
