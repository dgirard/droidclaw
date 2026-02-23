---
title: "feat: Native Android speech-to-text button"
type: feat
date: 2026-02-23
---

# feat: Native Android speech-to-text button

## Overview

Add a mic button to the chat input bar that uses Android's native `SpeechRecognizer` API (via the `speech_to_text` Flutter package) for real-time speech-to-text. Tap to start listening, tap again to stop. Partial results stream into the text field as the user speaks. The transcribed text lands in the input bar, ready to send (not auto-sent).

## Problem Statement / Motivation

DroidClaw is a personal AI assistant, and voice is the most natural way to issue quick commands on a phone ("mets France Inter", "quelle heure est-il ?", "cherche la météo à Paris"). Currently:

- The app has **dead voice code** (`VoiceService` + `VoiceInputButton` in `lib/features/voice/`) that uses Groq Whisper API — never wired into the app
- The `InputBar` already has an `onMicPressed` callback and `insertText()` method — never activated
- `RECORD_AUDIO` permission is already in the AndroidManifest
- The existing Groq approach requires: (1) a Groq API key, (2) recording to file, (3) uploading to server, (4) waiting for response — too slow for quick voice commands

The native Android `SpeechRecognizer` gives:
- **Zero latency** — partial results appear as the user speaks
- **No API key** — uses Google's on-device/cloud speech recognition
- **No file I/O** — streams audio directly to the recognizer
- **Locale-aware** — matches the app's current locale setting

## Proposed Solution

### Architecture: speech_to_text package + InputBar integration

```
ChatScreen
  └── InputBar
        ├── TextField (text input)
        └── Mic/Send button (RIGHT side)
              │
              ├── No text → Show mic icon → tap toggles STT
              └── Has text → Show send icon → tap sends
              │
              v
        SpeechToText (package)
              │
              ├── onResult(text, isFinal) → insertText() into TextField
              ├── onStatus(listening/notListening/done)
              └── onError(...)
              │
              v
        Android SpeechRecognizer (native)
              ├── On-device recognition (if available)
              └── Cloud fallback (Google)
```

### UX: WhatsApp-style toggle button

The current InputBar has: `[mic] [TextField] [send]`

New layout: `[TextField] [mic_or_send]`

- **No text in field + not listening** → green mic button (right side)
- **No text + listening** → red pulsing mic button (recording indicator)
- **Has text** → blue send button (existing behavior)
- Tap mic → start listening; tap again → stop listening
- Partial results stream into TextField in real-time
- When recognition completes, text stays in field for review/edit before sending
- User can also manually type over/edit the transcribed text

### Package: `speech_to_text`

- Wraps Android's native `SpeechRecognizer` API
- Supports partial results, locale selection, on-device recognition
- Well-maintained, 1600+ likes on pub.dev
- No additional Android permissions needed beyond `RECORD_AUDIO` (already present)

## Technical Approach

### Phase 1: Add dependency

#### 1a. pubspec.yaml

```yaml
speech_to_text: ^7.0.0
```

### Phase 2: Modify InputBar

#### 2a. InputBar — `lib/features/chat/input_bar.dart`

Major changes:
- Remove left-side mic button
- Add `isListening` state
- Replace right-side send button with a **dynamic button** that switches between mic and send:
  - `_hasText` → send icon (blue filled `IconButton`)
  - `!_hasText && !_isListening` → mic icon (green filled `IconButton`)
  - `!_hasText && _isListening` → mic icon (red pulsing, animated)
- New callbacks: `onMicStart`, `onMicStop` (or single `onMicToggle`)
- Receive partial results via new `listeningText` parameter or direct `insertText()` calls

The InputBar itself should remain **stateless regarding speech** — it exposes callbacks and receives state from the parent (ChatScreen). This keeps the speech logic in one place.

New parameters:
```dart
class InputBar extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback? onMicToggle;   // replaces onMicPressed
  final bool enabled;
  final bool isListening;            // NEW: controls mic button appearance
  // ...
}
```

#### 2b. Dynamic right button logic

```dart
Widget _buildActionButton() {
  if (_hasText) {
    // Send button (existing)
    return IconButton.filled(
      icon: const Icon(Icons.send),
      onPressed: widget.enabled ? _send : null,
    );
  }

  if (widget.onMicToggle == null) {
    // No mic support — show disabled send
    return IconButton.filled(
      icon: const Icon(Icons.send),
      onPressed: null,
    );
  }

  // Mic button
  return IconButton.filled(
    icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none),
    style: IconButton.styleFrom(
      backgroundColor: widget.isListening
          ? theme.colorScheme.error
          : Colors.green,
      foregroundColor: Colors.white,
    ),
    onPressed: widget.enabled ? widget.onMicToggle : null,
  );
}
```

### Phase 3: Speech logic in ChatScreen

#### 3a. ChatScreen — `lib/features/chat/chat_screen.dart`

Add speech-to-text logic:

```dart
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputBarKey = GlobalKey<InputBarState>();
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      final locale = ref.read(appConfigProvider).resolvedLocale;
      _speech.listen(
        onResult: _onSpeechResult,
        localeId: locale,  // match app locale
        listenMode: ListenMode.dictation,
        partialResults: true,
      );
      setState(() => _isListening = true);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    // Replace current text with recognized text
    _inputBarKey.currentState?.setText(result.recognizedWords);
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      setState(() => _isListening = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    setState(() => _isListening = false);
    if (error.errorMsg != 'error_speech_timeout') {
      // Show error snackbar (but not for normal timeout)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech error: ${error.errorMsg}')),
      );
    }
  }
  // ...

  // In build():
  InputBar(
    key: _inputBarKey,
    onSend: (text) => chatNotifier.sendMessage(text),
    onMicToggle: _speechAvailable ? _toggleListening : null,
    isListening: _isListening,
    enabled: !chatState.isProcessing,
  ),
}
```

#### 3b. InputBar needs `setText()` method

Add a public method to InputBar for replacing the text content (different from `insertText()` which inserts at cursor):

```dart
void setText(String text) {
  _controller.text = text;
  _controller.selection = TextSelection.collapsed(offset: text.length);
  setState(() {});
}
```

This is needed because partial results replace the previous partial result, rather than appending.

### Phase 4: Visual feedback

#### 4a. Listening indicator

When `_isListening` is true:
- Mic button turns **red** with a subtle pulse animation
- Optional: show a small "Listening..." text banner above the input bar (like the `AgentStatusIndicator`)

Keep it simple — the red mic button is sufficient visual feedback. No overlay, no bottom sheet.

### Phase 5: Cleanup dead code

#### 5a. Remove unused voice files

Delete the dead Groq-based voice code that was never wired in:
- `lib/features/voice/voice_service.dart`
- `lib/features/voice/voice_input.dart`

Also remove the `record` package from `pubspec.yaml` if no other code uses it.

### Phase 6: i18n

#### 6a. Add/update ARB keys

Keys needed (all 5 locale files):
- `chatListening` — "Listening..." (shown in status indicator, if used)
- `chatSpeechError` — "Speech recognition error"
- `chatSpeechUnavailable` — "Speech recognition unavailable"

The existing `chatVoiceInput` key is already present in all 5 locales.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Speech unavailable (no Google app) | `onMicToggle` is null → mic button not shown, only send |
| Permission denied | `initialize()` returns false → mic not shown |
| Network unavailable | Falls back to on-device recognition if available; otherwise error |
| User types while listening | Text from keyboard takes priority; stop listening |
| Agent processing (isProcessing=true) | Input bar disabled → mic button disabled |
| Silence timeout | SpeechRecognizer auto-stops after ~5s silence; status → "done" |
| Radio playing + STT | Both use different audio streams; STT uses VOICE_RECOGNITION, radio uses MEDIA |
| Quick tap (start/stop immediately) | Gracefully handles — speech.stop() is a no-op if not started |
| Locale mismatch | Maps app locale (en/fr/es/de/it) to speech locale ID |
| Long dictation | `ListenMode.dictation` allows continuous recognition until stopped |

## Files

### New files (0)

No new files needed — all changes are modifications to existing files.

### Modified files (5)

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `speech_to_text: ^7.0.0`, remove `record: ^6.2.0` |
| `lib/features/chat/input_bar.dart` | Remove left mic, add dynamic right button (mic/send), add `setText()`, new params |
| `lib/features/chat/chat_screen.dart` | Add SpeechToText init, toggle, result/status/error handlers, pass to InputBar |
| `lib/l10n/app_*.arb` (5 files) | Add `chatListening`, `chatSpeechError`, `chatSpeechUnavailable` keys |

### Deleted files (2)

| File | Reason |
|------|--------|
| `lib/features/voice/voice_service.dart` | Dead code — Groq Whisper STT, never wired |
| `lib/features/voice/voice_input.dart` | Dead code — hold-to-speak button, never wired |

### No change to

- `AndroidManifest.xml` — `RECORD_AUDIO` permission already present
- `app_config.dart` — no config needed (no API key)
- `service_agent_factory.dart` — STT is UI-only, not a tool
- `app_providers.dart` — STT is local to ChatScreen, not a Riverpod provider
- `tools_config_screen.dart` — not a tool, no toggle needed

## Acceptance Criteria

- [x] `flutter analyze` passes with 0 issues
- [x] Release APK builds and installs
- [ ] Mic button appears on right side when text field is empty
- [ ] Send button appears on right side when text field has text
- [ ] Tapping mic starts speech recognition, button turns red
- [ ] Partial results stream into text field as user speaks
- [ ] Tapping red mic stops recognition, text stays in field
- [ ] Silence timeout stops recognition gracefully
- [ ] Transcribed text can be edited before sending
- [ ] Tapping send after voice input sends the message normally
- [ ] Speech recognition uses app's current locale
- [ ] Error displayed if speech recognition fails (not for timeout)
- [ ] Mic button hidden if speech recognition unavailable
- [ ] Radio playback not affected by speech recognition
- [x] Dead voice code removed (`lib/features/voice/`)
- [x] `record` package removed from pubspec.yaml

## Dependencies

- **`speech_to_text: ^7.0.0`** — new Flutter dependency (wraps Android SpeechRecognizer)
- **Remove `record: ^6.2.0`** — no longer needed (was for dead Groq voice code)
- No API key needed
- No Gradle changes needed
- No new Android permissions needed

## References

- [speech_to_text package](https://pub.dev/packages/speech_to_text)
- [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer)
- Existing dead code: `lib/features/voice/voice_service.dart`, `lib/features/voice/voice_input.dart`
- Existing infrastructure: `InputBar.onMicPressed`, `InputBar.insertText()`
