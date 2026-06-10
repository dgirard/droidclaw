import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/agent/agent_loop.dart';
import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/agent/context_builder.dart';
import 'package:droidclaw/core/agent/memory_manager.dart';
import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/knowledge/services/knowledge_service.dart';
import 'package:droidclaw/core/providers/http_provider.dart' show LLMException;
import 'package:droidclaw/core/providers/llm_provider.dart';
import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/core/skills/skill_loader.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/shared/constants.dart';

import 'support/fake_embedding_provider.dart';
import 'support/fake_llm_provider.dart';
import 'support/hive_test_harness.dart';
import 'support/in_memory_kg.dart';

class _EchoTool extends Tool {
  @override
  String get name => 'echo';
  @override
  String get description => 'Echo a message back.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'msg': {'type': 'string'},
        },
      };
  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async =>
      ToolResult.simple('echoed: ${arguments['msg'] ?? ''}');
}

/// Throws on the [throwOnCall]-th chat call (1-based), delegating every other
/// call to [inner] — simulates the KG expansion LLM call failing while the
/// main chat call still works (the doubly-degraded retrieval path).
class _ThrowOnCallProvider implements LLMProvider {
  _ThrowOnCallProvider(this.inner, {required this.throwOnCall});

  final FakeLLMProvider inner;
  final int throwOnCall;
  int _calls = 0;

  @override
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  }) {
    _calls++;
    if (_calls == throwOnCall) {
      throw LLMException('expansion boom');
    }
    return inner.chat(
        messages: messages, tools: tools, model: model, options: options);
  }

  @override
  String get defaultModel => inner.defaultModel;
  @override
  String get providerName => inner.providerName;
}

class _ThrowingProvider implements LLMProvider {
  @override
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  }) async =>
      throw LLMException('boom');
  @override
  String get defaultModel => 'm';
  @override
  String get providerName => 'throwing';
}

void main() {
  late HiveTestHarness hive;
  late Directory workspace;
  late SessionManager sessions;

  Future<AgentLoop> buildLoop(LLMProvider provider,
      {KnowledgeService? knowledgeService}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage =
        StorageService(prefs: prefs, overrideWorkspacePath: workspace.path);
    final registry = ToolRegistry()..register(_EchoTool());
    final contextBuilder = ContextBuilder(
      memoryManager: MemoryManager(storage),
      skillLoader: SkillLoader(storage),
      toolRegistry: registry,
      workspacePath: workspace.path,
    );
    return AgentLoop(
      provider: provider,
      config: AppConfig.defaults(),
      sessions: sessions,
      tools: registry,
      contextBuilder: contextBuilder,
      knowledgeService: knowledgeService,
    );
  }

  setUp(() async {
    hive = await HiveTestHarness.create();
    workspace = await Directory.systemTemp.createTemp('agent_ws_');
    sessions = SessionManager();
    await sessions.init();
  });

  tearDown(() async {
    if (await workspace.exists()) await workspace.delete(recursive: true);
    await hive.dispose();
  });

  test('happy path: tool call, tool result, then final response', () async {
    final provider = FakeLLMProvider([
      toolCallResponse('echo', {'msg': 'hi'}),
      textResponse('done'),
    ]);
    final loop = await buildLoop(provider);

    final events =
        await loop.processMessage('hello', 'test-session').toList();

    final toolCall = events.whereType<ToolCallEvent>().single;
    expect(toolCall.name, 'echo');

    final toolResult = events.whereType<ToolResultEvent>().single;
    expect(toolResult.name, 'echo');
    expect(toolResult.result.forLLM, contains('echoed: hi'));

    expect(events.whereType<ResponseEvent>().single.content, 'done');
    expect(provider.callCount, 2);
  });

  test('error path: a provider failure yields an ErrorEvent', () async {
    final loop = await buildLoop(_ThrowingProvider());

    final events =
        await loop.processMessage('hello', 'err-session').toList();

    expect(events.whereType<ErrorEvent>(), isNotEmpty);
    expect(events.whereType<ResponseEvent>(), isEmpty);
  });

  group('flush cadence (U13)', () {
    // Policy assertion via the instrumented SessionManager.flushCount — a
    // true SIGKILL cannot be simulated in-process (see
    // test/session/lazy_load_and_flush_policy_test.dart for the caveat).
    test(
        'mid-turn tool-batch saves do not fsync; only the final response '
        'save does', () async {
      final provider = FakeLLMProvider([
        toolCallResponse('echo', {'msg': 'a'}),
        toolCallResponse('echo', {'msg': 'b'}, id: 'call_2'),
        textResponse('done'),
      ]);
      final loop = await buildLoop(provider);
      final baseline = sessions.flushCount;

      await loop.processMessage('hello', 'cadence-session').toList();

      expect(sessions.flushCount, baseline + 1,
          reason: 'two tool batches save without fsync; the turn-ending '
              'final-response save fsyncs exactly once');
      // The mid-turn writes still happened: tool results are persisted.
      final session = sessions.get('cadence-session')!;
      expect(session.messages.where((m) => m.role == 'tool'), hasLength(2));
    });

    test('an LLM error still ends the turn with a flushed save', () async {
      final loop = await buildLoop(_ThrowingProvider());
      final baseline = sessions.flushCount;

      await loop.processMessage('hello', 'err-flush-session').toList();

      expect(sessions.flushCount, baseline + 1,
          reason: 'the user message just added must be durable when the '
              'turn aborts');
    });
  });

  group('KG pre-query LLM cost (U12)', () {
    test(
        'with KG enabled and an embedder, a simple turn makes exactly ONE '
        'chat call — no pre-turn LLM query expansion', () async {
      final kgDb = inMemoryKnowledgeGraphDB();
      addTearDown(kgDb.close);
      final knowledgeService = KnowledgeService(
        db: kgDb,
        embeddingProvider: FakeEmbeddingProvider(const {}),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      final provider = FakeLLMProvider([textResponse('hello back')]);
      final loop =
          await buildLoop(provider, knowledgeService: knowledgeService);

      final events =
          await loop.processMessage('hello', 'kg-session').toList();

      expect(events.whereType<ResponseEvent>().single.content, 'hello back');
      expect(provider.callCount, 1,
          reason: 'the unconditional pre-turn expansion call must be gone');
      // The semantic-gap bridge moved into queryRelevant's vector path.
      expect(
        (knowledgeService.embeddingProvider as FakeEmbeddingProvider)
            .embedCallCount,
        1,
      );
    });

    test(
        'embedder configured but embed() fails at query time: the turn '
        'retries the pre-query WITH LLM keyword expansion (degraded mode) '
        'instead of silently using the raw query', () async {
      final kgDb = inMemoryKnowledgeGraphDB();
      addTearDown(kgDb.close);
      final embedder = FakeEmbeddingProvider(const {}, throwOnEmbed: true);
      final knowledgeService = KnowledgeService(
        db: kgDb,
        embeddingProvider: embedder,
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      final provider = FakeLLMProvider([
        textResponse('keyword keywords'), // degraded-retry expansion call
        textResponse('hello back'), // main chat call
      ]);
      final loop =
          await buildLoop(provider, knowledgeService: knowledgeService);

      final events =
          await loop.processMessage('hello', 'kg-embed-fail-session').toList();

      expect(events.whereType<ResponseEvent>().single.content, 'hello back');
      expect(embedder.embedCallCount, greaterThanOrEqualTo(1),
          reason: 'the vector path was attempted before degrading');
      expect(provider.callCount, 2,
          reason: 'exactly one expansion call plus the main chat call');
      expect(
        provider.receivedMessages.first.first.content,
        contains('keyword extractor'),
        reason: 'the degraded retry must go through query expansion, '
            'not the raw query (re-opens the semantic-gap bug otherwise)',
      );
    });

    test(
        'doubly degraded: embed() fails AND the expansion retry throws — '
        'the first query\'s LEXICAL results still reach the system prompt',
        () async {
      final kgDb = inMemoryKnowledgeGraphDB();
      addTearDown(kgDb.close);
      // Seed one entity the raw user message matches lexically (FTS).
      await kgDb.into(kgDb.entities).insert(EntitiesCompanion.insert(
            name: 'Didier Girard',
            entityType: const Value('PERSON'),
            summary: const Value('the user'),
          ));
      final knowledgeService = KnowledgeService(
        db: kgDb,
        embeddingProvider: FakeEmbeddingProvider(const {}, throwOnEmbed: true),
        embeddingModel: 'fake-model',
        embeddingDimensions: 4,
      );

      final inner = FakeLLMProvider([textResponse('hello back')]);
      // Call 1 is the degraded-retry expansion (throws); call 2 is the main
      // chat call (delegated to the scripted inner provider).
      final provider = _ThrowOnCallProvider(inner, throwOnCall: 1);
      final loop =
          await buildLoop(provider, knowledgeService: knowledgeService);

      final events = await loop
          .processMessage('tell me about Didier', 'kg-doubly-degraded')
          .toList();

      // The turn completes normally...
      expect(events.whereType<ResponseEvent>().single.content, 'hello back');
      expect(events.whereType<ErrorEvent>(), isEmpty);
      // ...and the KG context built from the FIRST (lexical) query survived
      // the failed retry: the main chat call's system prompt names the
      // entity instead of dropping the knowledge context entirely.
      final systemPrompt = inner.receivedMessages.single
          .firstWhere((m) => m.role == 'system')
          .content;
      expect(systemPrompt, contains('Didier Girard'),
          reason: 'a failed retry must keep, not discard, the lexical '
              'results of the first queryRelevant call');
    });

    test(
        'without an embedder (degraded mode), the LLM keyword expansion '
        'remains the semantic-gap bridge', () async {
      final kgDb = inMemoryKnowledgeGraphDB();
      addTearDown(kgDb.close);
      final knowledgeService = KnowledgeService(db: kgDb);

      final provider = FakeLLMProvider([
        textResponse('keyword keywords'), // expansion call
        textResponse('hello back'), // main chat call
      ]);
      final loop =
          await buildLoop(provider, knowledgeService: knowledgeService);

      await loop.processMessage('hello', 'kg-degraded-session').toList();

      expect(provider.callCount, 2);
      expect(
        provider.receivedMessages.first.first.content,
        contains('keyword extractor'),
        reason: 'the first call must be the query-expansion prompt',
      );
    });
  });

  test(
      'summarization fallback with a short first user message does not '
      'throw a RangeError', () async {
    // _ThrowingProvider fails the summarize call, forcing the fallback
    // summary built from the first user message — which is shorter than
    // the 100-char preview window.
    final loop = await buildLoop(_ThrowingProvider());
    final session = sessions.getOrCreate('summarize-fallback-session');
    for (var i = 0; i < AppConstants.summarizationMessageCount; i++) {
      session.addMessage(Message(
        role: i.isEven ? 'user' : 'assistant',
        content: i == 0 ? 'hi' : 'message $i',
      ));
    }
    await sessions.save(session);

    final events = await loop
        .processMessage('hello', 'summarize-fallback-session')
        .toList();

    expect(events.whereType<SummarizingEvent>(), isNotEmpty);
    expect(session.summary, contains('about: hi...'));
    // The main chat call also throws; the turn must end with an ErrorEvent,
    // not an uncaught RangeError from the fallback substring.
    expect(events.whereType<ErrorEvent>(), isNotEmpty);
  });

  test('the tool result is persisted to the session', () async {
    final provider = FakeLLMProvider([
      toolCallResponse('echo', {'msg': 'persist-me'}),
      textResponse('ok'),
    ]);
    final loop = await buildLoop(provider);

    await loop.processMessage('hello', 'persist-session').toList();

    final session = sessions.getOrCreate('persist-session');
    expect(
      session.messages.any(
          (m) => m.role == 'tool' && m.content.contains('persist-me')),
      isTrue,
    );
  });
}
