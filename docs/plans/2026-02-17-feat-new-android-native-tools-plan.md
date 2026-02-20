---
title: "feat: New Android-native tools for DroidClaw"
type: feat
date: 2026-02-17
tags: [tools, android, platform-apis, agent]
---

# New Android-Native Tools for DroidClaw

## Overview

All PicoClaw tools are already ported (except `exec`, `i2c`, `spi` — impossible on Android). DroidClaw even added 3 tools PicoClaw doesn't have (`get_location`, `get_address`, `web_scrape_js`).

This plan proposes **11 new tools** that exploit Android's unique platform capabilities — things a desktop/CLI agent can't do. Each tool follows the existing `Tool` base class contract, uses `ToolResult.dual()`, and integrates into the existing registration/toggle pattern.

## Context: What PicoClaw Had vs DroidClaw

| PicoClaw Tool | DroidClaw Status | Notes |
|---|---|---|
| `read_file`, `write_file`, `list_dir`, `edit_file`, `append_file` | Ported as `file` | Sandboxed to workspace |
| `exec` | **Not portable** | No shell on Android |
| `web_search` | Ported | Brave + DuckDuckGo fallback |
| `web_fetch` | Ported as `web_scrape` + `web_scrape_js` | HTTP + WebView |
| `message` | Ported | Chat UI + Telegram |
| `cron` | Ported | Background service + scheduled prompts |
| `subagent` | Ported | Fresh session delegation |
| `spawn` | Merged into `subagent` | Async not needed (Dart futures) |
| `i2c`, `spi` | **Not portable** | Linux hardware only |

**DroidClaw-only tools**: `get_location`, `get_address`, `web_scrape_js`

## Proposed New Tools

### Phase 1 — Quick Wins (no new permissions)

These tools require zero or minimal permissions, have mature packages, and provide immediate daily value.

---

#### 1. `clipboard` — Read/Write System Clipboard

**Package**: Built-in (`flutter/services.dart`) — no dependency needed.

**What it does**: Read or write text to the system clipboard. The agent can "read what I just copied" or "put this formatted text in my clipboard."

**Parameters**:
```json
{
  "operation": "read | write",
  "text": "(for write only)"
}
```

**Android constraints**:
- Android 10+: only foreground app can **read** clipboard. Write works from anywhere.
- Android 12+: toast notification shown when clipboard is read.

**Service isolate**: Write only. Read requires foreground (main isolate only).

**Permissions**: None.

**Value**: HIGH. Daily workflow tool — reformat copied text, extract data, prepare messages.

**Complexity**: Very low. ~50 lines.

---

#### 2. `device_info` — Battery, Connectivity, Device Model

**Packages**: `battery_plus`, `device_info_plus`, `connectivity_plus` (all from `plus_plugins` suite, very mature).

**What it does**: Returns battery level/state, connection type (WiFi/cellular/none), device model, Android version. One tool, three info sources.

**Parameters**:
```json
{
  "type": "object",
  "properties": {}
}
```
No parameters — returns all info at once.

**Service isolate**: YES — all three work from background.

**Permissions**: `ACCESS_NETWORK_STATE` (normal, auto-granted).

**Value**: MEDIUM-HIGH. Context-aware agent behavior ("battery is low, short answer"), conditional cron logic ("only if on WiFi").

**Complexity**: Very low. ~60 lines.

---

#### 3. `speak` — Text-to-Speech

**Package**: `flutter_tts` (very mature, uses Android built-in TTS engine).

**What it does**: Speaks text aloud. Completes the voice loop with existing STT (Groq Whisper).

**Parameters**:
```json
{
  "text": "string — text to speak",
  "language": "optional — e.g. fr-FR, en-US (default: device language)"
}
```

**Service isolate**: Works technically, but audio focus management may be needed. Recommend main isolate only initially.

**Permissions**: None. Needs `<queries>` entry for TTS intent in manifest.

**Value**: HIGH. Hands-free operation, voice conversation loop, accessibility.

**Complexity**: Low. ~70 lines.

---

#### 4. `open_app` — Launch Apps via Android Intents

**Packages**: `url_launcher` (already commonly used), `android_intent_plus`.

**What it does**: Opens other apps — Maps, Phone, Browser, Settings, Spotify, etc. Supports URL schemes (`tel:`, `mailto:`, `geo:`, `sms:`) and raw Android intents.

**Parameters**:
```json
{
  "action": "url | intent",
  "url": "(for url action) — e.g. tel:+33123456789, geo:48.8,2.3",
  "intent_action": "(for intent action) — e.g. android.settings.WIFI_SETTINGS",
  "extras": "(optional) — intent extras as key-value pairs"
}
```

**Android constraints**: Background activity launch restricted on Android 10+, but works from foreground service with `FLAG_ACTIVITY_NEW_TASK`.

**Service isolate**: Partial — intents work from service, but user experience may be jarring if unexpected.

**Permissions**: None. Needs `<queries>` declarations in manifest for target apps.

**Value**: HIGH. Bridges AI assistant to the full Android ecosystem. "Open Google Maps to X", "Call this number", "Open WiFi settings."

**Complexity**: Low-moderate. ~100 lines.

---

#### 5. `set_alarm` — Set Alarms and Timers via System Clock

**Package**: `android_intent_plus` (delegates to system Clock app).

**What it does**: Sets alarms or timers using Android's built-in Clock app. No custom alarm management needed — let the OS handle reliability.

**Parameters**:
```json
{
  "type": "alarm | timer",
  "hour": "(alarm) 0-23",
  "minutes": "(alarm) 0-59",
  "message": "optional label",
  "duration_seconds": "(timer) countdown in seconds"
}
```

**Service isolate**: YES — intent-based, works from background.

**Permissions**: None (delegates to Clock app).

**Value**: MEDIUM-HIGH. "Set an alarm for 7am", "Start a 5-minute timer." Core assistant functionality with zero implementation risk.

**Complexity**: Very low. ~60 lines.

---

### Phase 2 — Permission-Requiring but High Value

These tools need runtime permissions and careful privacy handling but provide core personal assistant functionality.

---

#### 6. `notifications` — Create Local Notifications and Reminders

**Package**: `flutter_local_notifications` (industry standard, v19.x).

**What it does**: Create instant or scheduled notifications. "Remind me at 3pm to call the dentist."

**Parameters**:
```json
{
  "operation": "show | schedule | cancel | list",
  "title": "notification title",
  "body": "notification body",
  "schedule_at": "(ISO 8601) for scheduled notifications",
  "id": "(for cancel) notification ID"
}
```

**Service isolate**: YES — notifications are background-native.

**Permissions**: `POST_NOTIFICATIONS` (Android 13+), `SCHEDULE_EXACT_ALARM` (Android 14+ for exact timing). Both already managed by the permission flow pattern.

**Value**: HIGH. Reminders are a core assistant capability. Different from crons — crons run the full agent loop, notifications are lightweight user-facing alerts.

**Complexity**: Moderate. Channel configuration, timezone handling, exact alarm permission flow.

---

#### 7. `contacts` — Read Device Contacts

**Package**: `flutter_contacts` (actively maintained, full CRUD).

**What it does**: Search and read contacts. "What's mom's phone number?", "Find John's email."

**Parameters**:
```json
{
  "operation": "search | get_all",
  "query": "(for search) name to search for",
  "limit": "max results (default 10)"
}
```

**Privacy handling**:
- **Read-only** — no WRITE_CONTACTS permission.
- Return minimal data in `forLLM` (name + phone + email only, no photos/addresses).
- Never log contact data.

**Service isolate**: YES — ContentProvider queries work from background.

**Permissions**: `READ_CONTACTS` (dangerous, runtime request).

**Value**: HIGH. Essential for "call [name]" workflows paired with `open_app`.

**Complexity**: Low. ~80 lines.

---

#### 8. `calendar` — Read/Write Calendar Events

**Package**: `device_calendar` or `device_calendar_plus`.

**What it does**: List calendars, read events, create events. "What's on my schedule today?", "Add a meeting tomorrow at 2pm."

**Parameters**:
```json
{
  "operation": "list_calendars | get_events | create_event",
  "calendar_id": "(for get_events/create) calendar to use",
  "start": "(ISO 8601) range start",
  "end": "(ISO 8601) range end",
  "title": "(create) event title",
  "description": "(create) event description",
  "location": "(create) event location"
}
```

**Service isolate**: YES — ContentProvider queries work from background. A cron that says "morning briefing with today's calendar" becomes possible.

**Permissions**: `READ_CALENDAR`, `WRITE_CALENDAR` (dangerous, runtime request).

**Value**: HIGH. Schedule awareness is core personal assistant territory.

**Complexity**: Moderate. Calendar APIs are complex (recurring events, timezones, attendees).

---

### Phase 3 — Media Processing

---

#### 9. `ocr` — Extract Text from Images (On-Device)

**Package**: `google_mlkit_text_recognition` (on-device ML, no API key, supports Latin/Chinese/Japanese/Korean/Devanagari).

**What it does**: Extract text from an image file in the workspace. "Read the text in this photo", "What does this receipt say?"

**Parameters**:
```json
{
  "image_path": "relative path to image in workspace"
}
```

**Service isolate**: YES for processing. Image must already be in workspace (saved by camera tool or file tool).

**Permissions**: None (beyond file access to workspace).

**Value**: MEDIUM-HIGH. Pairs with file tool and future camera tool.

**Complexity**: Moderate. Adds ~15MB to APK. CPU-intensive processing.

---

#### 10. `qr_generate` — Generate QR Codes

**Package**: `qr_flutter` (render QR code as image).

**What it does**: Generates a QR code image and saves it to workspace. "Create a QR code for this WiFi network", "Generate a QR for this URL."

**Parameters**:
```json
{
  "data": "string to encode in QR",
  "filename": "optional output filename (default: qr_code.png)"
}
```

**Service isolate**: YES — pure Dart image generation.

**Permissions**: None.

**Value**: MEDIUM. Useful for sharing URLs, WiFi configs, vCards.

**Complexity**: Low. ~60 lines.

---

#### 11. `pick_image` — Select Image from Gallery

**Package**: `image_picker` (official Flutter team).

**What it does**: Opens the system image picker to select a photo. Saves it to workspace for OCR or other processing.

**Parameters**:
```json
{
  "source": "gallery | camera"
}
```

**Service isolate**: NO — requires UI interaction (system picker dialog).

**Permissions**: `READ_MEDIA_IMAGES` (Android 13+) or `READ_EXTERNAL_STORAGE` (older). `CAMERA` if source is camera.

**Value**: MEDIUM. Feed images into OCR tool. "Take a photo of this document and read it."

**Complexity**: Low. ~60 lines. But requires UI integration for the picker callback.

---

## Tools NOT Recommended

| Tool | Reason |
|---|---|
| **SMS** (read/send) | Google Play rejects `READ_SMS`/`SEND_SMS` unless app is default SMS handler. Use `open_app` with `sms:` URI instead. |
| **Bluetooth** | Too niche for a general assistant. High complexity, poor value/effort ratio. |
| **NFC** | Foreground-only requirement + niche use case. |
| **Screenshot** | MediaProjection requires per-use consent dialog. Use manual screenshot + OCR instead. |
| **WiFi SSID** | Requires `ACCESS_FINE_LOCATION` just for SSID. Merge basic connectivity into `device_info`. |

## Service Isolate Compatibility

| Tool | Main Isolate | Service Isolate | Reason |
|---|:---:|:---:|---|
| `clipboard` | Yes | Write only | Android 10+ blocks background read |
| `device_info` | Yes | Yes | No restrictions |
| `speak` | Yes | Caution | Audio focus management needed |
| `open_app` | Yes | Partial | Intents work, but UX may be jarring |
| `set_alarm` | Yes | Yes | Intent-based |
| `notifications` | Yes | Yes | Background-native |
| `contacts` | Yes | Yes | ContentProvider access |
| `calendar` | Yes | Yes | ContentProvider access |
| `ocr` | Yes | Yes | On-device processing |
| `qr_generate` | Yes | Yes | Pure Dart |
| `pick_image` | Yes | No | Needs UI |

## Implementation Pattern (Same for All)

Each tool follows the existing pattern:

1. Create `lib/core/tools/my_tool.dart` extending `Tool`
2. Register in `lib/providers/app_providers.dart` → `toolRegistryProvider`
3. Add toggle in `lib/features/settings/tools_config_screen.dart`
4. If service-isolate compatible, register in `lib/core/agent/service_agent_factory.dart`
5. If needs Android permission, add to `AndroidManifest.xml`
6. If needs runtime permission, handle in `execute()` with `canRequestPermission` pattern
7. Update README tools table

## Acceptance Criteria

- [ ] Each tool compiles and passes `flutter analyze`
- [ ] Each tool uses `ToolResult.dual()` for LLM/user content separation
- [ ] Each tool has a settings toggle
- [ ] Service-isolate compatible tools work from crons
- [ ] Runtime permissions are requested gracefully with clear error messages
- [ ] README updated with new tool descriptions and availability table
- [ ] No new `flutter analyze` warnings

## Recommended Implementation Order

**Start with Phase 1** — these tools are quick wins that immediately make the assistant more capable without any permission complexity:

1. `clipboard` (built-in API, ~50 lines)
2. `device_info` (3 mature packages, ~60 lines)
3. `speak` (completes voice loop with existing STT)
4. `open_app` (bridges to Android ecosystem)
5. `set_alarm` (intent-based, zero risk)

**Then Phase 2** for the "real personal assistant" tools:

6. `notifications` (reminders)
7. `contacts` (people lookup)
8. `calendar` (schedule awareness)

**Phase 3** when media workflows are needed:

9. `ocr` (text from images)
10. `qr_generate` (QR code creation)
11. `pick_image` (image acquisition)

## References

- Tool base class: `lib/core/tools/tool.dart`
- Registration pattern: `lib/providers/app_providers.dart:76-114`
- Settings toggle: `lib/features/settings/tools_config_screen.dart`
- Service factory: `lib/core/agent/service_agent_factory.dart`
- Manifest: `android/app/src/main/AndroidManifest.xml`
- CLAUDE.md: Adding a New Tool section
- Solution doc: `docs/solutions/architecture/enable-location-tools-in-service-isolate.md` (service isolate checklist)
