import 'dart:async';
import 'dart:typed_data';

import '../../shared/constants.dart';
import '../config/log_entry.dart';
import 'app_logger.dart';

/// Seam over the sherpa_onnx [KeywordSpotter] so [WakeWordService] is
/// unit-testable (mirrors U1's [TtsEngine] / U5's [SttEngine] seams). sherpa
/// is FFI, so the real implementation works in ANY isolate — but a unit test
/// must never load a 25 MB ONNX model or open a real recognizer.
///
/// Lifecycle: [start] loads the model + opens a streaming keyword stream for
/// [keyword]; [acceptWaveform] feeds 16 kHz mono int16 PCM frames and returns
/// the detected keyword (non-null) on a hit; [reset] clears the decoder state
/// after a detection; [stop] frees the native resources.
abstract class KeywordDetector {
  Future<void> start({required String keyword});

  /// Feeds one PCM frame. Returns the matched keyword on a detection in this
  /// frame, or null. The implementation owns the decode loop (isReady/decode).
  String? acceptWaveform(Int16List frame);

  /// Clears decoder state so the same utterance is not re-detected.
  void reset();

  Future<void> stop();
}

/// Seam over the microphone PCM source (the real one is backed by the
/// dedicated microphone foreground service — main isolate / native capture).
/// Emits 16 kHz mono int16 frames of [AppConstants.wakeWordFrameSamples].
abstract class AudioSource {
  /// Starts capturing. Frames arrive on [frames] until [stop].
  Future<void> start();

  Stream<Int16List> get frames;

  Future<void> stop();
}

/// Why the wake word listener is currently NOT consuming audio.
///
/// The listener is a single arbiter: ANY active reason suspends it. The mic is
/// structurally never open during a competing audio activity (R5).
enum WakeWordSuspendReason {
  /// A V2 STT listen session is active (conversation mode / single-shot).
  sttActive,

  /// VoiceNarrator (TTS) is speaking.
  narratorSpeaking,

  /// Radio playback is active.
  radioPlaying,

  /// A phone call / audio-focus loss (telephony or AUDIOFOCUS_LOSS).
  phoneCall,
}

/// Phase of the wake word listener.
enum WakeWordPhase {
  /// Service not started (disabled, or before the app started it from the
  /// foreground). After reboot this is the only reachable state until the app
  /// is opened once (Android 14+ forbids background start of a mic FGS).
  stopped,

  /// Started and actively consuming audio, watching for the keyword.
  listening,

  /// Started but suspended by one or more [WakeWordSuspendReason]s — the mic
  /// is released; audio is not consumed.
  suspended,
}

/// Observable state for the settings UI.
class WakeWordState {
  final WakeWordPhase phase;
  final Set<WakeWordSuspendReason> activeReasons;

  /// True after the service was requested but cannot run until the app is
  /// opened (post-reboot limitation — surfaced in settings, R5).
  final bool inactiveUntilAppOpened;

  const WakeWordState({
    this.phase = WakeWordPhase.stopped,
    this.activeReasons = const {},
    this.inactiveUntilAppOpened = false,
  });

  bool get isRunning => phase != WakeWordPhase.stopped;

  WakeWordState copyWith({
    WakeWordPhase? phase,
    Set<WakeWordSuspendReason>? activeReasons,
    bool? inactiveUntilAppOpened,
  }) =>
      WakeWordState(
        phase: phase ?? this.phase,
        activeReasons: activeReasons ?? this.activeReasons,
        inactiveUntilAppOpened:
            inactiveUntilAppOpened ?? this.inactiveUntilAppOpened,
      );
}

/// Hands-free wake word listener (U7, gated on spike S2).
///
/// "Hey Claw" → the assistant wakes and enters conversation mode (U5). The
/// service is OFF by default and only startable from the foreground.
///
/// Mic arbitration (R5) is the unit-testable core: the listener SUSPENDS
/// while any of [WakeWordSuspendReason] is active (STT session, TTS narration,
/// radio, phone call) and RESUMES only when ALL are clear. The mic is never
/// open during a competing audio activity — suspension releases the audio
/// source so the second mic FGS and the STT recognizer never contend.
///
/// Seams ([KeywordDetector], [AudioSource]) keep the engine + mic out of unit
/// tests — the arbitration state machine, detection routing, and the
/// stopServiceIfIdle accounting are all asserted without a real model or mic
/// (real capture + battery are spike-only, see tool/SPIKE_WAKE_WORD.md).
///
/// UI learning honored: there is NEVER a "stop" button on the persistent
/// notification — the only off switch is the settings toggle. The green mic
/// indicator and the post-reboot limitation are explained in the settings
/// screen, not fought with a notification action.
class WakeWordService {
  final KeywordDetector _detector;
  final AudioSource _audio;
  final String _keyword;

  /// Invoked on a confirmed detection — the app should be brought to the
  /// foreground and a voice-modality conversation entry initiated (U5). The
  /// intent carries the matched keyword and the voice modality.
  final void Function(WakeIntent intent) _onWake;

  WakeWordService({
    required KeywordDetector detector,
    required AudioSource audio,
    required String keyword,
    required void Function(WakeIntent intent) onWake,
  })  : _detector = detector,
        _audio = audio,
        _keyword = keyword.trim().isEmpty
            ? AppConstants.wakeWordDefaultKeyword
            : keyword.trim(),
        _onWake = onWake;

  final _stateController = StreamController<WakeWordState>.broadcast();
  WakeWordState _state = const WakeWordState();
  StreamSubscription<Int16List>? _frameSub;

  /// Reasons currently forcing suspension. Empty ⇒ free to listen.
  final Set<WakeWordSuspendReason> _reasons = {};

  bool _started = false;

  WakeWordState get state => _state;
  Stream<WakeWordState> get states => _stateController.stream;

  /// Whether the listener is started (running, possibly suspended).
  bool get isStarted => _started;

  /// Starts the listener. MUST be called from the app foreground (the caller —
  /// [WakeWordService] does not check; the foreground-only-start constraint is
  /// enforced at the call site that owns the FGS). Loads the model, opens the
  /// keyword stream, and begins consuming audio unless a suspend reason is
  /// already active.
  ///
  /// No-op if already started.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    AppLogger.instance.info(
        LogSource.app, '[WakeWord] starting listener (keyword="$_keyword")');
    try {
      await _detector.start(keyword: _keyword);
    } catch (e) {
      _started = false;
      AppLogger.instance
          .error(LogSource.app, '[WakeWord] detector start failed: $e');
      _setState(_state.copyWith(
          phase: WakeWordPhase.stopped, inactiveUntilAppOpened: false));
      rethrow;
    }
    if (_reasons.isEmpty) {
      await _engageAudio();
    } else {
      _setState(_state.copyWith(
          phase: WakeWordPhase.suspended,
          activeReasons: Set.of(_reasons),
          inactiveUntilAppOpened: false));
    }
  }

  /// Stops the listener entirely: releases the mic and frees the engine.
  /// Safe to call when already stopped.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _releaseAudio();
    try {
      await _detector.stop();
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, '[WakeWord] detector stop failed: $e');
    }
    _setState(_state.copyWith(
        phase: WakeWordPhase.stopped, activeReasons: const {}));
    AppLogger.instance.info(LogSource.app, '[WakeWord] listener stopped');
  }

  /// Records that [reason] now forbids listening. While ANY reason is active
  /// the mic is released. Idempotent.
  Future<void> suspend(WakeWordSuspendReason reason) async {
    final wasFree = _reasons.isEmpty;
    if (!_reasons.add(reason)) return; // Already suspended for this reason.
    AppLogger.instance.debug(
        LogSource.app, '[WakeWord] suspend (${reason.name})');
    if (!_started) {
      _setState(_state.copyWith(activeReasons: Set.of(_reasons)));
      return;
    }
    if (wasFree) {
      // First reason: release the mic.
      await _releaseAudio();
      _setState(_state.copyWith(
          phase: WakeWordPhase.suspended, activeReasons: Set.of(_reasons)));
    } else {
      _setState(_state.copyWith(activeReasons: Set.of(_reasons)));
    }
  }

  /// Clears [reason]. The listener resumes only when ALL reasons are clear.
  /// Idempotent.
  Future<void> resume(WakeWordSuspendReason reason) async {
    if (!_reasons.remove(reason)) return;
    AppLogger.instance
        .debug(LogSource.app, '[WakeWord] resume (${reason.name})');
    if (!_started) {
      _setState(_state.copyWith(activeReasons: Set.of(_reasons)));
      return;
    }
    if (_reasons.isEmpty) {
      await _engageAudio();
    } else {
      _setState(_state.copyWith(activeReasons: Set.of(_reasons)));
    }
  }

  /// True when listening is currently permitted (started + no suspend reason).
  bool get canListen => _started && _reasons.isEmpty;

  /// Number of active suspend reasons (0 ⇒ free to listen when started).
  int get activeCount => _reasons.length;

  void dispose() {
    _frameSub?.cancel();
    _stateController.close();
  }

  /// Opens the audio source and begins feeding frames to the detector.
  Future<void> _engageAudio() async {
    if (_frameSub != null) return;
    try {
      await _audio.start();
      _frameSub = _audio.frames.listen(_onFrame);
      _setState(_state.copyWith(
          phase: WakeWordPhase.listening,
          activeReasons: const {},
          inactiveUntilAppOpened: false));
      AppLogger.instance.debug(LogSource.app, '[WakeWord] listening');
    } catch (e) {
      AppLogger.instance
          .error(LogSource.app, '[WakeWord] audio start failed: $e');
      _setState(_state.copyWith(phase: WakeWordPhase.suspended));
    }
  }

  /// Releases the audio source (suspension or stop).
  Future<void> _releaseAudio() async {
    await _frameSub?.cancel();
    _frameSub = null;
    try {
      await _audio.stop();
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, '[WakeWord] audio stop failed: $e');
    }
  }

  /// One PCM frame from the mic. Dropped silently if a suspend reason raced in
  /// after the frame was enqueued (defensive — _releaseAudio cancels the sub).
  void _onFrame(Int16List frame) {
    if (!canListen) return;
    final String? hit;
    try {
      hit = _detector.acceptWaveform(frame);
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, '[WakeWord] decode failed: $e');
      return;
    }
    if (hit == null) return;
    _detector.reset();
    AppLogger.instance
        .info(LogSource.app, '[WakeWord] DETECTED "$hit" — waking');
    _onWake(WakeIntent(keyword: hit));
  }

  void _setState(WakeWordState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(_state);
  }
}

/// A confirmed wake event. Always carries the voice modality so the receiver
/// opens a SPOKEN conversation turn (U5), never a typed one.
class WakeIntent {
  /// Always [WakeModality.voice] — a wake is by definition hands-free.
  final WakeModality modality;
  final String keyword;

  const WakeIntent({
    required this.keyword,
    this.modality = WakeModality.voice,
  });
}

/// Modality carried by a wake intent. Distinct enum (not a bool) so future
/// non-voice wakes (e.g. a hardware button) can be added without ambiguity.
enum WakeModality { voice }
