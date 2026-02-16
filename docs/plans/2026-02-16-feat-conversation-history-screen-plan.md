---
title: "feat: Add conversation history screen"
type: feat
date: 2026-02-16
---

# Add conversation history screen

## Overview

Add a screen to browse, switch between, and delete past conversations. The backend is fully ready (`SessionManager.getAllSessions()`, `ChatNotifier.loadSession()`), but **no UI exists** — old conversations are persisted in Hive but completely inaccessible to the user.

## Problem Statement / Motivation

- The "New session" button creates sessions, but there's no way to return to previous ones
- Conversations are saved in Hive but practically lost once the user creates a new session
- Users need to continue past conversations or reference old ones
- Telegram sessions (`telegram_<chatId>`) should be visible but clearly separated

## Proposed Solution

A simple `HistoryScreen` accessible from the ChatScreen AppBar, showing all sessions sorted by most recent, with tap-to-load and swipe-to-delete.

### 1. New `HistoryScreen`

A `ConsumerWidget` that reads all sessions from `SessionManager` and displays them as a list.

**UI structure:**
- AppBar: "Conversations"
- ListView of sessions, grouped:
  - **Chat sessions** (keys not starting with `telegram_`)
  - **Telegram sessions** (keys starting with `telegram_`) — shown in separate section if any exist
- Each tile shows:
  - **Title**: first user message (truncated to 60 chars), or "New conversation" if empty
  - **Subtitle**: relative date ("Today", "Yesterday", "Feb 14") + message count
  - **Trailing**: delete icon button
- Tap → `chatNotifier.loadSession(key)` + `Navigator.pop()`
- Current session highlighted with a different background
- Empty state if only one session exists

### 2. Add history button to ChatScreen

Replace the "New session" icon or add alongside it in the AppBar:

```dart
IconButton(
  icon: const Icon(Icons.history),
  tooltip: 'Conversations',
  onPressed: () => Navigator.pushNamed(context, '/history'),
),
```

### 3. Wire route in `app.dart`

```dart
'/history': (context) => const HistoryScreen(),
```

### 4. Add `loadSession` initialization

Currently `ChatNotifier` starts with an empty `ChatState` and never loads the default session. Add session loading in `build()` or on first access so the user sees their last conversation on app start.

## Files to modify

| File | Change |
|---|---|
| `lib/features/chat/history_screen.dart` | **New** — conversation history list screen |
| `lib/features/chat/chat_screen.dart` | Add history button to AppBar |
| `lib/app.dart` | Add `/history` route + import |
| `lib/providers/chat_provider.dart` | Ensure `loadSession` works correctly, add session delete support |

## Detailed changes

### `history_screen.dart` (new)

```dart
class HistoryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionManager = ref.watch(sessionManagerProvider);
    return sessionManager.when(
      data: (sm) {
        final sessions = sm.getAllSessions();
        final chatSessions = sessions.where((s) => !s.key.startsWith('telegram_')).toList();
        final telegramSessions = sessions.where((s) => s.key.startsWith('telegram_')).toList();
        // Build ListView with sections
      },
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

**Session preview extraction:**
```dart
String _sessionTitle(Session session) {
  final firstUserMsg = session.messages.where((m) => m.role == 'user').firstOrNull;
  if (firstUserMsg == null) return 'New conversation';
  final text = firstUserMsg.content.replaceAll('\n', ' ').trim();
  return text.length > 60 ? '${text.substring(0, 60)}...' : text;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sessionDay = DateTime(date.year, date.month, date.day);
  if (sessionDay == today) return 'Today';
  if (sessionDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}
```

### `chat_screen.dart`

Add history button in AppBar actions (before settings):

```dart
IconButton(
  icon: const Icon(Icons.history),
  tooltip: 'Conversations',
  onPressed: () => Navigator.pushNamed(context, '/history'),
),
```

### `chat_provider.dart`

Add delete support:

```dart
Future<void> deleteSession(String sessionKey) async {
  final sm = await ref.read(sessionManagerProvider.future);
  sm.deleteSession(sessionKey);
  // If deleting current session, switch to default
  if (state.sessionKey == sessionKey) {
    await loadSession(AppConstants.defaultSessionKey);
  }
}
```

### `app.dart`

```dart
'/history': (context) => const HistoryScreen(),
```

## Points to watch

1. **Session without messages**: `createNew()` creates empty sessions — the history list should skip sessions with 0 messages, or show them as "New conversation"
2. **Delete confirmation**: Show a dialog before deleting to prevent accidental loss
3. **Telegram sessions**: Display with a Telegram icon to distinguish from chat sessions
4. **Current session indicator**: Highlight the active session so the user knows which one they're in
5. **Message count**: `session.messages` includes tool/system messages — filter to user+assistant for the count shown to users

## Acceptance Criteria

- [ ] History screen accessible from ChatScreen AppBar (history icon)
- [ ] All past sessions listed, sorted by most recent
- [ ] Each session shows: first user message as title, date, message count
- [ ] Tap on a session loads it in the chat
- [ ] Delete button with confirmation dialog removes a session
- [ ] Telegram sessions shown separately with Telegram icon
- [ ] Current session visually highlighted
- [ ] Empty sessions (0 user messages) hidden or shown as "New conversation"
- [ ] `flutter analyze` passes without errors

## References

### Internal References
- Session model: `lib/core/session/session.dart`
- SessionManager (getAllSessions, deleteSession): `lib/core/session/session_manager.dart`
- ChatNotifier (loadSession, newSession): `lib/providers/chat_provider.dart`
- ChatScreen AppBar: `lib/features/chat/chat_screen.dart`
- App routes: `lib/app.dart`
- SessionManager provider: `lib/providers/app_providers.dart`
