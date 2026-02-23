---
title: "RangeError in InputBar.insertText() — stale TextEditingController selection after clear()"
date: "2026-02-23"
category: "runtime-errors"
component: "lib/features/chat/input_bar.dart"
tags: ["text-editing", "speech-to-text", "selection-bounds", "rangeError", "TextEditingController"]
severity: "high"
symptoms:
  - "RangeError (end): Invalid value: Not in inclusive range 0..N: M"
  - "Crash after sending a voice-dictated message"
root_cause: "insertText() used TextEditingController.selection offsets without bounds checking; after clear(), selection retains stale offsets exceeding the now-empty text length"
---

# RangeError in InputBar.insertText() — stale selection after clear()

## Problem

After sending a voice-dictated message, the app crashes with:

```
RangeError (end): Invalid value: Not in inclusive range 0..18: 100
```

The error occurs in `InputBar.insertText()` when `String.replaceRange()` receives out-of-bounds indices from a stale `TextEditingController.selection`.

## Trigger Scenario

1. User dictates text via STT (speech-to-text) — text appears in field (e.g. "arrête FIP", length ~10-100)
2. User taps send button
3. `_send()` calls `_controller.clear()` — text becomes "" (length 0)
4. STT fires one last partial result callback
5. `insertText()` reads `_controller.selection` — still at old offset (e.g. 100)
6. `replaceRange(100, 100, text)` on empty string → **RangeError**

## Root Cause

`TextEditingController.selection` is not automatically invalidated when text is cleared. After `_controller.clear()` sets `text = ""`, the selection object retains its previous offset values. The selection update is queued in Flutter's rendering pipeline and may not execute immediately. When an asynchronous callback (STT result) invokes `insertText()` before the selection naturally resets, the stale offset falls outside `[0, currentText.length]`.

## Fix

**Before (broken)** — `lib/features/chat/input_bar.dart`:

```dart
void insertText(String text) {
  final selection = _controller.selection;
  final newText = _controller.text.replaceRange(
    selection.start,
    selection.end,
    text,
  );
  _controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: selection.start + text.length,
    ),
  );
  setState(() {});
}
```

**After (fixed)**:

```dart
void insertText(String text) {
  final currentText = _controller.text;
  final selection = _controller.selection;
  // Clamp selection to valid range (can be stale after clear())
  final start = selection.start.clamp(0, currentText.length);
  final end = selection.end.clamp(0, currentText.length);
  final newText = currentText.replaceRange(start, end, text);
  _controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: start + text.length),
  );
  setState(() {});
}
```

## Why It Works

Clamping `selection.start` and `selection.end` to `[0, currentText.length]` defensively handles stale offsets. If text was cleared and selection still points to offset 100, `start.clamp(0, 0)` returns 0, making `replaceRange(0, 0, text)` a valid insert-at-beginning on an empty string. The fix is minimal, idempotent, and requires no changes to the STT handler or controller lifecycle.

## Prevention

- **Always clamp selection offsets** before using them in `replaceRange()`, `substring()`, or similar string operations on `TextEditingController`
- **Never assume `selection` is valid** after `clear()`, direct `text=` assignment, or any external text modification — the selection update may be deferred by Flutter's rendering pipeline
- **Use atomic `TextEditingValue` assignment** when both text and selection need to change together
- **High-risk scenarios**: speech-to-text partial results, autocomplete, undo/redo, copy-paste — any async callback that modifies text while UI thread may be processing a separate mutation

## Related Docs

- `docs/solutions/architecture/implement-i18n-with-dual-isolate-support.md` — also modifies `input_bar.dart`
