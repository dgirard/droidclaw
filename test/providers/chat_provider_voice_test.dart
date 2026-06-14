import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/agent/agent_loop.dart';
import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/services/voice_narrator.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/providers/app_providers.dart';
import 'package:droidclaw/providers/chat_provider.dart';

import '../services/voice_narrator_test.dart' show FakeTtsEngine;

/// Fake agent loop yielding a scripted event stream — only [processMessage]
/// is exercised by [ChatNotifier.sendMessage].
class FakeAgentLoop implements AgentLoop {
  final Stream<AgentEvent> _events;

  FakeAgentLoop(List<AgentEvent> events)
      : _events = Stream.fromIterable(events);

  FakeAgentLoop.fromStream(this._events);

  @override
  Stream<AgentEvent> processMessage(String userMessage, String sessionKey) =>
      _events;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class FakeAppConfigNotifier extends AppConfigNotifier {
  @override
  AppConfig build() => AppConfig(agent: AgentConfig.defaults(), locale: 'en');
}

void main() {
  late FakeTtsEngine engine;

  setUp(() {
    engine = FakeTtsEngine();
  });

  ProviderContainer makeContainer(AgentLoop loop) {
    final container = ProviderContainer(overrides: [
      agentLoopProvider.overrideWith((ref) => Future.value(loop)),
      appConfigProvider.overrideWith(FakeAppConfigNotifier.new),
      voiceNarratorProvider.overrideWith(
        (ref) => VoiceNarrator(engine: engine),
      ),
    ]);
    addTearDown(container.dispose);
    // Keep chatProvider alive for the duration of the test.
    container.listen(chatProvider, (_, _) {});
    return container;
  }

  test('voice turn narrates the final response (locale en -> en-US)',
      () async {
    final container = makeContainer(FakeAgentLoop([
      const ResponseEvent(content: 'Hello **world**'),
    ]));

    await container
        .read(chatProvider.notifier)
        .sendMessage('hi', modality: ChatTurnModality.voice);
    await container.read(voiceNarratorProvider).idle;

    expect(engine.languagesSet, ['en-US']);
    expect(engine.spoken, ['Hello world']);
  });

  test('typed turn never touches TTS (default modality)', () async {
    final container = makeContainer(FakeAgentLoop([
      const ResponseEvent(content: 'Hello'),
    ]));

    await container.read(chatProvider.notifier).sendMessage('hi');
    await container.read(voiceNarratorProvider).idle;

    expect(engine.initCalled, isFalse);
    expect(engine.spoken, isEmpty);
    // The response still reached the chat UI.
    final messages = container.read(chatProvider).messages;
    expect(messages.last.content, 'Hello');
  });

  test('voice turn narrates non-silent forUser, skips silent results',
      () async {
    final container = makeContainer(FakeAgentLoop([
      const ToolCallEvent(name: 'weather', arguments: {}),
      ToolResultEvent(
        name: 'weather',
        result: ToolResult.dual(
          forLLM: 'STRUCTURED-LLM-DATA',
          forUser: 'Sunny, 20 degrees',
        ),
      ),
      ToolResultEvent(
        name: 'knowledge_store',
        result: ToolResult.silent('stored 3 entities'),
      ),
      const ResponseEvent(content: 'Nice day!'),
    ]));

    await container
        .read(chatProvider.notifier)
        .sendMessage('weather?', modality: ChatTurnModality.voice);
    await container.read(voiceNarratorProvider).idle;

    expect(engine.spoken, ['Sunny, 20 degrees', 'Nice day!']);
  });

  test(
      'speak-tool dedup: a speak ToolCallEvent this turn suppresses '
      'ResponseEvent narration and its own result', () async {
    final container = makeContainer(FakeAgentLoop([
      const ToolCallEvent(name: 'speak', arguments: {'text': 'Bonjour'}),
      ToolResultEvent(
        name: 'speak',
        result: ToolResult.dual(
          forLLM: 'Text is being spoken aloud (7 chars).',
          forUser: 'Speaking (7 chars)...',
        ),
      ),
      const ResponseEvent(content: 'I said it out loud.'),
    ]));

    await container
        .read(chatProvider.notifier)
        .sendMessage('say hi', modality: ChatTurnModality.voice);
    await container.read(voiceNarratorProvider).idle;

    expect(engine.spoken, isEmpty); // single narration came from the tool
  });

  test('ErrorEvent is narrated briefly on a voice turn', () async {
    final container = makeContainer(FakeAgentLoop([
      const ErrorEvent('Provider exploded'),
    ]));

    await container
        .read(chatProvider.notifier)
        .sendMessage('hi', modality: ChatTurnModality.voice);
    await container.read(voiceNarratorProvider).idle;

    expect(engine.spoken, ['Provider exploded']);
  });

  test('errors are NOT narrated on a typed turn', () async {
    final container = makeContainer(FakeAgentLoop([
      const ErrorEvent('Provider exploded'),
    ]));

    await container.read(chatProvider.notifier).sendMessage('hi');
    await container.read(voiceNarratorProvider).idle;

    expect(engine.spoken, isEmpty);
  });

  test('typing mid-turn (narrator.stop) mutes the rest of the voice turn',
      () async {
    final controller = StreamController<AgentEvent>();
    final container = makeContainer(FakeAgentLoop.fromStream(controller.stream));
    final narrator = container.read(voiceNarratorProvider);

    final turn = container
        .read(chatProvider.notifier)
        .sendMessage('hi', modality: ChatTurnModality.voice);

    controller.add(ToolResultEvent(
      name: 'weather',
      result: ToolResult.simple('Sunny'),
    ));
    await Future<void>.delayed(Duration.zero);
    await narrator.idle;
    expect(engine.spoken, ['Sunny']);

    // First keystroke: input_bar's onUserTyped calls narrator.stop().
    await narrator.stop();

    controller.add(const ResponseEvent(content: 'should stay unspoken'));
    await controller.close();
    await turn;
    await narrator.idle;

    expect(engine.spoken, ['Sunny']); // response was muted
    // The text response still reached the chat UI.
    expect(container.read(chatProvider).messages.last.content,
        'should stay unspoken');
  });
}
