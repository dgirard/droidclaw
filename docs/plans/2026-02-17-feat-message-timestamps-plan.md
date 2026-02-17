---
title: "feat: Display timestamps on chat messages"
type: feat
date: 2026-02-17
---

# Display Timestamps on Chat Messages

## Overview

Add date/time display on each message bubble in the chat conversation, following standard messaging app conventions (WhatsApp, Telegram, iMessage).

## Current State

- `ChatMessage` already has a `timestamp` field (`DateTime`, defaults to `DateTime.now()`)
- `MessageBubble` doesn't display it
- `loadSession()` recreates `ChatMessage` without preserving the original timestamp from the `Session`

## Implementation

### 1. Fix timestamp preservation on session load

**`lib/providers/chat_provider.dart`** — `loadSession()`:

Currently creates new `ChatMessage` without timestamp. The `Session.Message` doesn't store timestamps, but `Session.updated` and message order give approximate times. For now, loaded messages won't have precise timestamps (only new messages will).

No change needed — `ChatMessage` defaults to `DateTime.now()` which is acceptable for loaded sessions (they show "just now" which is fine since the history screen already shows the session date).

### 2. Display timestamp on message bubbles

**`lib/features/chat/message_bubble.dart`**:

Add a small timestamp below the message content, following chat app conventions:

- **Position**: bottom-right for user messages, bottom-left for assistant messages
- **Format**: `HH:mm` (e.g., `14:32`) — standard for same-day messages
- **Style**: small, muted text (`bodySmall` + reduced opacity)
- **No date**: since conversations are session-scoped, time-only is sufficient (like WhatsApp within the same day)

```dart
Text(
  DateFormat('HH:mm').format(message.timestamp),
  style: theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    fontSize: 11,
  ),
)
```

Place it at the bottom-right of the bubble content (inside the existing padding, after the message text), aligned right. This replaces the current `Stack` + `Positioned` copy button approach — move the copy button and timestamp together at the bottom.

### 3. Don't show timestamps on tool messages

Tool call/result messages are transient UI indicators — no timestamp needed.

## Acceptance Criteria

- [ ] User and assistant messages show `HH:mm` timestamp
- [ ] Timestamp is small and unobtrusive (muted color, 11px)
- [ ] Tool messages don't show timestamps
- [ ] `flutter analyze` passes
- [ ] APK builds and installs

## Files Changed

| File | Change |
|------|--------|
| `lib/features/chat/message_bubble.dart` | Add timestamp display below message content |

## References

- `lib/features/chat/message_bubble.dart` — current bubble widget
- `lib/providers/chat_provider.dart:8-23` — `ChatMessage` with existing `timestamp` field
