// U4: episodic interception in the AgentLoop — cacheable read-only tool
// calls are served from a fresh episode BEFORE execution; successful
// executions are recorded after; force_fresh bypasses; side-effecting tools
// are untouched; summarization routes the compressed-away conversation to
// the ingestion pipeline.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/agent/agent_loop.dart';
import 'package:droidclaw/core/agent/context_builder.dart';
import 'package:droidclaw/core/agent/memory_manager.dart';
import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/knowledge/database/knowledge_graph_db.dart';
import 'package:droidclaw/core/knowledge/services/entity_extractor.dart';
import 'package:droidclaw/core/knowledge/services/entity_resolver.dart';
import 'package:droidclaw/core/knowledge/services/episode_store.dart';
import 'package:droidclaw/core/knowledge/services/ingestion_pipeline.dart';
import 'package:droidclaw/core/providers/llm_provider.dart';
import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/core/skills/skill_loader.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/fake_llm_provider.dart';
import '../support/hive_test_harness.dart';
import '../support/in_memory_kg.dart';

/// A counting fake tool: records every execution and its arguments.
class _CountingTool extends Tool {
  _CountingTool(this.name, {this.response = 'tool output'});

  @override
  final String name;
  final String response;

  int callCount = 0;
  final List<Map<String, dynamic>> receivedArgs = [];

  @override
  String get description => 'fake $name';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    callCount++;
    receivedArgs.add(Map.of(arguments));
    return ToolResult.simple(response);
  }
}

/// Captures extractAndStore calls instead of running real extraction.
class _CapturingPipeline extends IngestionPipeline {
  _CapturingPipeline(KnowledgeGraphDB db)
      : super(
          extractor: EntityExtractor(
              provider: FakeLLMProvider.text('unused'), model: 'm'),
          resolver: EntityResolver(db),
          db: db,
        );

  final calls =
      <({String userMessage, String assistantResponse, String? sessionKey})>[];
  final completer = Completer<void>();

  @override
  Future<int> extractAndStore({
    required String userMessage,
    required String assistantResponse,
    String? sessionKey,
  }) async {
    calls.add((
      userMessage: userMessage,
      assistantResponse: assistantResponse,
      sessionKey: sessionKey,
    ));
    if (!completer.isCompleted) completer.complete();
    return 0;
  }
}

void main() {
  late HiveTestHarness hive;
  late Directory workspace;
  late SessionManager sessions;
  late KnowledgeGraphDB kgDb;
  late EpisodeStore store;

  setUp(() async {
    hive = await HiveTestHarness.create();
    workspace = await Directory.systemTemp.createTemp('episodic_ws_');
    sessions = SessionManager();
    await sessions.init();
    kgDb = inMemoryKnowledgeGraphDB();
    store = EpisodeStore(kgDb);
  });

  tearDown(() async {
    await kgDb.close();
    if (await workspace.exists()) await workspace.delete(recursive: true);
    await hive.dispose();
  });

  Future<AgentLoop> buildLoop(
    LLMProvider provider,
    List<Tool> tools, {
    IngestionPipeline? ingestionPipeline,
    EpisodeStore? episodeStore,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage =
        StorageService(prefs: prefs, overrideWorkspacePath: workspace.path);
    final registry = ToolRegistry();
    for (final t in tools) {
      registry.register(t);
    }
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
      ingestionPipeline: ingestionPipeline,
      episodeStore: episodeStore ?? store,
    );
  }

  Future<int> episodeCount() async {
    final row = await kgDb
        .customSelect('SELECT COUNT(*) AS cnt FROM episodes')
        .getSingle();
    return row.read<int>('cnt');
  }

  group('interception of cacheable tools', () {
    test('two identical weather calls → one real execution, the second is '
        'served from the cache with an age annotation', () async {
      store.setLocationContext(48.8566, 2.3522);
      final weather = _CountingTool('weather', response: 'sunny, 21°C');
      final provider = FakeLLMProvider([
        toolCallResponse('weather', {'city': 'Paris'}),
        textResponse('done 1'),
        toolCallResponse('weather', {'city': 'paris '}), // same canonical args
        textResponse('done 2'),
      ]);
      final loop = await buildLoop(provider, [weather]);

      await loop.processMessage('weather?', 'turn-1').toList();
      final secondTurn =
          await loop.processMessage('weather again?', 'turn-2').toList();

      expect(weather.callCount, 1,
          reason: 'the second call must be intercepted before execution');

      final cachedResult = secondTurn.whereType<ToolResultEvent>().single;
      expect(cachedResult.result.forLLM, contains('cached result from'));
      expect(cachedResult.result.forLLM, contains('force_fresh=true'));
      expect(cachedResult.result.forLLM, contains('sunny, 21°C'));
      expect(cachedResult.result.forUser, contains('(cached,'));

      // The cached annotation also reaches the session (what the LLM sees).
      final session = sessions.get('turn-2')!;
      final toolMsg =
          session.messages.firstWhere((m) => m.role == 'tool');
      expect(toolMsg.content, contains('cached result from'));
    });

    test('ToolResultEvent.arguments is populated (force_fresh stripped)',
        () async {
      store.setLocationContext(48.8566, 2.3522);
      final weather = _CountingTool('weather');
      final provider = FakeLLMProvider([
        toolCallResponse(
            'weather', {'city': 'Paris', 'force_fresh': true}),
        textResponse('done'),
      ]);
      final loop = await buildLoop(provider, [weather]);

      final events = await loop.processMessage('w?', 'args-evt').toList();

      final resultEvent = events.whereType<ToolResultEvent>().single;
      expect(resultEvent.arguments, {'city': 'Paris'});
    });

    test('force_fresh=true bypasses a fresh episode and never reaches the '
        'tool', () async {
      store.setLocationContext(48.8566, 2.3522);
      final weather = _CountingTool('weather');
      final provider = FakeLLMProvider([
        toolCallResponse('weather', {'city': 'paris'}),
        textResponse('done 1'),
        toolCallResponse(
            'weather', {'city': 'paris', 'force_fresh': true}),
        textResponse('done 2'),
      ]);
      final loop = await buildLoop(provider, [weather]);

      await loop.processMessage('w?', 'ff-1').toList();
      await loop.processMessage('w again, fresh', 'ff-2').toList();

      expect(weather.callCount, 2,
          reason: 'force_fresh must bypass the fresh episode');
      expect(weather.receivedArgs.last.containsKey('force_fresh'), isFalse,
          reason: 'the cache-control param must be stripped before execute');
    });

    test('cacheable tool schemas gain force_fresh; side-effecting tools do '
        'not', () async {
      final registry = ToolRegistry()
        ..register(_CountingTool('weather'))
        ..register(_CountingTool('set_alarm'));

      final weatherParams =
          (registry.get('weather')!.parameters['properties'] as Map);
      final alarmParams =
          (registry.get('set_alarm')!.parameters['properties'] as Map);
      expect(weatherParams.containsKey('force_fresh'), isTrue);
      expect(alarmParams.containsKey('force_fresh'), isFalse);
    });
  });

  group('geo context', () {
    test('geo-keyed tool with NO known location cell is never cached',
        () async {
      // No setLocationContext on the fresh store.
      final weather = _CountingTool('weather');
      final provider = FakeLLMProvider([
        toolCallResponse('weather', {'city': 'paris'}),
        textResponse('done 1'),
        toolCallResponse('weather', {'city': 'paris'}),
        textResponse('done 2'),
      ]);
      final loop = await buildLoop(provider, [weather]);

      await loop.processMessage('w?', 'nocell-1').toList();
      await loop.processMessage('w?', 'nocell-2').toList();

      expect(weather.callCount, 2);
      expect(await episodeCount(), 0);
    });

    test('a different location cell is a cache MISS (post-train-ride '
        'weather is fresh)', () async {
      store.setLocationContext(48.8566, 2.3522); // Paris
      final weather = _CountingTool('weather');
      final provider = FakeLLMProvider([
        toolCallResponse('weather', {}),
        textResponse('done 1'),
        toolCallResponse('weather', {}),
        textResponse('done 2'),
      ]);
      final loop = await buildLoop(provider, [weather]);

      await loop.processMessage('w?', 'cell-1').toList();
      store.setLocationContext(45.7640, 4.8357); // Lyon
      await loop.processMessage('w?', 'cell-2').toList();

      expect(weather.callCount, 2);
    });

    test('a get_location result passing through the loop updates the cell',
        () async {
      final location = _CountingTool('get_location',
          response: 'Current device location: latitude=48.856600, '
              'longitude=2.352200, accuracy=10m');
      final provider = FakeLLMProvider([
        toolCallResponse('get_location', {}),
        textResponse('done'),
      ]);
      final loop = await buildLoop(provider, [location]);

      expect(store.locationCell, isNull);
      await loop.processMessage('where am I?', 'loc-1').toList();

      expect(store.locationCell, '48.86,2.35');
    });
  });

  group('side-effecting tools', () {
    test('set_alarm is never intercepted and never recorded', () async {
      final alarm = _CountingTool('set_alarm', response: 'alarm set');
      final provider = FakeLLMProvider([
        toolCallResponse('set_alarm', {'hour': 7}),
        textResponse('done 1'),
        toolCallResponse('set_alarm', {'hour': 7}),
        textResponse('done 2'),
      ]);
      final loop = await buildLoop(provider, [alarm]);

      await loop.processMessage('alarm', 'alarm-1').toList();
      await loop.processMessage('alarm', 'alarm-2').toList();

      expect(alarm.callCount, 2,
          reason: 'side-effecting tools must execute every time');
      expect(await episodeCount(), 0);
    });
  });

  group('summarization → ingestion', () {
    test('the compressed-away conversation is routed to '
        'IngestionPipeline.extractAndStore (role-prefixed, capped)',
        () async {
      final pipeline = _CapturingPipeline(kgDb);
      final provider = FakeLLMProvider([
        textResponse('a concise summary'), // summarize call
        textResponse('final answer'), // main chat call
      ]);
      final loop = await buildLoop(provider, [],
          ingestionPipeline: pipeline);

      final session = sessions.getOrCreate('summarize-ingest');
      for (var i = 0; i < AppConstants.summarizationMessageCount; i++) {
        session.addMessage(Message(
          role: i.isEven ? 'user' : 'assistant',
          content: 'message number $i about raclette',
        ));
      }
      await sessions.save(session);

      final events =
          await loop.processMessage('hello', 'summarize-ingest').toList();
      expect(events.whereType<SummarizingEvent>(), isNotEmpty);

      // Fire-and-forget: wait for the captured call.
      await pipeline.completer.future
          .timeout(const Duration(seconds: 5));

      final call = pipeline.calls.single;
      expect(call.userMessage, contains('user: message number 0'));
      expect(call.userMessage, contains('assistant: message number 1'));
      expect(call.userMessage.length,
          lessThanOrEqualTo(AppConstants.episodeSummarizationIngestMaxChars));
      expect(call.assistantResponse, 'a concise summary');
      expect(call.sessionKey, 'summarize-ingest');
    });

    test('without an ingestion pipeline, summarization still works',
        () async {
      final provider = FakeLLMProvider([
        textResponse('a summary'),
        textResponse('final'),
      ]);
      final loop = await buildLoop(provider, []);

      final session = sessions.getOrCreate('summarize-noingest');
      for (var i = 0; i < AppConstants.summarizationMessageCount; i++) {
        session.addMessage(Message(
          role: i.isEven ? 'user' : 'assistant',
          content: 'message $i',
        ));
      }
      await sessions.save(session);

      final events =
          await loop.processMessage('hello', 'summarize-noingest').toList();

      expect(events.whereType<SummarizingEvent>(), isNotEmpty);
      expect(events.whereType<ResponseEvent>().single.content, 'final');
    });
  });
}
