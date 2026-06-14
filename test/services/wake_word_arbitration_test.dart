import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/services/wake_word_service.dart';
import 'package:droidclaw/providers/background_service_provider.dart';
import 'package:droidclaw/shared/constants.dart';

/// Recording fake for the [KeywordDetector] seam — no real ONNX model. A test
/// triggers a detection by setting [nextHit]; the next accepted frame returns
/// it once (then it is consumed, like a real one-shot detection + reset).
class FakeKeywordDetector implements KeywordDetector {
  int startCalls = 0;
  int stopCalls = 0;
  int resetCalls = 0;
  int framesAccepted = 0;
  String? startedKeyword;
  bool throwOnStart = false;

  /// Set to make the next [acceptWaveform] report a detection.
  String? nextHit;

  @override
  Future<void> start({required String keyword}) async {
    if (throwOnStart) throw StateError('model load failed');
    startCalls++;
    startedKeyword = keyword;
  }

  @override
  String? acceptWaveform(Int16List frame) {
    framesAccepted++;
    final hit = nextHit;
    nextHit = null;
    return hit;
  }

  @override
  void reset() => resetCalls++;

  @override
  Future<void> stop() async => stopCalls++;
}

/// Controllable fake [AudioSource] — the test pushes frames manually so the
/// detection path is deterministic (no real mic, no timers).
class FakeAudioSource implements AudioSource {
  final _controller = StreamController<Int16List>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  bool get isOpen => startCalls > stopCalls;

  @override
  Stream<Int16List> get frames => _controller.stream;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  void pushFrame() =>
      _controller.add(Int16List(AppConstants.wakeWordFrameSamples));

  void close() => _controller.close();
}

void main() {
  late FakeKeywordDetector detector;
  late FakeAudioSource audio;
  late List<WakeIntent> wakes;
  late WakeWordService service;

  WakeWordService build({String keyword = 'hey claw'}) {
    return WakeWordService(
      detector: detector,
      audio: audio,
      keyword: keyword,
      onWake: wakes.add,
    );
  }

  setUp(() {
    detector = FakeKeywordDetector();
    audio = FakeAudioSource();
    wakes = [];
    service = build();
  });

  tearDown(() {
    service.dispose();
    audio.close();
  });

  /// Flush pending microtasks / broadcast-stream deliveries.
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('start / stop lifecycle', () {
    test('start engages the mic and loads the model with the keyword',
        () async {
      await service.start();
      expect(detector.startCalls, 1);
      expect(detector.startedKeyword, 'hey claw');
      expect(audio.isOpen, isTrue);
      expect(service.state.phase, WakeWordPhase.listening);
      expect(service.canListen, isTrue);
    });

    test('empty keyword falls back to the default', () async {
      service.dispose();
      service = build(keyword: '   ');
      await service.start();
      expect(detector.startedKeyword, AppConstants.wakeWordDefaultKeyword);
    });

    test('stop releases the mic and frees the engine', () async {
      await service.start();
      await service.stop();
      expect(audio.isOpen, isFalse);
      expect(detector.stopCalls, 1);
      expect(service.state.phase, WakeWordPhase.stopped);
      expect(service.canListen, isFalse);
    });

    test('a detector start failure leaves the service stopped (degrades)',
        () async {
      detector.throwOnStart = true;
      await expectLater(service.start(), throwsA(isA<StateError>()));
      expect(service.isStarted, isFalse);
      expect(service.state.phase, WakeWordPhase.stopped);
      expect(audio.isOpen, isFalse);
    });
  });

  group('arbitration — suspend / resume', () {
    test('STT active suspends the listener; clearing it resumes', () async {
      await service.start();
      expect(service.canListen, isTrue);

      await service.suspend(WakeWordSuspendReason.sttActive);
      expect(service.state.phase, WakeWordPhase.suspended);
      expect(service.canListen, isFalse);
      expect(audio.isOpen, isFalse, reason: 'mic released while suspended');

      await service.resume(WakeWordSuspendReason.sttActive);
      expect(service.state.phase, WakeWordPhase.listening);
      expect(service.canListen, isTrue);
      expect(audio.isOpen, isTrue);
    });

    test('narrator speaking suspends the listener', () async {
      await service.start();
      await service.suspend(WakeWordSuspendReason.narratorSpeaking);
      expect(service.canListen, isFalse);
      expect(audio.isOpen, isFalse);
    });

    test('radio playback suspends the listener', () async {
      await service.start();
      await service.suspend(WakeWordSuspendReason.radioPlaying);
      expect(service.canListen, isFalse);
    });

    test('phone call / audio-focus loss suspends, no wake during the call',
        () async {
      await service.start();
      await service.suspend(WakeWordSuspendReason.phoneCall);
      expect(service.canListen, isFalse);

      // A frame that races in during the call must not wake the assistant.
      detector.nextHit = 'hey claw';
      audio.pushFrame();
      await pump();
      expect(wakes, isEmpty, reason: 'no wake while suspended for a call');
    });

    test('resumes only when ALL reasons are clear', () async {
      await service.start();
      await service.suspend(WakeWordSuspendReason.sttActive);
      await service.suspend(WakeWordSuspendReason.narratorSpeaking);
      expect(service.activeCount, 2);

      await service.resume(WakeWordSuspendReason.sttActive);
      expect(service.canListen, isFalse,
          reason: 'still suspended by the narrator');
      expect(service.state.phase, WakeWordPhase.suspended);

      await service.resume(WakeWordSuspendReason.narratorSpeaking);
      expect(service.canListen, isTrue);
      expect(service.state.phase, WakeWordPhase.listening);
    });

    test('suspend / resume are idempotent', () async {
      await service.start();
      await service.suspend(WakeWordSuspendReason.sttActive);
      await service.suspend(WakeWordSuspendReason.sttActive);
      await service.resume(WakeWordSuspendReason.sttActive);
      expect(service.canListen, isTrue);
      // Resuming a reason that is not set is a no-op.
      await service.resume(WakeWordSuspendReason.radioPlaying);
      expect(service.canListen, isTrue);
    });
  });

  group('detection → wake routing', () {
    test('a detection routes a voice-modality conversation-entry intent',
        () async {
      await service.start();
      detector.nextHit = 'hey claw';
      audio.pushFrame();
      await pump();

      expect(wakes, hasLength(1));
      expect(wakes.single.modality, WakeModality.voice);
      expect(wakes.single.keyword, 'hey claw');
      expect(detector.resetCalls, 1, reason: 'decoder reset after detection');
    });

    test('non-detection frames do not wake', () async {
      await service.start();
      audio.pushFrame();
      audio.pushFrame();
      await pump();
      expect(wakes, isEmpty);
      expect(detector.framesAccepted, greaterThanOrEqualTo(2));
    });
  });

  group('stopServiceIfIdle accounting (wake word as a consumer)', () {
    test('wake word active keeps the service alive (not killed)', () {
      // No crons, no Telegram, but the wake word is on → still a consumer.
      expect(
        BackgroundServiceNotifier.hasServiceConsumer(
          hasActiveCrons: false,
          telegramEnabled: false,
          wakeWordEnabled: true,
        ),
        isTrue,
        reason: 'toggling crons/Telegram off must not kill an active wake word',
      );
    });

    test('wake word disabled with no other consumer → service stops', () {
      expect(
        BackgroundServiceNotifier.hasServiceConsumer(
          hasActiveCrons: false,
          telegramEnabled: false,
          wakeWordEnabled: false,
        ),
        isFalse,
      );
    });

    test('another consumer keeps the service alive even with wake word off',
        () {
      expect(
        BackgroundServiceNotifier.hasServiceConsumer(
          hasActiveCrons: true,
          telegramEnabled: false,
          wakeWordEnabled: false,
        ),
        isTrue,
      );
    });
  });

  group('spike-only boundary (documented)', () {
    test('real mic capture + battery are NOT unit-testable — asserted here',
        () {
      // The arbitration machine, routing, and accounting are covered above
      // with seams. Real PCM capture survival across backgrounding and 24 h
      // battery duty-cycle are measured by the on-device spike S2 only
      // (tool/SPIKE_WAKE_WORD.md) — there is intentionally NO unit test for
      // them. This test documents that boundary and pins the battery gate.
      expect(AppConstants.wakeWordMaxBatteryPctPerDay, 3.0);
      expect(AppConstants.wakeWordSampleRate, 16000);
    });
  });
}
