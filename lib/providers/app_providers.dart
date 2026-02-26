import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path/path.dart' as p;

import '../core/agent/agent_loop.dart';
import '../core/agent/context_builder.dart';
import '../core/agent/memory_manager.dart';
import '../core/config/app_config.dart';
import '../core/config/config_storage.dart';
import '../core/knowledge/database/knowledge_graph_db.dart';
import '../core/knowledge/services/entity_extractor.dart';
import '../core/knowledge/services/entity_resolver.dart';
import '../core/knowledge/services/ingestion_pipeline.dart';
import '../core/knowledge/services/knowledge_service.dart';
import '../core/providers/embedding_provider.dart';
import '../core/providers/embedding_provider_factory.dart';
import '../core/providers/llm_provider.dart';
import '../core/providers/provider_factory.dart';
import '../core/session/session_manager.dart';
import '../core/tools/knowledge_search_tool.dart';
import '../core/tools/knowledge_store_tool.dart';
import '../shared/constants.dart';
import '../core/skills/skill_installer.dart';
import '../core/skills/skill_loader.dart';
import '../core/tools/calendar_tool.dart';
import '../core/tools/clipboard_tool.dart';
import '../core/tools/datetime_tool.dart';
import '../core/tools/contacts_tool.dart';
import '../core/tools/device_info_tool.dart';
import '../core/tools/directions_tool.dart';
import '../core/tools/geocode_tool.dart';
import '../core/tools/file_tool.dart';
import '../core/tools/location_tool.dart';
import '../core/tools/message_tool.dart';
import '../core/tools/notifications_tool.dart';
import '../core/tools/ocr_tool.dart';
import '../core/tools/open_app_tool.dart';
import '../core/tools/pick_image_tool.dart';
import '../core/tools/qr_generate_tool.dart';
import '../core/tools/reverse_geocode_tool.dart';
import '../core/tools/set_alarm_tool.dart';
import '../core/tools/speak_tool.dart';
import '../core/tools/subagent_tool.dart';
import '../core/tools/transit_tool.dart';
import '../core/tools/radio_tool.dart';
import '../core/tools/volume_control_tool.dart';
import '../core/tools/weather_tool.dart';
import '../core/tools/tool.dart';
import '../core/tools/web_scrape_js_tool.dart';
import '../core/tools/web_scrape_tool.dart';
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

/// Knowledge Graph database — null when KG is disabled in config.
final knowledgeGraphDbProvider =
    FutureProvider<KnowledgeGraphDB?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!config.knowledge.enabled) return null;

  final storage = ref.watch(storageServiceProvider);
  final workspacePath = await storage.workspacePath;
  final dbPath = p.join(workspacePath, AppConstants.knowledgeDbFilename);
  final db = KnowledgeGraphDB(dbPath);

  ref.onDispose(() => db.close());

  return db;
});

/// Knowledge Service — null when KG is disabled.
final knowledgeServiceProvider =
    FutureProvider<KnowledgeService?>((ref) async {
  final db = await ref.watch(knowledgeGraphDbProvider.future);
  if (db == null) return null;
  return KnowledgeService(db: db);
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
  final orsApiKey = await configStorage.getOrsApiKey();
  final sncfApiKey = await configStorage.getSncfApiKey();
  final primApiKey = await configStorage.getPrimApiKey();
  final locale = config.resolvedLocale;
  final registry = ToolRegistry();
  final disabled = config.tools.disabledTools;

  if (!disabled.contains('web_search')) {
    registry.register(WebSearchTool(
      braveApiKey: braveApiKey,
      maxResults: config.tools.webSearchMaxResults,
    ));
  }
  if (!disabled.contains('web_scrape')) {
    registry.register(WebScrapeTool());
  }
  if (!disabled.contains('web_scrape_js')) {
    registry.register(WebScrapeJsTool());
  }
  if (!disabled.contains('file')) {
    registry.register(FileTool(workspacePath: workspacePath));
  }
  // MessageTool is always registered (internal UI mechanism).
  registry.register(MessageTool());
  if (!disabled.contains('get_location')) {
    registry.register(LocationTool());
  }
  if (!disabled.contains('get_address')) {
    registry.register(ReverseGeocodeTool());
  }
  if (!disabled.contains('subagent')) {
    registry.register(SubagentTool());
  }
  if (!disabled.contains('clipboard')) {
    registry.register(ClipboardTool());
  }
  if (!disabled.contains('get_datetime')) {
    registry.register(DateTimeTool(locale: locale));
  }
  if (!disabled.contains('device_info')) {
    registry.register(DeviceInfoTool(locale: locale));
  }
  if (!disabled.contains('speak')) {
    registry.register(SpeakTool());
  }
  if (!disabled.contains('open_app')) {
    registry.register(OpenAppTool());
  }
  if (!disabled.contains('set_alarm')) {
    registry.register(SetAlarmTool());
  }
  if (!disabled.contains('notifications')) {
    registry.register(NotificationsTool());
  }
  if (!disabled.contains('contacts')) {
    registry.register(ContactsTool());
  }
  if (!disabled.contains('calendar')) {
    registry.register(CalendarTool());
  }
  if (!disabled.contains('ocr')) {
    registry.register(OcrTool(workspacePath: workspacePath));
  }
  if (!disabled.contains('qr_generate')) {
    registry.register(QrGenerateTool(workspacePath: workspacePath));
  }
  if (!disabled.contains('pick_image')) {
    registry.register(PickImageTool(workspacePath: workspacePath));
  }
  if (!disabled.contains('volume_control')) {
    registry.register(VolumeControlTool());
  }
  if (!disabled.contains('get_directions')) {
    registry.register(DirectionsTool(apiKey: orsApiKey));
  }
  if (!disabled.contains('geocode')) {
    registry.register(GeocodeTool());
  }
  if (!disabled.contains('get_transit')) {
    registry.register(TransitTool(sncfApiKey: sncfApiKey, primApiKey: primApiKey, locale: locale));
  }
  if (!disabled.contains('weather')) {
    registry.register(WeatherTool(locale: locale));
  }
  if (!disabled.contains('radio')) {
    registry.register(RadioTool());
  }

  // Knowledge Graph tools (require KG to be enabled)
  final kgDb = await ref.watch(knowledgeGraphDbProvider.future);
  final kgService = await ref.watch(knowledgeServiceProvider.future);
  if (kgDb != null && kgService != null) {
    if (!disabled.contains('knowledge_search')) {
      registry.register(KnowledgeSearchTool(knowledgeService: kgService));
    }
    if (!disabled.contains('knowledge_store')) {
      final resolver = EntityResolver(kgDb);
      registry.register(KnowledgeStoreTool(db: kgDb, resolver: resolver));
    }
  }

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

/// Embedding provider — created from embedding config + API key.
/// Returns null when no embedding provider is configured.
final embeddingProviderProvider =
    FutureProvider<EmbeddingProvider?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (config.embedding.provider.isEmpty) return null;

  final configStorage = ref.read(configStorageProvider);
  final String? apiKey;
  if (config.embedding.useOwnApiKey) {
    apiKey = await configStorage.getEmbeddingApiKey();
  } else {
    apiKey = await configStorage.getApiKey(config.agent.provider);
  }
  if (apiKey == null || apiKey.isEmpty) return null;

  final provider = EmbeddingProviderFactory.create(
    providerName: config.embedding.provider,
    apiKey: apiKey,
    apiBase: config.embedding.apiBase.isNotEmpty
        ? config.embedding.apiBase
        : null,
    dimensions: config.embedding.dimensions,
  );

  ref.onDispose(() => provider.dispose());

  return provider;
});

/// Context builder.
final contextBuilderProvider = FutureProvider<ContextBuilder>((ref) async {
  final config = ref.watch(appConfigProvider);
  final storage = ref.watch(storageServiceProvider);
  final workspacePath = await storage.workspacePath;
  final toolRegistry = await ref.watch(toolRegistryProvider.future);

  return ContextBuilder(
    memoryManager: ref.watch(memoryManagerProvider),
    skillLoader: ref.watch(skillLoaderProvider),
    toolRegistry: toolRegistry,
    workspacePath: workspacePath,
    locale: config.resolvedLocale,
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

  // Wire Knowledge Graph (optional)
  final kgService2 = await ref.watch(knowledgeServiceProvider.future);
  final kgDb2 = await ref.watch(knowledgeGraphDbProvider.future);
  IngestionPipeline? ingestionPipeline;
  if (kgService2 != null && kgDb2 != null && config.knowledge.autoExtract) {
    ingestionPipeline = IngestionPipeline(
      extractor: EntityExtractor(provider: provider, model: config.agent.model),
      resolver: EntityResolver(kgDb2),
      db: kgDb2,
    );
  }

  final agentLoop = AgentLoop(
    provider: provider,
    config: config,
    sessions: sessions,
    tools: tools,
    contextBuilder: contextBuilder,
    knowledgeService: kgService2,
    ingestionPipeline: ingestionPipeline,
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
