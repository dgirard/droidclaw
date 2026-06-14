import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import '../config/log_entry.dart';
import '../tools/tool.dart';
import 'app_logger.dart';

/// Seam over the platform TTS engine so [VoiceNarrator] is unit-testable
/// (flutter_tts exposes no interface — this wraps it).
abstract class TtsEngine {
  /// One-time engine setup (await-speak-completion, queue mode, rate, volume).
  Future<void> init();

  /// Whether a voice exists for the given BCP-47 tag (e.g. `fr-FR`).
  Future<bool> isLanguageAvailable(String bcp47Tag);

  Future<void> setLanguage(String bcp47Tag);

  /// Speaks [text]; the future completes when the utterance finishes
  /// (or is stopped).
  Future<void> speak(String text);

  Future<void> stop();
}

/// Production [TtsEngine] backed by flutter_tts. Main isolate only.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setQueueMode(AppConstants.ttsQueueModeAdd);
    await _tts.setSpeechRate(AppConstants.ttsSpeechRate);
    await _tts.setVolume(1.0);
  }

  @override
  Future<bool> isLanguageAvailable(String bcp47Tag) async {
    final result = await _tts.isLanguageAvailable(bcp47Tag);
    return result == 1 || result == true;
  }

  @override
  Future<void> setLanguage(String bcp47Tag) => _tts.setLanguage(bcp47Tag);

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}

/// Degraded states surfaced to the UI (U11 pattern: never fail silently —
/// the text answer is always displayed regardless).
enum VoiceDegradation {
  none,

  /// No TTS voice for the configured locale — engine default voice is used.
  languageUnavailable,

  /// The TTS engine itself failed (missing/broken engine) — narration is off.
  engineUnavailable,
}

/// Observable narrator state for the chat UI (speaking indicator + snackbar).
class VoiceNarratorState {
  final bool isSpeaking;
  final VoiceDegradation degradation;

  const VoiceNarratorState({
    this.isSpeaking = false,
    this.degradation = VoiceDegradation.none,
  });
}

/// Speaks agent output for voice-initiated turns. Main isolate only —
/// Telegram/cron/subagent paths never construct or reach a narrator.
///
/// Utterances are queued in an internal FIFO and spoken sequentially
/// (engine `speak` is awaited per utterance), so narration never blocks the
/// agent event loop: `narrate*` methods enqueue and return immediately.
///
/// Interruption coverage (R2):
/// - Tap on the speaking indicator / first keystroke → [stop] (wired in UI).
/// - App lifecycle pause → [stop] (wired via WidgetsBindingObserver in
///   chat_screen), which covers incoming calls and backgrounding.
/// - NOT covered (documented gap): flutter_tts 4.x exposes no audio-focus
///   loss callback and no AUDIO_BECOMING_NOISY (headset unplug) event, so a
///   headset disconnect while the app stays foregrounded does not stop
///   narration. Android itself ducks/pauses TTS audio during calls.
class VoiceNarrator {
  final TtsEngine _engine;

  VoiceNarrator({required TtsEngine engine}) : _engine = engine;

  final _stateController = StreamController<VoiceNarratorState>.broadcast();
  VoiceNarratorState _state = const VoiceNarratorState();

  final List<String> _queue = [];
  bool _draining = false;
  Completer<void>? _idleCompleter;

  bool _initialized = false;
  bool _engineFailed = false;

  /// Set by [stop]; cleared by [beginTurn]. While muted, narrations of the
  /// in-flight turn are dropped (typing demotes the rest of the turn).
  bool _muted = false;

  String? _currentLanguageTag;
  String _linkWord = 'link';

  /// Current state (also emitted on [states] on every change).
  VoiceNarratorState get state => _state;

  /// State changes for the UI (speaking indicator, degradation snackbar).
  Stream<VoiceNarratorState> get states => _stateController.stream;

  /// Completes when the narration queue is fully drained.
  Future<void> get idle {
    if (!_draining) return Future.value();
    _idleCompleter ??= Completer<void>();
    return _idleCompleter!.future;
  }

  /// Prepares the narrator for a voice turn: unmutes, sets the TTS language
  /// from the app locale ([AppConstants.ttsLocaleTags] BCP-47 mapping).
  ///
  /// A missing voice for the locale or a broken engine degrades (state
  /// surfaced, logged) — it never throws and never blocks the turn.
  Future<void> beginTurn(String localeCode) async {
    _muted = false;
    _queue.clear();
    _linkWord = tr(localeCode).voiceLinkWord;

    if (_engineFailed) return; // Sticky: degradation already surfaced.

    try {
      if (!_initialized) {
        await _engine.init();
        _initialized = true;
      }
      final tag = AppConstants.ttsLocaleTags[localeCode] ?? localeCode;
      if (tag == _currentLanguageTag) return;
      if (await _engine.isLanguageAvailable(tag)) {
        await _engine.setLanguage(tag);
        _currentLanguageTag = tag;
        _setState(degradation: VoiceDegradation.none);
      } else {
        AppLogger.instance.warning(
          LogSource.app,
          '[VoiceNarrator] No TTS voice for "$tag" — using engine default',
        );
        _setState(degradation: VoiceDegradation.languageUnavailable);
      }
    } catch (e) {
      _engineFailed = true;
      AppLogger.instance.error(
        LogSource.app,
        '[VoiceNarrator] TTS engine unavailable: $e',
      );
      _setState(degradation: VoiceDegradation.engineUnavailable);
    }
  }

  /// Narrates a tool result's user-facing text. Silent results are never
  /// spoken; error results are spoken briefly
  /// ([AppConstants.ttsErrorNarrationMaxChars]).
  void narrateToolResult(ToolResult result) {
    if (result.silent) return;
    if (result.isError) {
      narrateError(result.forUser);
    } else {
      _enqueue(cleanForSpeech(result.forUser, linkWord: _linkWord));
    }
  }

  /// Narrates the final assistant response of a voice turn.
  void narrateResponse(String content) {
    _enqueue(cleanForSpeech(content, linkWord: _linkWord));
  }

  /// Narrates an error briefly (errors are spoken per plan, but capped).
  void narrateError(String message) {
    var text = cleanForSpeech(message, linkWord: _linkWord);
    if (text.length > AppConstants.ttsErrorNarrationMaxChars) {
      text = text.substring(0, AppConstants.ttsErrorNarrationMaxChars);
    }
    _enqueue(text);
  }

  /// Stops the current utterance, drops queued ones, and mutes the rest of
  /// the in-flight turn (until the next [beginTurn]).
  Future<void> stop() async {
    _muted = true;
    final wasActive = _draining || _queue.isNotEmpty;
    _queue.clear();
    if (!wasActive) return; // Avoid platform-channel spam on every keystroke.
    try {
      await _engine.stop();
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, '[VoiceNarrator] stop failed: $e');
    }
  }

  void dispose() {
    _queue.clear();
    _muted = true;
    // Best-effort stop so a hung _engine.speak() in an in-flight _drain()
    // doesn't keep blocking; ignore failures (engine may be broken/gone).
    unawaited(_engine.stop().catchError((_) {}));
    // Complete any pending idle waiter (VoiceConversationController awaits
    // narrator.idle): if _drain() is stuck on a hung speak(), its finally
    // block can never run, so release the waiter here to avoid a deadlock.
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    _stateController.close();
  }

  void _enqueue(String text) {
    if (_muted || _engineFailed || text.isEmpty) return;
    _queue.add(text);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    _setState(isSpeaking: true);
    try {
      while (_queue.isNotEmpty) {
        final text = _queue.removeAt(0);
        await _engine.speak(text);
      }
    } catch (e) {
      _queue.clear();
      _engineFailed = true;
      AppLogger.instance.error(
        LogSource.app,
        '[VoiceNarrator] speak failed — narration disabled: $e',
      );
      _setState(degradation: VoiceDegradation.engineUnavailable);
    } finally {
      _draining = false;
      _setState(isSpeaking: false);
      _idleCompleter?.complete();
      _idleCompleter = null;
    }
  }

  void _setState({bool? isSpeaking, VoiceDegradation? degradation}) {
    _state = VoiceNarratorState(
      isSpeaking: isSpeaking ?? _state.isSpeaking,
      degradation: degradation ?? _state.degradation,
    );
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  /// Prepares markdown-ish agent text for speech: fenced code blocks are
  /// skipped entirely, markdown links keep their label, URLs become
  /// [linkWord], markdown punctuation (`*_#\``) is dropped, whitespace is
  /// collapsed, and the result is capped at
  /// [AppConstants.ttsNarrationMaxChars].
  static final RegExp _fencedCodeRe = RegExp(r'```[\s\S]*?(```|$)');
  static final RegExp _markdownLinkRe = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');
  static final RegExp _bareUrlRe = RegExp(r'(https?://|www\.)\S+');
  static final RegExp _markdownPunctRe = RegExp(r'[*_`#]+');
  static final RegExp _whitespaceRe = RegExp(r'\s+');

  static String cleanForSpeech(String text, {String linkWord = 'link'}) {
    var s = text;
    // Fenced code blocks: skipped (not read aloud).
    s = s.replaceAll(_fencedCodeRe, ' ');
    // Markdown links [label](url) → label.
    s = s.replaceAllMapped(_markdownLinkRe, (m) => m[1] ?? '');
    // Bare URLs → localized "link" word.
    s = s.replaceAll(_bareUrlRe, linkWord);
    // Markdown punctuation: bold/italic/inline code/headings. Underscores in
    // snake_case identifiers become spaces — better for speech anyway.
    s = s.replaceAll(_markdownPunctRe, ' ');
    // Collapse whitespace.
    s = s.replaceAll(_whitespaceRe, ' ').trim();
    if (s.length > AppConstants.ttsNarrationMaxChars) {
      s = s.substring(0, AppConstants.ttsNarrationMaxChars);
    }
    return s;
  }
}
