---
title: "refactor: Full README review and refresh"
type: refactor
date: 2026-02-17
tags: [documentation, readme, accuracy]
---

# Full README Review and Refresh

## Overview

After Phase 1 (5 tools) and Phase 2 (3 tools) additions, plus earlier architecture changes (location in service isolate, decoupled cron/telegram), the README has accumulated small inaccuracies. This plan fixes all of them in one pass.

## Confirmed Inaccuracies

### 1. Dart file count is wrong (63 -> 59)

The README claims **63 Dart files** in two places:
- Line ~180: `**63 Dart files** in total.`
- Stats table: `| **Dart files** | 63 |`

**Actual count: 59** (verified by `find lib -name '*.dart' | wc -l`).

The discrepancy: when Phase 1 added 5 tool files (55 -> 60), the count was updated correctly. When Phase 2 added 3 tool files, it was bumped to 63 — but the original 60 was already overcounted (should have been 56 -> 59 after Phase 2).

**Fix**: Change both occurrences from `63` to `59`.

### 2. Service isolate exclusion comments incomplete

`lib/core/agent/service_agent_factory.dart` has exclusion comments for 7 tools but 10 are actually excluded. The 3 Phase 2 tools (`notifications`, `contacts`, `calendar`) are not registered but have no exclusion comment.

**Fix**: Add comments for the 3 missing tools:
```dart
// - NotificationsTool (initialization requires Activity context)
// - ContactsTool (ContentProvider unreliable from background)
// - CalendarTool (ContentProvider unreliable from background)
```

### 3. Foreground service description incomplete

The "Foreground Service" section (line ~225) only mentions `remoteMessaging`:
> `remoteMessaging` has **no time limit** — designed for messaging apps

The service now also uses `location` type (since the location-in-service-isolate change). The manifest already has `remoteMessaging|location` and the `startService()` call uses both types.

**Fix**: Update the sentence to mention both types:
> `remoteMessaging|location` — `remoteMessaging` for messaging (no time limit), `location` for GPS access from background

### 4. APK size likely outdated

The Stats table says `20.8 MB`. After adding 4 new dependencies (flutter_local_notifications, timezone, flutter_contacts, device_calendar_plus), the APK is likely larger.

**Fix**: Rebuild APK and update the size. If not building now, mark as "~21 MB" or remove the exact number.

## Items Already Correct (No Changes Needed)

- Tool count: 16
- Tool names in all lists (What Was Kept, mermaid diagram, tool table, availability table)
- Default disabled tools (6): speak, open_app, set_alarm, notifications, contacts, calendar
- Tool availability table (main vs service isolate)
- Architecture diagrams
- Provider cascade description
- Summarization parameters
- Riverpod 3.x patterns
- Dual-isolate architecture

## Files to Change

| File | Change |
|------|--------|
| `README.md` | Fix Dart file count (2 places), update foreground service description |
| `lib/core/agent/service_agent_factory.dart` | Add 3 missing exclusion comments |

## Acceptance Criteria

- [ ] Dart file count says 59 in both places in README
- [ ] Service agent factory has complete exclusion comments for all 10 excluded tools
- [ ] Foreground service section mentions both `remoteMessaging` and `location` types
- [ ] `flutter analyze` passes with 0 issues
