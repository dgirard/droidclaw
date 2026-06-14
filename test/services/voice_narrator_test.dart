import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/services/voice_narrator.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/shared/constants.dart';

/// Recording fake for the [TtsEngine] seam (flutter_tts has no interface,
/// so VoiceNarrator depends on the TtsEngine abstraction instead).
class FakeTtsEngine implements TtsEngine {
  final spoken = <String>[];
  final languagesSet = <String>[];
  Set<String> availableLanguages = {
    'en-US',
    'fr-FR',
    'es-ES',
    'de-DE',
    'it-IT',
  };
  bool initCalled = false;
  bool throwOnInit = false;
  bool throwOnSpeak = false;
  int stopCalls = 0;

  /// When set, speak() blocks until the gate completes (or stop() is called).
  Completer<void>? speakGate;

  /// When false, stop() does NOT release a pending speakGate — models a TTS
  /// engine whose stop() is itself a no-op/hung, so the drain stays blocked.
  bool stopUnblocksSpeak = true;

  @override
  Future<void> init() async {
    if (throwOnInit) throw StateError('no TTS engine installed');
    initCalled = true;
  }

  @override
  Future<bool> isLanguageAvailable(String bcp47Tag) async =>
      availableLanguages.contains(bcp47Tag);

  @override
  Future<void> setLanguage(String bcp47Tag) async =>
      languagesSet.add(bcp47Tag);

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw StateError('speak failed');
    spoken.add(text);
    if (speakGate != null) await speakGate!.future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopUnblocksSpeak && speakGate != null && !speakGate!.isCompleted) {
      speakGate!.complete();
      speakGate = null;
    }
  }
}

void main() {
  late FakeTtsEngine engine;
  late VoiceNarrator narrator;

  setUp(() {
    engine = FakeTtsEngine();
    narrator = VoiceNarrator(engine: engine);
  });

  group('cleanForSpeech', () {
    test('strips markdown bold, italic, inline code, and headings', () {
      expect(
        VoiceNarrator.cleanForSpeech('# Title\n**bold** and *italic* `code`'),
        'Title bold and italic code',
      );
    });

    test('skips fenced code blocks entirely', () {
      expect(
        VoiceNarrator.cleanForSpeech('Before\n```dart\nprint("x");\n```\nAfter'),
        'Before After',
      );
    });

    test('keeps the label of markdown links', () {
      expect(
        VoiceNarrator.cleanForSpeech('See [the docs](https://example.com/a)'),
        'See the docs',
      );
    });

    test('replaces bare URLs with the localized link word', () {
      expect(
        VoiceNarrator.cleanForSpeech('Go to https://example.com/x?q=1 now',
            linkWord: 'lien'),
        'Go to lien now',
      );
    });

    test('caps output at ttsNarrationMaxChars', () {
      final long = 'a' * (AppConstants.ttsNarrationMaxChars + 500);
      expect(
        VoiceNarrator.cleanForSpeech(long).length,
        AppConstants.ttsNarrationMaxChars,
      );
    });
  });

  group('language setup (beginTurn)', () {
    test('maps app locale fr to BCP-47 fr-FR', () async {
      await narrator.beginTurn('fr');
      expect(engine.languagesSet, ['fr-FR']);
      expect(narrator.state.degradation, VoiceDegradation.none);
    });

    test('maps every supported app locale to its BCP-47 tag', () async {
      for (final entry in AppConstants.ttsLocaleTags.entries) {
        final e = FakeTtsEngine();
        final n = VoiceNarrator(engine: e);
        await n.beginTurn(entry.key);
        expect(e.languagesSet, [entry.value]);
      }
    });

    test('unavailable language degrades but still narrates (no silence)',
        () async {
      engine.availableLanguages = {}; // no voices for any locale
      final states = <VoiceNarratorState>[];
      final sub = narrator.states.listen(states.add);

      await narrator.beginTurn('fr');
      // Let the broadcast stream deliver.
      await Future<void>.delayed(Duration.zero);
      expect(engine.languagesSet, isEmpty);
      expect(
          narrator.state.degradation, VoiceDegradation.languageUnavailable);
      expect(
        states.map((s) => s.degradation),
        contains(VoiceDegradation.languageUnavailable),
      );

      narrator.narrateResponse('Bonjour');
      await narrator.idle;
      expect(engine.spoken, ['Bonjour']); // fallback voice, not silence

      await sub.cancel();
    });

    test('engine init failure surfaces engineUnavailable and never throws',
        () async {
      engine.throwOnInit = true;
      await narrator.beginTurn('en'); // must not throw
      expect(narrator.state.degradation, VoiceDegradation.engineUnavailable);

      narrator.narrateResponse('hello');
      await narrator.idle;
      expect(engine.spoken, isEmpty); // narration off, text still in UI
    });
  });

  group('narration content', () {
    setUp(() async => narrator.beginTurn('en'));

    test('narrateResponse speaks cleaned text', () async {
      narrator.narrateResponse('**Hello** _world_');
      await narrator.idle;
      expect(engine.spoken, ['Hello world']);
    });

    test('narrateToolResult speaks forUser, never forLLM', () async {
      narrator.narrateToolResult(ToolResult.dual(
        forLLM: 'STRUCTURED-LLM-DATA',
        forUser: 'Sunny, 20 degrees',
      ));
      await narrator.idle;
      expect(engine.spoken, ['Sunny, 20 degrees']);
    });

    test('silent ToolResult is never spoken', () async {
      narrator.narrateToolResult(ToolResult.silent('internal bookkeeping'));
      await narrator.idle;
      expect(engine.spoken, isEmpty);
    });

    test('error ToolResult is spoken briefly (capped)', () async {
      final longError = 'failure ${'x' * 1000}';
      narrator.narrateToolResult(ToolResult.error(longError));
      await narrator.idle;
      expect(engine.spoken, hasLength(1));
      expect(engine.spoken.first.length,
          lessThanOrEqualTo(AppConstants.ttsErrorNarrationMaxChars));
      expect(engine.spoken.first, startsWith('failure'));
    });

    test('speak failure mid-narration degrades without crashing', () async {
      engine.throwOnSpeak = true;
      narrator.narrateResponse('hello');
      await narrator.idle;
      expect(narrator.state.degradation, VoiceDegradation.engineUnavailable);
      narrator.narrateResponse('again'); // muted by engine failure, no throw
      await narrator.idle;
    });
  });

  group('stop and mute semantics', () {
    test('stop() cuts the current utterance and drops queued ones', () async {
      await narrator.beginTurn('en');
      engine.speakGate = Completer<void>();
      narrator.narrateResponse('first utterance');
      narrator.narrateToolResult(ToolResult.simple('queued result'));

      await narrator.stop();
      await narrator.idle;

      expect(engine.stopCalls, 1);
      expect(engine.spoken, ['first utterance']); // queued one was dropped
    });

    test('after stop(), the rest of the turn is muted until next beginTurn',
        () async {
      await narrator.beginTurn('en');
      await narrator.stop(); // e.g. keyboard typing
      narrator.narrateResponse('should not be spoken');
      await narrator.idle;
      expect(engine.spoken, isEmpty);

      await narrator.beginTurn('en'); // next voice turn re-enables narration
      narrator.narrateResponse('spoken again');
      await narrator.idle;
      expect(engine.spoken, ['spoken again']);
    });

    test('stop() when idle does not hit the platform engine', () async {
      await narrator.beginTurn('en');
      await narrator.stop();
      expect(engine.stopCalls, 0); // no channel spam on every keystroke
    });

    test('dispose() while a drain is hung completes the idle future', () async {
      await narrator.beginTurn('en');
      // Engine.speak() hangs and its stop() does NOT release the gate, so the
      // in-flight _drain() can never reach its finally block on its own.
      engine.stopUnblocksSpeak = false;
      engine.speakGate = Completer<void>();
      narrator.narrateResponse('hung utterance');

      // Let the drain start and block on speak().
      await Future<void>.delayed(Duration.zero);
      final idleFuture = narrator.idle;

      narrator.dispose();

      // Must not hang: dispose completes the pending idle waiter.
      await idleFuture.timeout(
        const Duration(seconds: 1),
        onTimeout: () => fail('dispose() did not complete idle — deadlock'),
      );
      expect(engine.stopCalls, greaterThanOrEqualTo(1));
    });

    test('speaking state is emitted while draining and cleared after',
        () async {
      await narrator.beginTurn('en');
      final states = <bool>[];
      final sub = narrator.states.listen((s) => states.add(s.isSpeaking));

      narrator.narrateResponse('hello');
      await narrator.idle;
      // Let the broadcast stream deliver.
      await Future<void>.delayed(Duration.zero);

      expect(states, containsAllInOrder([true, false]));
      expect(narrator.state.isSpeaking, isFalse);
      await sub.cancel();
    });
  });
}
