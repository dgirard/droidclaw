import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../core/config/log_entry.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/voice_narrator.dart';
import '../../l10n/l10n.dart';
import '../../shared/constants.dart';

/// Seam over the platform speech recognizer so
/// [VoiceConversationController] is unit-testable (mirrors the [TtsEngine]
/// seam of U1 — speech_to_text exposes no interface either).
///
/// Results are delivered per listen session through [SttListenResult]
/// callbacks; the global status/error callbacks of speech_to_text stay owned
/// by the chat screen, which forwards them to the controller hooks
/// ([VoiceConversationController.onSttStatus] / `onSttError`).
abstract class SttEngine {
  /// Starts one listen session. [onResult] receives partial and final
  /// results for THIS session only.
  Future<void> listen({
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
    required void Function(String recognizedWords, bool finalResult) onResult,
  });

  /// Shortens/extends the no-speech endpointing of the active session
  /// (used to collapse the 7 s follow-up window to normal endpointing once
  /// the user starts speaking).
  void changePauseFor(Duration pauseFor);

  /// Ends the active session, delivering a final result if speech was seen.
  Future<void> stop();

  /// Aborts the active session without delivering a final result.
  Future<void> cancel();
}

/// Production [SttEngine] backed by speech_to_text. The wrapped
/// [SpeechToText] is the package singleton — the same instance the chat
/// screen uses for single-shot dictation (only one session runs at a time;
/// conversation mode and single-shot are mutually exclusive in the UI).
class SpeechToTextSttEngine implements SttEngine {
  final SpeechToText _speech;

  SpeechToTextSttEngine(this._speech);

  @override
  Future<void> listen({
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
    required void Function(String recognizedWords, bool finalResult) onResult,
  }) {
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      localeId: localeId,
      pauseFor: pauseFor,
      listenFor: listenFor,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  @override
  void changePauseFor(Duration pauseFor) => _speech.changePauseFor(pauseFor);

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

/// Phase of the voice conversation state machine (plan HTD diagram).
enum VoiceConversationPhase {
  /// Not in conversation mode.
  idle,

  /// Mic open, waiting for the user to speak (initial or follow-up window).
  listening,

  /// A voice turn was sent; the agent is working. Mic closed.
  processing,

  /// The narrator is reading the answer aloud. Mic closed (half-duplex).
  speaking,
}

/// Why the conversation mode last returned to [VoiceConversationPhase.idle].
enum VoiceCloseReason {
  none,

  /// Explicit exit: chip tap, mic tap, typing, screen dispose.
  userExit,

  /// The user said an exit phrase ("merci", "stop", ...).
  exitPhrase,

  /// Silence in the 7 s follow-up window — silent close, no reprompt.
  silence,

  /// Two unusable STT sessions in a row — visual fallback (snackbar).
  notUnderstood,
}

/// Observable controller state for the chat UI.
class VoiceConversationState {
  final VoiceConversationPhase phase;
  final VoiceCloseReason closeReason;

  const VoiceConversationState({
    this.phase = VoiceConversationPhase.idle,
    this.closeReason = VoiceCloseReason.none,
  });

  bool get isActive => phase != VoiceConversationPhase.idle;
}

/// Hands-free multi-turn voice conversation (U5): speak → hear the spoken
/// answer → speak again, exit by phrase or silence.
///
/// State machine: Idle → Listening → Processing → Speaking → Listening
/// (7 s follow-up window) → ... → Idle. speech_to_text has no continuous
/// dictation, so every turn is its own listen session (listen → done →
/// re-listen).
///
/// Invariants:
/// - **Half-duplex (KTD)**: a listen session only ever starts when
///   `narrator.state.isSpeaking == false` AND the machine is entering
///   Listening — the mic is structurally never open during narration.
/// - **Generation token** (learning: inputbar-rangeerror — the re-listen
///   loop multiplies late callbacks): every listen session captures a token;
///   results, statuses and errors that belong to a cancelled/older session
///   are dropped without any state mutation.
/// - Exit phrases ([AppConstants.voiceExitPhrases]) are checked on every
///   final result BEFORE sending.
/// - Silence in the follow-up window closes the conversation silently (no
///   audible reprompt). An unusable initial result gets max ONE spoken
///   clarification, then the mode exits with a visual fallback.
class VoiceConversationController {
  final SttEngine _stt;
  final VoiceNarrator _narrator;
  final String Function() _resolveLocale;
  final void Function(String text) _onSendVoiceMessage;

  VoiceConversationController({
    required SttEngine stt,
    required VoiceNarrator narrator,
    required String Function() resolveLocale,
    required void Function(String text) onSendVoiceMessage,
  })  : _stt = stt,
        _narrator = narrator,
        _resolveLocale = resolveLocale,
        _onSendVoiceMessage = onSendVoiceMessage {
    _narratorSub = _narrator.states.listen(_onNarratorState);
  }

  final _stateController = StreamController<VoiceConversationState>.broadcast();
  VoiceConversationState _state = const VoiceConversationState();
  StreamSubscription<VoiceNarratorState>? _narratorSub;

  /// Incremented for every new listen session and on every exit — anything
  /// captured under an older value is stale and must be ignored.
  int _generation = 0;

  /// Consecutive unusable STT sessions (empty final / recognizer error).
  int _strikes = 0;

  /// Whether the active listen session is the post-answer follow-up window
  /// (silence there closes silently instead of counting a strike).
  bool _followUpListen = false;

  /// Whether a non-empty partial was seen in the active session (used to
  /// collapse the follow-up window to normal endpointing once).
  bool _sawSpeech = false;

  VoiceConversationState get state => _state;

  /// State changes for the UI (mode chip, snackbar on [VoiceCloseReason]).
  Stream<VoiceConversationState> get states => _stateController.stream;

  /// Enters conversation mode and opens the first listen session.
  Future<void> enterConversationMode() async {
    if (_state.isActive) return;
    _strikes = 0;
    await _narrator.stop();
    AppLogger.instance
        .info(LogSource.app, '[VoiceConversation] entering conversation mode');
    await _startListen(followUp: false);
  }

  /// Leaves conversation mode: cancels any listen session, stops narration,
  /// invalidates all in-flight callbacks. Safe to call when already idle.
  Future<void> exitConversationMode({
    VoiceCloseReason reason = VoiceCloseReason.userExit,
  }) async {
    if (!_state.isActive) return;
    _generation++; // Invalidate every in-flight STT callback.
    _setPhase(VoiceConversationPhase.idle, reason);
    AppLogger.instance.info(
        LogSource.app, '[VoiceConversation] exited (${reason.name})');
    try {
      await _stt.cancel();
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, '[VoiceConversation] stt cancel failed: $e');
    }
    await _narrator.stop();
  }

  /// Hook for the chat layer: the in-flight turn finished (agent produced
  /// its response or an error). Once narration drains, the follow-up listen
  /// window opens. No-op outside conversation mode.
  void onTurnFinished() {
    if (_state.phase != VoiceConversationPhase.processing &&
        _state.phase != VoiceConversationPhase.speaking) {
      return;
    }
    unawaited(_reListenAfterTurn());
  }

  /// Hook for the chat screen's global speech_to_text status callback.
  /// `doneNoResult` means the session ended without ANY final result (plain
  /// `done` always follows a final result and is ignored here). Only acted
  /// on while Listening — a late recognizer `done` during Processing never
  /// opens a second session.
  void onSttStatus(String status) {
    if (_state.phase != VoiceConversationPhase.listening) return;
    if (status == 'doneNoResult') _onUnusableSession(_generation);
  }

  /// Hook for the chat screen's global speech_to_text error callback
  /// (error_speech_timeout, error_no_match, ...). Only acted on while
  /// Listening; equivalent to an empty session.
  void onSttError(String errorMsg) {
    if (_state.phase != VoiceConversationPhase.listening) return;
    AppLogger.instance
        .info(LogSource.app, '[VoiceConversation] stt error: $errorMsg');
    _onUnusableSession(_generation);
  }

  void dispose() {
    _generation++;
    _narratorSub?.cancel();
    _stateController.close();
  }

  /// Opens one listen session. Half-duplex guard: never while the narrator
  /// is speaking (callers always drain narration first; this is the
  /// structural backstop).
  Future<void> _startListen({required bool followUp}) async {
    if (_narrator.state.isSpeaking) return;
    final token = ++_generation;
    _followUpListen = followUp;
    _sawSpeech = false;
    _setPhase(VoiceConversationPhase.listening);
    try {
      await _stt.listen(
        localeId: _resolveLocale(),
        // The follow-up window IS the listen session's no-speech timeout:
        // 7 s of silence delivers an empty final → silent close.
        pauseFor: followUp
            ? AppConstants.voiceFollowUpWindow
            : AppConstants.voiceListenPauseFor,
        listenFor: AppConstants.voiceListenFor,
        onResult: (words, isFinal) => _onSttResult(token, words, isFinal),
      );
    } catch (e) {
      AppLogger.instance
          .error(LogSource.app, '[VoiceConversation] listen failed: $e');
      if (token != _generation) return;
      _generation++;
      _setPhase(VoiceConversationPhase.idle, VoiceCloseReason.silence);
    }
  }

  /// Per-session result callback. [token] was captured when the session
  /// started — stale callbacks are dropped without any state mutation.
  void _onSttResult(int token, String words, bool isFinal) {
    if (token != _generation ||
        _state.phase != VoiceConversationPhase.listening) {
      return; // Stale session (cancelled / superseded) — drop.
    }

    if (!isFinal) {
      if (!_sawSpeech && words.trim().isNotEmpty) {
        _sawSpeech = true;
        // The user started talking inside the follow-up window — collapse
        // the 7 s window to normal endpointing.
        if (_followUpListen) {
          _stt.changePauseFor(AppConstants.voiceListenPauseFor);
        }
      }
      return;
    }

    final text = words.trim();
    if (text.isEmpty) {
      _onUnusableSession(token);
      return;
    }

    if (_isExitPhrase(text)) {
      unawaited(exitConversationMode(reason: VoiceCloseReason.exitPhrase));
      return;
    }

    _strikes = 0;
    _generation++; // This session is consumed; late echoes are stale.
    _setPhase(VoiceConversationPhase.processing);
    _onSendVoiceMessage(text);
  }

  /// A session ended with nothing usable (empty final, timeout, no-match).
  void _onUnusableSession(int token) {
    if (token != _generation ||
        _state.phase != VoiceConversationPhase.listening) {
      return;
    }
    _generation++;

    if (_followUpListen) {
      // Silence in the follow-up window: close silently, never reprompt.
      _setPhase(VoiceConversationPhase.idle, VoiceCloseReason.silence);
      return;
    }

    _strikes++;
    if (_strikes >= AppConstants.voiceMaxStrikes) {
      // Visual fallback only — the UI shows a "didn't understand" state.
      _setPhase(VoiceConversationPhase.idle, VoiceCloseReason.notUnderstood);
      return;
    }
    unawaited(_clarifyAndRelisten());
  }

  /// First strike: one short spoken clarification, then re-listen.
  Future<void> _clarifyAndRelisten() async {
    final token = _generation;
    final locale = _resolveLocale();
    _setPhase(VoiceConversationPhase.speaking);
    await _narrator.beginTurn(locale);
    _narrator.narrateResponse(tr(locale).voiceClarificationPrompt);
    await _narrator.idle;
    if (token != _generation || !_state.isActive) return;
    await _startListen(followUp: false);
  }

  /// Turn done: wait for the narration queue to drain, then open the
  /// follow-up window.
  Future<void> _reListenAfterTurn() async {
    final token = _generation;
    await _narrator.idle;
    if (token != _generation) return;
    if (_state.phase != VoiceConversationPhase.processing &&
        _state.phase != VoiceConversationPhase.speaking) {
      return;
    }
    await _startListen(followUp: true);
  }

  /// Narrator activity drives the Processing ↔ Speaking display phases.
  void _onNarratorState(VoiceNarratorState narratorState) {
    if (narratorState.isSpeaking &&
        _state.phase == VoiceConversationPhase.processing) {
      _setPhase(VoiceConversationPhase.speaking);
    } else if (!narratorState.isSpeaking &&
        _state.phase == VoiceConversationPhase.speaking) {
      _setPhase(VoiceConversationPhase.processing);
    }
  }

  /// Matches the whole normalized utterance against the locale's exit
  /// tokens ([AppConstants.voiceExitPhrases] — matching tokens, not ARB
  /// display strings).
  bool _isExitPhrase(String text) {
    final normalized = _normalize(text);
    final phrases = AppConstants.voiceExitPhrases[_resolveLocale()] ??
        AppConstants.voiceExitPhrases['en']!;
    return phrases.any((p) => _normalize(p) == normalized);
  }

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('’', "'") // curly apostrophe → straight
      .replaceAll(RegExp(r'[.,!?;:]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _setPhase(VoiceConversationPhase phase,
      [VoiceCloseReason reason = VoiceCloseReason.none]) {
    _state = VoiceConversationState(phase: phase, closeReason: reason);
    if (!_stateController.isClosed) _stateController.add(_state);
  }
}
