import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/agent/agent_loop.dart';
import 'package:droidclaw/core/agent/context_builder.dart';
import 'package:droidclaw/core/agent/memory_manager.dart';
import 'package:droidclaw/core/config/app_config.dart';
import 'package:droidclaw/core/providers/http_provider.dart' show LLMException;
import 'package:droidclaw/core/providers/llm_provider.dart';
import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/core/skills/skill_loader.dart';
import 'package:droidclaw/core/tools/tool.dart';
import 'package:droidclaw/data/local/storage_service.dart';

import 'support/fake_llm_provider.dart';
import 'support/hive_test_harness.dart';

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

  Future<AgentLoop> buildLoop(LLMProvider provider) async {
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
