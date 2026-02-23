import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/storage_service.dart';
import '../../shared/constants.dart';
import '../config/app_config.dart';
import '../providers/provider_factory.dart';
import '../session/session_manager.dart';
import '../skills/skill_loader.dart';
import '../tools/datetime_tool.dart';
import '../tools/device_info_tool.dart';
import '../tools/directions_tool.dart';
import '../tools/geocode_tool.dart';
import '../tools/file_tool.dart';
import '../tools/location_tool.dart';
import '../tools/ocr_tool.dart';
import '../tools/qr_generate_tool.dart';
import '../tools/reverse_geocode_tool.dart';
import '../tools/tool.dart';
import '../tools/transit_tool.dart';
import '../tools/weather_tool.dart';
import '../tools/web_scrape_tool.dart';
import '../tools/web_search_tool.dart';
import 'agent_loop.dart';
import 'context_builder.dart';
import 'memory_manager.dart';

/// Creates an AgentLoop from plain Dart types for the foreground service isolate.
///
/// The service isolate runs on a separate FlutterEngine with platform channel
/// access (via GeneratedPluginRegistrant). SharedPreferences, geolocator, etc.
/// work. Only FlutterSecureStorage, WebView, and UI-dependent features are
/// unavailable. All secrets and paths must be pre-resolved and passed in.
class ServiceAgentFactory {
  ServiceAgentFactory._();

  /// Create a fully-initialized AgentLoop.
  ///
  /// All parameters come from SharedPreferences (cached by the main isolate).
  /// [hivePath] must point to the same directory used by Hive.initFlutter()
  /// so both isolates share the same session data.
  static Future<AgentLoop> create({
    required SharedPreferences prefs,
    required String apiKey,
    required String providerName,
    required String workspacePath,
    required String hivePath,
    String? braveApiKey,
    String? orsApiKey,
    String? sncfApiKey,
    String? primApiKey,
    String locale = 'en',
  }) async {
    // 1. Initialize Hive (plain Dart — no initFlutter)
    Hive.init(hivePath);
    final sessionManager = SessionManager();
    await sessionManager.init();

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

    // 5. Create StorageService with pre-resolved workspace path
    final storageService = StorageService(
      prefs: prefs,
      overrideWorkspacePath: workspacePath,
    );

    // 6. Create ContextBuilder
    final memoryManager = MemoryManager(storageService);
    final skillLoader = SkillLoader(storageService);
    final contextBuilder = ContextBuilder(
      memoryManager: memoryManager,
      skillLoader: skillLoader,
      toolRegistry: registry,
      workspacePath: workspacePath,
      locale: locale,
    );

    // 7. Build AgentLoop
    return AgentLoop(
      provider: provider,
      config: config,
      sessions: sessionManager,
      tools: registry,
      contextBuilder: contextBuilder,
    );
  }
}
