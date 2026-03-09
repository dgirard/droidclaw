---
title: "feat: Separate scheduled tasks into a tab in history screen"
type: feat
date: 2026-03-09
---

# feat: Separate scheduled tasks into a tab in history screen

## Overview

Convert the `HistoryScreen` from a single scrollable list with section headers into a two-tab layout:

- **Tab 1 — "Conversations"**: Chat sessions + Telegram sessions (with their existing section headers)
- **Tab 2 — "Scheduled Tasks"**: Cron session groups (with existing grouping/drill-in logic)

This gives scheduled task history its own dedicated space, reducing clutter in the conversation list.

## Acceptance Criteria

- [x] `HistoryScreen` uses a `TabBar` with 2 tabs
- [x] "Conversations" tab shows chat + telegram sessions, preserving "Chat" / "Telegram" section headers
- [x] "Scheduled Tasks" tab shows grouped cron sessions (same tile logic as today)
- [x] Per-tab empty states: chat bubble icon for Conversations, schedule icon for Scheduled Tasks
- [x] Default tab on open: "Conversations"
- [x] Tab selection survives rebuilds (cron completion refresh, session deletion)
- [x] `CronExecutionsScreen` navigation still works (`popCount: 2` — no nested Navigator)
- [x] New i18n ARB keys for tab labels in all 5 locales (EN/FR/ES/DE/IT)
- [x] `flutter analyze` passes with 0 issues

## Technical Approach

### Widget Structure

Wrap the existing `ConsumerWidget` body with `DefaultTabController` (length: 2). This avoids converting to `ConsumerStatefulWidget` while maintaining tab state across Riverpod-triggered rebuilds.

```
Scaffold
├── AppBar
│   └── bottom: TabBar(tabs: [Conversations, Scheduled Tasks])
└── TabBarView
    ├── Tab 0: ListView (chat + telegram sections, or empty state)
    └── Tab 1: ListView (cron groups, or empty state)
```

### Key File: `lib/features/chat/history_screen.dart`

1. Wrap `Scaffold` body in `DefaultTabController(length: 2)`
2. Add `TabBar` to `AppBar.bottom` with 2 tabs
3. Replace the single `ListView` with `TabBarView` containing 2 children
4. Move chat+telegram rendering to Tab 0, cron rendering to Tab 1
5. Add per-tab empty state widgets (different icon + text per tab)
6. Keep all existing helper methods (`_groupCronSessions`, `_loadSession`, `_confirmDelete`, etc.)

### i18n: 5 ARB files

Add 2 new keys + 2 empty-state keys:

| Key | EN | FR | ES | DE | IT |
|---|---|---|---|---|---|
| `historyTabConversations` | Conversations | Conversations | Conversaciones | Unterhaltungen | Conversazioni |
| `historyTabScheduled` | Scheduled Tasks | Tâches planifiées | Tareas programadas | Geplante Aufgaben | Attività pianificate |
| `historyEmptyScheduled` | No scheduled tasks yet | Aucune tâche planifiée | Sin tareas programadas | Keine geplanten Aufgaben | Nessuna attività pianificata |

The existing `historyEmpty` key serves as the Conversations empty state.

### What Does NOT Change

- `Session` model, `SessionManager`, session key prefix conventions
- `CronExecutionsScreen` and its `popCount` logic (no nested navigation added)
- `_SessionTile`, `_CronGroup`, `_SectionHeader` private widgets
- `chatProvider` deletion/load logic
- `cronCompletionCount` rebuild trigger
- `CronConfigScreen._viewExecutions()` path (independent of `HistoryScreen`)
- Named route `/history`

## Risk Analysis

| Risk | Severity | Mitigation |
|---|---|---|
| Tab resets to index 0 on rebuild | Medium | `DefaultTabController` preserves state in widget tree; verify with cron completion test |
| `popCount: 2` breaks with nested nav | High | Do NOT use nested `Navigator` — tabs stay in same `Scaffold` |
| Tab state lost on session deletion | Low | Riverpod rebuild preserves `DefaultTabController` state |

## References

- `lib/features/chat/history_screen.dart` — primary file to modify
- `lib/l10n/app_en.arb`, `app_fr.arb`, `app_es.arb`, `app_de.arb`, `app_it.arb` — new ARB keys
- `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md` — cross-isolate session refresh pattern
