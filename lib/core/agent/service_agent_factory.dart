import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/storage_service.dart';
import '../../shared/constants.dart';
import '../config/app_config.dart';
import '../config/log_entry.dart';
import '../services/app_logger.dart';
import '../services/model_download_manager.dart';
import '../knowledge/database/knowledge_graph_db.dart';
import '../knowledge/services/entity_extractor.dart';
import '../knowledge/services/entity_resolver.dart';
import '../knowledge/services/episode_store.dart';
import '../knowledge/services/ingestion_pipeline.dart';
import '../knowledge/services/knowledge_service.dart';
import '../providers/embedding_provider.dart';
import '../providers/embedding_provider_factory.dart';
import '../providers/provider_factory.dart';
import '../session/database/sessions_db_path.dart';
import '../session/session_manager.dart';
import '../skills/skill_loader.dart';
import '../tools/datetime_tool.dart';
import '../tools/device_info_tool.dart';
import '../tools/directions_tool.dart';
import '../tools/geocode_tool.dart';
import '../tools/file_tool.dart';
import '../tools/knowledge_query_tool.dart';
import '../tools/knowledge_search_tool.dart';
import '../tools/knowledge_store_tool.dart';
import '../tools/location_tool.dart';
import '../tools/ocr_tool.dart';
import '../tools/qr_generate_tool.dart';
import '../tools/reverse_geocode_tool.dart';
import '../tools/tool.dart';
import '../tools/transit_tool.dart';
import '../tools/proof_editor/proof_document_store.dart';
import '../tools/proof_editor_tool.dart';
import '../tools/weather_tool.dart';
import '../tools/web_scrape_tool.dart';
import '../tools/web_search_tool.dart';
import 'agent_loop.dart';
import 'context_builder.dart';
import 'memory_manager.dart';

/// Creates an AgentLoop from plain Dart types for the foreground service isolate.
///
/// The service isolate runs on a separate FlutterEngine with platform channel
/// access (via GeneratedPluginRegistrant). SharedPreferences, geolocator, and
/// — where the runtime capability probe in `ServiceSecretReader` succeeds —
/// FlutterSecureStorage all work; only WebView and UI-dependent features are
/// unavailable. Secrets are resolved by the caller (secure storage when the
/// probe passed, SharedPreferences mirrors otherwise) and passed in here.
class ServiceAgentFactory {
  ServiceAgentFactory._();

  /// Create a fully-initialized AgentLoop.
  ///
  /// All parameters come from SharedPreferences (cached by the main isolate).
  /// The sessions.db directory is derived from [workspacePath] by
  /// [SessionManager] via `SessionsDbPath`, so both isolates open their own
  /// WAL connection on the same database file.
  static Future<AgentLoop> create({
    required SharedPreferences prefs,
    required String apiKey,
    required String providerName,
    required String workspacePath,
    String? braveApiKey,
    String? orsApiKey,
    String? sncfApiKey,
    String? primApiKey,
    String locale = 'en',
    String? kbLanguage,
    String? embeddingApiKey,
    String embeddingProvider = '',
    String embeddingModel = '',
    int embeddingDimensions = 768,
    String embeddingApiBase = '',
    bool embeddingUseOwnKey = false,
  }) async {
    // 1. Open the sessions database: SessionManager resolves the shared
    //    sessions.db directory from the workspace path (and runs the
    //    one-shot Hive→SQLite migration if this isolate is first — e.g.
    //    autoRunOnBoot started the service before the app).
    final sessionManager = SessionManager();
    await sessionManager.init(workspacePath: workspacePath);

    // 2. Load AppConfig from SharedPreferences
    final configRaw = prefs.getString(AppConstants.configKey);
    final config = configRaw != null
        ? AppConfig.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(configRaw) as Map,
            ),
          )
        : AppConfig.defaults();

    // 3. Create LLM provider
    final providerConfig = config.providers[providerName];
    if (providerConfig == null) {
      throw StateError('No provider config for "$providerName"');
    }
    final provider = ProviderFactory.create(
      name: providerName,
      config: providerConfig,
      apiKey: apiKey,
      defaultModel: config.agent.model,
    );

    // 4. Create ToolRegistry (service-safe tools only)
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
    if (!disabled.contains('file')) {
      registry.register(FileTool(workspacePath: workspacePath));
    }
    if (!disabled.contains('get_location')) {
      registry.register(LocationTool(canRequestPermission: false));
    }
    if (!disabled.contains('get_address')) {
      registry.register(ReverseGeocodeTool());
    }
    if (!disabled.contains('get_datetime')) {
      registry.register(DateTimeTool(locale: locale));
    }
    if (!disabled.contains('device_info')) {
      registry.register(DeviceInfoTool(locale: locale));
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
    if (!disabled.contains('ocr')) {
      registry.register(OcrTool(workspacePath: workspacePath));
    }
    if (!disabled.contains('qr_generate')) {
      registry.register(QrGenerateTool(workspacePath: workspacePath));
    }
    if (!disabled.contains('weather')) {
      registry.register(WeatherTool(locale: locale));
    }
    if (!disabled.contains('proof_editor')) {
      final proofStorePath = p.join(
          SessionsDbPath.dirFromWorkspace(workspacePath),
          'proof_documents.json');
      registry.register(ProofEditorTool(
        store: ProofDocumentStore(proofStorePath),
        locale: locale,
      ));
    }
    // Excluded from service isolate:
    // - WebScrapeJsTool (WebView needs Activity)
    // - SubagentTool (self-referential, complex lifecycle)
    // - MessageTool (no UI in service isolate)
    // - ClipboardTool (read requires foreground on Android 10+)
    // - SpeakTool (audio focus, no user context)
    // - OpenAppTool (launches Activity, jarring from background)
    // - SetAlarmTool (opens Clock app, jarring from background)
    // - NotificationsTool (initialization requires Activity context)
    // - ContactsTool (ContentProvider unreliable from background)
    // - CalendarTool (ContentProvider unreliable from background)
    // - PickImageTool (image picker UI needs Activity)
    // - VolumeControlTool (MethodChannel registered on Activity FlutterEngine only)
    // - RadioTool (MediaSessionService requires Activity FlutterEngine)

    // 4b. Embedding provider. Cloud providers are pure HTTP and always work
    // here. The 'local' provider needs the flutter_onnxruntime plugin, which
    // is registered on the service FlutterEngine via GeneratedPluginRegistrant
    // but is NOT documented to work there — so creation (and the disk check)
    // is wrapped in try/catch with a null fallback: cron turns degrade to
    // lexical-only KG search instead of failing. Note the ONNX session loads
    // lazily, so a plugin failure can also surface at first embed() — those
    // land in the existing degraded-retrieval paths.
    EmbeddingProvider? embeddingProviderInstance;
    if (embeddingProvider == AppConstants.localEmbeddingProviderName) {
      try {
        final modelsRoot =
            ModelDownloadManager.rootFromWorkspace(workspacePath);
        const spec = ModelSpec.embeddingGemmaInt8;
        if (ModelDownloadManager.isReadySync(
            modelsRootDir: modelsRoot, spec: spec)) {
          embeddingProviderInstance = EmbeddingProviderFactory.create(
            providerName: embeddingProvider,
            dimensions: embeddingDimensions,
            localModelDir: p.join(modelsRoot, spec.id),
          );
        } else {
          AppLogger.instance.warning(LogSource.service,
              'Local embedding model not downloaded — KG search is '
              'lexical-only in the service isolate');
        }
      } catch (e) {
        AppLogger.instance.warning(LogSource.service,
            'Local embedding provider unavailable in service isolate: $e');
        embeddingProviderInstance = null;
      }
    } else if (embeddingProvider.isNotEmpty) {
      final embKey = embeddingUseOwnKey ? embeddingApiKey : apiKey;
      if (embKey != null && embKey.isNotEmpty) {
        embeddingProviderInstance = EmbeddingProviderFactory.create(
          providerName: embeddingProvider,
          apiKey: embKey,
          apiBase: embeddingApiBase.isNotEmpty ? embeddingApiBase : null,
          dimensions: embeddingDimensions,
        );
      }
    }

    // 4c. Knowledge Graph tools (with optional vector search via embeddings)
    KnowledgeService? knowledgeService;
    IngestionPipeline? ingestionPipeline;
    EpisodeStore? episodeStore;
    final kgEnabled = prefs.getBool(AppConstants.cachedKnowledgeEnabledKey) ?? false;
    if (kgEnabled) {
      try {
        final dbPath = p.join(workspacePath, AppConstants.knowledgeDbFilename);
        final kgDb = KnowledgeGraphDB(dbPath);
        // Episodic memory (U4): the service isolate opens its own WAL
        // connection, so episodes written by cron turns are visible to the
        // main isolate (and vice versa).
        episodeStore = EpisodeStore(kgDb);
        knowledgeService = KnowledgeService(
          db: kgDb,
          embeddingProvider: embeddingProviderInstance,
          embeddingModel: embeddingModel,
          embeddingDimensions: embeddingDimensions,
        );

        if (config.knowledge.autoExtract) {
          final resolver = EntityResolver(kgDb);
          ingestionPipeline = IngestionPipeline(
            extractor: EntityExtractor(
              provider: provider,
              model: config.agent.model,
              kbLanguage: kbLanguage,
            ),
            resolver: resolver,
            db: kgDb,
            embeddingProvider: embeddingProviderInstance,
            embeddingModel: embeddingModel,
            embeddingDimensions: embeddingDimensions,
          );
        }

        if (!disabled.contains('knowledge_search')) {
          registry.register(KnowledgeSearchTool(
            knowledgeService: knowledgeService,
            kbLanguage: kbLanguage,
          ));
        }
        if (!disabled.contains('knowledge_store')) {
          final resolver = EntityResolver(kgDb);
          registry.register(KnowledgeStoreTool(
            db: kgDb,
            resolver: resolver,
            kbLanguage: kbLanguage,
          ));
        }
        if (!disabled.contains('kb_query')) {
          registry.register(KnowledgeQueryTool(
            knowledgeService: knowledgeService,
          ));
        }
      } catch (_) {
        // KG init failed in service isolate — continue without it
        episodeStore = null;
      }
    }

    // 5. Create StorageService with pre-resolved workspace path
    final storageService = StorageService(
      prefs: prefs,
      overrideWorkspacePath: workspacePath,
    );

    // 6. Create ContextBuilder
    final memoryManager = MemoryManager(storageService);
    final skillLoader = SkillLoader(storageService);
    final proofStorePath = p.join(
        SessionsDbPath.dirFromWorkspace(workspacePath),
        'proof_documents.json');
    final contextBuilder = ContextBuilder(
      memoryManager: memoryManager,
      skillLoader: skillLoader,
      toolRegistry: registry,
      workspacePath: workspacePath,
      locale: locale,
      kbLanguage: kbLanguage,
      proofDocumentStore: ProofDocumentStore(proofStorePath),
    );

    // 7. Build AgentLoop
    return AgentLoop(
      provider: provider,
      config: config,
      sessions: sessionManager,
      tools: registry,
      contextBuilder: contextBuilder,
      knowledgeService: knowledgeService,
      ingestionPipeline: ingestionPipeline,
      episodeStore: episodeStore,
    );
  }
}
