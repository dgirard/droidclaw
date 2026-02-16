import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/agent/agent_loop.dart';
import '../core/agent/context_builder.dart';
import '../core/agent/memory_manager.dart';
import '../core/config/app_config.dart';
import '../core/config/config_storage.dart';
import '../core/providers/llm_provider.dart';
import '../core/providers/provider_factory.dart';
import '../core/session/session_manager.dart';
import '../core/skills/skill_installer.dart';
import '../core/skills/skill_loader.dart';
import '../core/tools/file_tool.dart';
import '../core/tools/message_tool.dart';
import '../core/tools/subagent_tool.dart';
import '../core/tools/tool.dart';
import '../core/tools/web_fetch_tool.dart';
import '../core/tools/web_search_tool.dart';
import '../data/local/storage_service.dart';

/// SharedPreferences instance — must be overridden at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// Core storage service.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(prefs: ref.watch(sharedPreferencesProvider));
});

/// Config storage (load/save config + API keys).
final configStorageProvider = Provider<ConfigStorage>((ref) {
  return ConfigStorage(ref.watch(storageServiceProvider));
});

/// App configuration — reactive, can be updated.
final appConfigProvider =
    NotifierProvider<AppConfigNotifier, AppConfig>(AppConfigNotifier.new);

class AppConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() => ref.read(configStorageProvider).load();

  void update(AppConfig config) => state = config;
}

/// Session manager — initialized asynchronously (opens Hive box).
final sessionManagerProvider = FutureProvider<SessionManager>((ref) async {
  final manager = SessionManager();
  await manager.init();
  return manager;
});

/// Memory manager.
final memoryManagerProvider = Provider<MemoryManager>((ref) {
  return MemoryManager(ref.watch(storageServiceProvider));
});

/// Skill loader.
final skillLoaderProvider = Provider<SkillLoader>((ref) {
  return SkillLoader(ref.watch(storageServiceProvider));
});

/// Skill installer.
final skillInstallerProvider = Provider<SkillInstaller>((ref) {
  return SkillInstaller(
    ref.watch(storageServiceProvider),
    ref.watch(skillLoaderProvider),
  );
});

/// Tool registry with all tools registered.
final toolRegistryProvider = FutureProvider<ToolRegistry>((ref) async {
  final config = ref.watch(appConfigProvider);
  final configStorage = ref.watch(configStorageProvider);
  final storage = ref.watch(storageServiceProvider);
  final workspacePath = await storage.workspacePath;
  final braveApiKey = await configStorage.getBraveApiKey();
  final registry = ToolRegistry();

  registry.register(WebSearchTool(
    braveApiKey: braveApiKey,
    maxResults: config.tools.webSearchMaxResults,
  ));
  registry.register(WebFetchTool());
  registry.register(FileTool(workspacePath: workspacePath));
  registry.register(MessageTool());
  registry.register(SubagentTool());

  return registry;
});

/// LLM provider — created from config + secure API key.
final llmProviderProvider = FutureProvider<LLMProvider?>((ref) async {
  final config = ref.watch(appConfigProvider);
  final configStorage = ref.read(configStorageProvider);

  final providerName = config.agent.provider;
  final providerConfig = config.providers[providerName];
  if (providerConfig == null) return null;

  final apiKey = await configStorage.getApiKey(providerName);
  if (apiKey == null || apiKey.isEmpty) return null;

  return ProviderFactory.create(
    name: providerName,
    config: providerConfig,
    apiKey: apiKey,
    defaultModel: config.agent.model,
  );
});

/// Context builder.
final contextBuilderProvider = FutureProvider<ContextBuilder>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  final workspacePath = await storage.workspacePath;
  final toolRegistry = await ref.watch(toolRegistryProvider.future);

  return ContextBuilder(
    memoryManager: ref.watch(memoryManagerProvider),
    skillLoader: ref.watch(skillLoaderProvider),
    toolRegistry: toolRegistry,
    workspacePath: workspacePath,
  );
});

/// Agent loop — the main agent, depends on LLM provider.
final agentLoopProvider = FutureProvider<AgentLoop?>((ref) async {
  final provider = await ref.watch(llmProviderProvider.future);
  if (provider == null) return null;

  final config = ref.watch(appConfigProvider);
  final sessions = await ref.watch(sessionManagerProvider.future);
  final tools = await ref.watch(toolRegistryProvider.future);
  final contextBuilder = await ref.watch(contextBuilderProvider.future);

  final agentLoop = AgentLoop(
    provider: provider,
    config: config,
    sessions: sessions,
    tools: tools,
    contextBuilder: contextBuilder,
  );

  // Wire SubagentTool executor: creates a fresh session, processes the task,
  // and returns the final response content.
  final subagentTool = tools.get('subagent');
  if (subagentTool is SubagentTool) {
    subagentTool.executor = (task) async {
      final subSession = sessions.createNew();
      String result = '';
      await for (final event
          in agentLoop.processMessage(task, subSession.key)) {
        if (event is ResponseEvent) {
          result = event.content;
        } else if (event is ErrorEvent) {
          result = 'Subagent error: ${event.message}';
        }
      }
      // Clean up subagent session
      await sessions.deleteSession(subSession.key);
      return result;
    };
  }

  return agentLoop;
});
