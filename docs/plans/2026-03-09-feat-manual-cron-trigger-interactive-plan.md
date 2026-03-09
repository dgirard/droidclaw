---
title: "feat: Manually trigger a cron in interactive chat mode"
type: feat
date: 2026-03-09
---

# feat: Manually trigger a cron in interactive chat mode

## Overview

Add a "Run Now" button on cron tiles that sends the cron's prompt as a regular chat message in a new session. The user sees the execution interactively (thinking, tool calls, response) in the chat UI instead of it running silently in the background.

## Problem Statement

Currently, cron prompts only execute automatically in the service isolate. To test or re-run a cron, you have to wait for the next scheduled trigger or manually copy-paste the prompt into chat. There's no way to trigger a cron on-demand and see the execution live.

## Proposed Solution

Add a play button to cron tiles in two places:
1. **CronConfigScreen** — next to each cron's enable/disable switch
2. **HistoryScreen scheduled tab** — on each cron group tile

On tap: create a new session, send the cron prompt as a user message, navigate to chat.

### Implementation

**Zero changes to AgentLoop or ChatNotifier needed.** The existing `newSession()` + `sendMessage()` flow handles everything:

```dart
// In CronConfigScreen or HistoryScreen:
void _runCronNow(BuildContext context, WidgetRef ref, CronDefinition cron) {
  final chatNotifier = ref.read(chatProvider.notifier);
  chatNotifier.newSession();
  chatNotifier.sendMessage(cron.prompt);
  Navigator.of(context).pushNamedAndRemoveUntil('/chat', (route) => false);
}
```

This works because:
- `sendMessage()` doesn't depend on `ChatScreen` being mounted — it updates Riverpod state and calls `AgentLoop.processMessage()`
- `ChatScreen` reads state reactively on build — it renders whatever events arrive
- The session is a regular chat session (no `cron_` prefix) — it appears in the Conversations tab, not Scheduled Tasks

### Files to Modify

| File | Change |
|---|---|
| `lib/features/settings/cron_config_screen.dart` | Add play button (`Icons.play_arrow`) to each cron tile's trailing Row |
| `lib/features/chat/history_screen.dart` | Add play button to cron group tiles in scheduled tab |
| `lib/l10n/app_*.arb` (5 files) | Add `cronRunNow` key ("Run now" / "Lancer maintenant" / etc.) |

### Files NOT Modified

- `chat_provider.dart` — `newSession()` + `sendMessage()` already exist
- `agent_loop.dart` — `processMessage()` is caller-agnostic
- `cron_config.dart` — `prompt` field already accessible
- `app.dart` — `/chat` route already exists

## Acceptance Criteria

- [x] Play button visible on each cron tile in CronConfigScreen
- [x] Play button visible on each cron group tile in HistoryScreen scheduled tab
- [x] Tapping play: creates new session, sends cron prompt, navigates to chat
- [x] User sees live execution (thinking, tool calls, response) in chat
- [x] Session appears in Conversations tab (not Scheduled Tasks)
- [x] i18n: `cronRunNow` key in all 5 locales
- [x] `flutter analyze` passes with 0 issues

## Technical Considerations

- **Session type**: Interactive runs create regular sessions (no `cron_` prefix), distinguishing them from automated executions. This is intentional — the user triggered it manually.
- **Concurrent execution**: If a cron is running in the service isolate AND the user triggers it manually, two separate sessions are created. No conflict — different session keys, different AgentLoop instances (service vs main isolate).
- **Navigation**: `pushNamedAndRemoveUntil('/chat', (route) => false)` clears the navigation stack, so the user lands on a clean chat screen. Back button goes to home, not back through settings.

## References

- `lib/providers/chat_provider.dart:112-201` — `sendMessage()` flow
- `lib/providers/chat_provider.dart:205-208` — `newSession()`
- `lib/features/settings/cron_config_screen.dart:109-157` — cron tile with trailing actions
- `lib/features/chat/history_screen.dart:125-183` — scheduled tab cron group tiles
- `lib/core/config/cron_config.dart:75` — `CronDefinition.prompt` field
