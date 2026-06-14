import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/services/voice_narrator.dart';
import 'package:droidclaw/features/chat/voice_conversation_controller.dart';
import 'package:droidclaw/l10n/l10n.dart';
import 'package:droidclaw/shared/constants.dart';

/// Minimal recording [TtsEngine] fake (same shape as voice_narrator_test) —
/// the controller is exercised against a REAL VoiceNarrator so the
/// half-duplex coupling (isSpeaking / idle) is the production code path.
class FakeTtsEngine implements TtsEngine {
  final spoken = <String>[];

  /// When set, speak() blocks until the gate completes.
  Completer<void>? speakGate;

  @override
  Future<void> init() async {}

  @override
  Future<bool> isLanguageAvailable(String bcp47Tag) async => true;

  @override
  Future<void> setLanguage(String bcp47Tag) async {}

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    if (speakGate != null) await speakGate!.future;
  }

  @override
  Future<void> stop() async {
    if (speakGate != null && !speakGate!.isCompleted) {
      speakGate!.complete();
    }
    speakGate = null;
  }
}

/// One recorded STT listen session — the test invokes [onResult] to play
/// the platform recognizer.
class FakeListenSession {
  final String localeId;
  final Duration pauseFor;
  final Duration listenFor;
  final void Function(String recognizedWords, bool finalResult) onResult;

  FakeListenSession({
    required this.localeId,
    required this.pauseFor,
    required this.listenFor,
    required this.onResult,
  });
}

/// Recording fake for the [SttEngine] seam.
class FakeSttEngine implements SttEngine {
  final sessions = <FakeListenSession>[];
  final pauseChanges = <Duration>[];
  int stopCalls = 0;
  int cancelCalls = 0;

  FakeListenSession get last => sessions.last;

  @override
  Future<void> listen({
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
    required void Function(String recognizedWords, bool finalResult) onResult,
  }) async {
    sessions.add(FakeListenSession(
      localeId: localeId,
      pauseFor: pauseFor,
      listenFor: listenFor,
      onResult: onResult,
    ));
  }

  @override
  void changePauseFor(Duration pauseFor) => pauseChanges.add(pauseFor);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;
}

void main() {
  late FakeSttEngine stt;
  late FakeTtsEngine tts;
  late VoiceNarrator narrator;
  late List<String> sent;
  late VoiceConversationController controller;
  var locale = 'en';

  setUp(() {
    locale = 'en';
    stt = FakeSttEngine();
    tts = FakeTtsEngine();
    narrator = VoiceNarrator(engine: tts);
    sent = [];
    controller = VoiceConversationController(
      stt: stt,
      narrator: narrator,
      resolveLocale: () => locale,
      onSendVoiceMessage: sent.add,
    );
  });

  tearDown(() {
    controller.dispose();
    narrator.dispose();
  });

  /// Flushes pending microtasks / stream deliveries.
  Future<void> pump([int times = 4]) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Runs enter → final result → turn finished, landing in the follow-up
  /// listen window (no narration in between — narrator idle).
  Future<void> reachFollowUpWindow() async {
    await controller.enterConversationMode();
    stt.last.onResult('what is the weather', true);
    expect(sent, ['what is the weather']);
    controller.onTurnFinished();
    await pump();
    expect(stt.sessions, hasLength(2));
    expect(controller.state.phase, VoiceConversationPhase.listening);
  }

  test('enter opens an endpointed dictation session and goes Listening',
      () async {
    await controller.enterConversationMode();

    expect(controller.state.phase, VoiceConversationPhase.listening);
    expect(stt.sessions, hasLength(1));
    expect(stt.last.localeId, 'en');
    expect(stt.last.pauseFor, AppConstants.voiceListenPauseFor);
    expect(stt.last.listenFor, AppConstants.voiceListenFor);
  });

  test(
      'full cycle: final result auto-sends, narration plays, follow-up '
      'window re-listens, second result sends again', () async {
    await controller.enterConversationMode();

    stt.last.onResult('what is the weather', true);
    expect(sent, ['what is the weather']);
    expect(controller.state.phase, VoiceConversationPhase.processing);

    // Chat layer narrates the response (voice modality turn).
    tts.speakGate = Completer<void>();
    await narrator.beginTurn('en');
    narrator.narrateResponse('Sunny and warm');
    await pump();
    expect(controller.state.phase, VoiceConversationPhase.speaking);

    // Turn ends while still speaking — mic must stay closed (half-duplex).
    controller.onTurnFinished();
    await pump();
    expect(stt.sessions, hasLength(1));

    // Narration drains → the 7 s follow-up window opens.
    tts.speakGate!.complete();
    await pump();
    expect(stt.sessions, hasLength(2));
    expect(stt.last.pauseFor, AppConstants.voiceFollowUpWindow);
    expect(controller.state.phase, VoiceConversationPhase.listening);

    stt.last.onResult('and tomorrow', true);
    expect(sent, ['what is the weather', 'and tomorrow']);
    expect(controller.state.phase, VoiceConversationPhase.processing);
  });

  test('stale-generation final result is dropped without any state change',
      () async {
    await reachFollowUpWindow();
    final staleSession = stt.sessions.first;

    // The first session's late callback fires while the SECOND session is
    // listening — same phase, older token: must be ignored.
    staleSession.onResult('ghost words', true);

    expect(sent, ['what is the weather']); // no second send
    expect(controller.state.phase, VoiceConversationPhase.listening);
    expect(stt.sessions, hasLength(2)); // no extra session spawned
  });

  test('late result after explicit exit is dropped', () async {
    await controller.enterConversationMode();
    final session = stt.last;
    await controller.exitConversationMode();

    session.onResult('too late', true);

    expect(sent, isEmpty);
    expect(controller.state.phase, VoiceConversationPhase.idle);
  });

  test('silence in the 7s follow-up window closes silently', () async {
    await reachFollowUpWindow();

    stt.last.onResult('', true); // window elapsed with no speech
    await pump();

    expect(controller.state.phase, VoiceConversationPhase.idle);
    expect(controller.state.closeReason, VoiceCloseReason.silence);
    expect(tts.spoken, isEmpty); // no audible reprompt
    expect(sent, ['what is the weather']);
  });

  test('recognizer timeout error in the follow-up window closes silently',
      () async {
    await reachFollowUpWindow();

    controller.onSttError('error_speech_timeout');
    await pump();

    expect(controller.state.phase, VoiceConversationPhase.idle);
    expect(controller.state.closeReason, VoiceCloseReason.silence);
    expect(tts.spoken, isEmpty);
  });

  test('exit phrase ends the conversation immediately without sending',
      () async {
    locale = 'fr';
    await controller.enterConversationMode();

    stt.last.onResult('Merci !', true);
    await pump();

    expect(sent, isEmpty);
    expect(controller.state.phase, VoiceConversationPhase.idle);
    expect(controller.state.closeReason, VoiceCloseReason.exitPhrase);
    expect(stt.cancelCalls, 1);
  });

  test('exit phrase matching normalizes curly apostrophes and punctuation',
      () async {
    locale = 'fr';
    await controller.enterConversationMode();

    stt.last.onResult('C’est tout.', true);
    await pump();

    expect(sent, isEmpty);
    expect(controller.state.closeReason, VoiceCloseReason.exitPhrase);
  });

  test('a sentence merely containing an exit token is still sent', () async {
    await controller.enterConversationMode();

    stt.last.onResult('thank you for nothing tell me more', true);

    expect(sent, ['thank you for nothing tell me more']);
    expect(controller.state.phase, VoiceConversationPhase.processing);
  });

  test('typing exit: cancels the session, stops narration, goes Idle',
      () async {
    await controller.enterConversationMode();

    await controller.exitConversationMode(); // wired to onUserTyped / chip tap

    expect(controller.state.phase, VoiceConversationPhase.idle);
    expect(controller.state.closeReason, VoiceCloseReason.userExit);
    expect(stt.cancelCalls, 1);
  });

  test('Processing ignores recognizer done events — no double session',
      () async {
    await controller.enterConversationMode();
    stt.last.onResult('hello there', true);
    expect(controller.state.phase, VoiceConversationPhase.processing);

    controller.onSttStatus('doneNoResult');
    controller.onSttStatus('done');
    controller.onSttStatus('notListening');
    controller.onSttError('error_speech_timeout');
    await pump();

    expect(controller.state.phase, VoiceConversationPhase.processing);
    expect(stt.sessions, hasLength(1));
  });

  test(
      'first unusable session: one spoken clarification then re-listen; '
      'second: exits with visual fallback', () async {
    await controller.enterConversationMode();

    // Strike 1 — empty final: clarification is narrated, then re-listen.
    stt.last.onResult('', true);
    await pump();
    expect(
      tts.spoken,
      [VoiceNarrator.cleanForSpeech(tr('en').voiceClarificationPrompt)],
    );
    expect(stt.sessions, hasLength(2));
    expect(stt.last.pauseFor, AppConstants.voiceListenPauseFor); // not 7 s
    expect(controller.state.phase, VoiceConversationPhase.listening);

    // Strike 2 — still nothing: exit, display-only (no more speech).
    stt.last.onResult('', true);
    await pump();
    expect(controller.state.phase, VoiceConversationPhase.idle);
    expect(controller.state.closeReason, VoiceCloseReason.notUnderstood);
    expect(tts.spoken, hasLength(1)); // exactly one clarification, ever
    expect(sent, isEmpty);
  });

  test('half-duplex: follow-up listen never starts while narrator speaks',
      () async {
    await controller.enterConversationMode();
    stt.last.onResult('tell me a story', true);

    tts.speakGate = Completer<void>();
    await narrator.beginTurn('en');
    narrator.narrateResponse('Once upon a time');
    controller.onTurnFinished();
    await pump();

    expect(narrator.state.isSpeaking, isTrue);
    expect(stt.sessions, hasLength(1)); // mic still closed

    tts.speakGate!.complete();
    await pump();
    expect(stt.sessions, hasLength(2)); // opens only after the drain
  });

  test('speech inside the follow-up window collapses it to endpointing',
      () async {
    await reachFollowUpWindow();

    stt.last.onResult('so about', false); // partial — user started talking
    stt.last.onResult('so about that trip', false);

    expect(stt.pauseChanges, [AppConstants.voiceListenPauseFor]); // once
  });

  test('onTurnFinished outside conversation mode never opens the mic',
      () async {
    controller.onTurnFinished(); // e.g. a typed turn finished
    await pump();

    expect(stt.sessions, isEmpty);
    expect(controller.state.phase, VoiceConversationPhase.idle);
  });
}
