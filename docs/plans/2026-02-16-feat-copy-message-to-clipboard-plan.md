---
title: "feat: Add copy-to-clipboard on chat messages"
type: feat
date: 2026-02-16
---

# Copy Chat Messages to Clipboard

## Overview

Add the ability to copy any message in the chat view (user input, assistant responses, tool results) to the system clipboard via a long-press context menu or a copy icon button.

## Current State

- **User messages**: rendered as plain `Text` widget in a right-aligned bubble (`message_bubble.dart:45-51`)
- **Assistant messages**: rendered via `MarkdownBody(selectable: true)` in a left-aligned bubble (`message_bubble.dart:52-70`). Text is selectable but there's no one-tap copy action
- **Tool messages**: compact inline indicator with truncated text (`message_bubble.dart:75-110`)
- **No clipboard functionality** exists anywhere in the project — no import of `flutter/services.dart`

## Proposed Solution

Add a **copy icon button** on each message bubble (user, assistant, error). On tap, copy the full `message.content` to the clipboard and show a brief SnackBar confirmation.

### Design

- Small copy icon (`Icons.copy`, size 16-18) positioned at the top-right corner of each message bubble
- Semi-transparent until hovered/focused for a clean look
- Tool call/result messages: no copy button (content is too short/technical to be useful)
- SnackBar: "Copied to clipboard" shown for 1.5 seconds

## Acceptance Criteria

- [ ] User messages can be copied to clipboard via a copy icon button
- [ ] Assistant messages can be copied to clipboard via a copy icon button
- [ ] Error messages can be copied to clipboard via a copy icon button
- [ ] Tool call/result messages do NOT have a copy button (they're short inline indicators)
- [ ] A SnackBar "Copied to clipboard" confirms the action
- [ ] The copy button is subtle and doesn't clutter the UI
- [ ] `flutter analyze` passes with 0 issues
- [ ] APK builds and installs on device

## Implementation

### `lib/features/chat/message_bubble.dart`

1. Add `import 'package:flutter/services.dart';`
2. For user and assistant/error message bubbles, wrap the existing content in a `Stack` or add an `IconButton` row:
   - Add a small copy `IconButton` at the top-right of the bubble
   - On press: `Clipboard.setData(ClipboardData(text: message.content))`
   - Show SnackBar via `ScaffoldMessenger.of(context)`
3. Keep tool messages unchanged (no copy button)

### Files Changed

| File | Change |
|------|--------|
| `lib/features/chat/message_bubble.dart` | Add copy button to user/assistant/error bubbles |

### No New Files

This is a single-file change in the existing `MessageBubble` widget.

## References

- `lib/features/chat/message_bubble.dart` — message rendering widget
- `lib/providers/chat_provider.dart:8-57` — ChatMessage model with `content` field
- Flutter `Clipboard` API: `flutter/services.dart`
