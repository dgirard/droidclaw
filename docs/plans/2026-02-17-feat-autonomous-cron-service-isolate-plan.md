---
title: "feat: Autonomous AgentLoop in foreground service isolate"
type: feat
date: 2026-02-17
---

# Autonomous AgentLoop in Foreground Service Isolate

## Overview

Currently, cron execution depends on the main Flutter isolate being alive — the foreground service isolate detects cron triggers but must `sendDataToMain()` for actual LLM processing. When Android kills the main activity overnight, crons are delayed until the user opens the app.

This plan makes the service isolate **self-sufficient**: it initializes its own AgentLoop (LLMProvider, SessionManager, ToolRegistry, ContextBuilder) and executes crons directly — no main isolate needed.

## Architecture

```
Before:
  Service Isolate          Main Isolate
  (cron detection)  ──→    (AgentLoop execution)
                    sendDataToMain (fails if dead)

After:
  Service Isolate
  (cron detection + own AgentLoop execution)
  ──→ main isolate only for UI notifications (optional)
```

## Constraints

The service isolate is a **plain Dart isolate** — no Flutter engine binding:
- **No** `rootBundle` (Flutter assets) → builtin skills silently skipped (OK, `_loadBuiltinSkills` has try/catch)
- **No** platform channels → `LocationTool`, `ReverseGeocodeTool`, `WebScrapeJsTool` (WebView) excluded
- **No** `FlutterSecureStorage` → API keys must be read on main isolate and passed via SharedPreferences
- **No** `getApplicationDocumentsDirectory()` → workspace path must be pre-resolved and stored in SharedPreferences
- `SharedPreferences` **works** in service isolate (native Android, no Flutter engine required)
- `Hive` **works** in service isolate with `Hive.init(path)` (no `initFlutter()`)
- HTTP calls **work** (dart:io) → LLM API calls, WebSearchTool, WebScrapeTool all fine

## Implementation

### 1. Pre-resolve secrets on main isolate startup

**`lib/providers/telegram_provider.dart`** — in `_checkInitialState()` or `enable()`:

Before starting the foreground service, read all secrets from `FlutterSecureStorage` and cache them in `SharedPreferences` so the service isolate can access them:

```dart
Future<void> _cacheSecretsForService() async {
  final storage = ref.read(storageServiceProvider);
  final configStorage = ref.read(configStorageProvider);
  final config = ref.read(appConfigProvider);

  // Cache LLM API key
  final providerName = config.agent.provider;
  final apiKey = await configStorage.getApiKey(providerName);
  if (apiKey != null) {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.cachedApiKeyKey, apiKey);
    await prefs.setString(AppConstants.cachedProviderNameKey, providerName);
  }

  // Cache Brave API key
  final braveKey = await configStorage.getBraveApiKey();
  if (braveKey != null) {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.cachedBraveApiKeyKey, braveKey);
  }

  // Cache workspace path
  final workspacePath = await storage.workspacePath;
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setString(AppConstants.cachedWorkspacePathKey, workspacePath);
}
```

- [x] Add `cachedApiKeyKey`, `cachedProviderNameKey`, `cachedBraveApiKeyKey`, `cachedWorkspacePathKey` to `constants.dart`
- [x] Call `_cacheSecretsForService()` in `enable()` and `ensureServiceRunning()` before starting the service
- [ ] Also call it in `_checkInitialState()` when the service is already running (refresh cache on app open)

### 2. Create ServiceAgentFactory

**NEW: `lib/core/agent/service_agent_factory.dart`**

A standalone factory that creates an `AgentLoop` from plain Dart types (no Riverpod, no Flutter). Used by the service isolate:

```dart
class ServiceAgentFactory {
  /// Create a fully-initialized AgentLoop from pre-resolved values.
  /// Call from the service isolate.
  static Future<AgentLoop> create({
    required String apiKey,
    required String providerName,
    required Map<String, dynamic> configJson,
    required String workspacePath,
    required String hivePath,
    String? braveApiKey,
  }) async {
    // 1. Initialize Hive (plain Dart, no Flutter)
    Hive.init(hivePath);
    final sessionManager = SessionManager();
    await sessionManager.init();

    // 2. Load AppConfig from JSON
    final config = AppConfig.fromJson(configJson);

    // 3. Create LLM provider
    final providerConfig = config.providers[providerName]!;
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
    // MessageTool: no UI in service → skip or register with no-op
    // Excluded: WebScrapeJsTool (WebView), LocationTool, ReverseGeocodeTool
    //           (platform channels), SubagentTool (self-referential)

    // 5. Create StorageService with a "headless" SharedPreferences
    //    (already available in service isolate)
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs: prefs);

    // 6. Create ContextBuilder
    final memoryManager = MemoryManager(storageService);
    final skillLoader = SkillLoader(storageService);
    final contextBuilder = ContextBuilder(
      memoryManager: memoryManager,
      skillLoader: skillLoader,
      toolRegistry: registry,
      workspacePath: workspacePath,
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
```

- [x] Create `lib/core/agent/service_agent_factory.dart`
- [x] Import all necessary types (no Flutter imports — only dart:* and package:hive)

### 3. Modify TelegramTaskHandler to use AgentLoop

**`lib/features/telegram/telegram_task_handler.dart`**:

Add AgentLoop initialization and direct cron execution:

```dart
class TelegramTaskHandler extends TaskHandler {
  // ... existing fields ...
  AgentLoop? _agentLoop;
  bool _agentInitializing = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // ... existing init (Telegram API, offset, crons) ...

    // Initialize AgentLoop for autonomous cron execution
    _initAgentLoop();
  }

  Future<void> _initAgentLoop() async {
    if (_agentInitializing) return;
    _agentInitializing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(AppConstants.cachedApiKeyKey);
      final providerName = prefs.getString(AppConstants.cachedProviderNameKey);
      final workspacePath = prefs.getString(AppConstants.cachedWorkspacePathKey);
      final configJson = prefs.getString(AppConstants.configKey);

      if (apiKey == null || providerName == null || workspacePath == null || configJson == null) {
        _log('Cannot init AgentLoop: missing cached config');
        return;
      }

      // Hive data dir (same as Flutter's path)
      final hivePath = '$workspacePath/../app_flutter';

      _agentLoop = await ServiceAgentFactory.create(
        apiKey: apiKey,
        providerName: providerName,
        configJson: jsonDecode(configJson) as Map<String, dynamic>,
        workspacePath: workspacePath,
        hivePath: hivePath,
        braveApiKey: prefs.getString(AppConstants.cachedBraveApiKeyKey),
      );

      _log('AgentLoop initialized in service isolate');
    } catch (e) {
      _log('Failed to init AgentLoop: $e');
    } finally {
      _agentInitializing = false;
    }
  }
```

Modify `_checkCrons()` to execute directly when AgentLoop is available:

```dart
if (due) {
  _log('Triggering cron "${cron.name}"');
  _updateCronLastRun(cron.id, now, prefs);

  if (_agentLoop != null) {
    // Execute directly in service isolate
    _executeCronLocally(cron, prefs);
  } else {
    // Fallback: queue for main isolate (existing behavior)
    final triggerData = { ... };
    _addPendingTrigger(prefs, triggerData);
    FlutterForegroundTask.sendDataToMain(triggerData);
    FlutterForegroundTask.launchApp();
  }
}
```

New `_executeCronLocally()` method:

```dart
Future<void> _executeCronLocally(CronDefinition cron, SharedPreferences prefs) async {
  final sessionKey = cron.sessionStrategy == SessionStrategy.sameThread
      ? '${AppConstants.cronSessionPrefix}${cron.id}'
      : '${AppConstants.cronSessionPrefix}${cron.id}_${DateTime.now().millisecondsSinceEpoch}';

  _log('Executing "${cron.name}" locally (session=$sessionKey)');

  try {
    await for (final event in _agentLoop!.processMessage(cron.prompt, sessionKey)) {
      if (event is ResponseEvent) {
        _log('Got response for "${cron.name}" (${event.content.length} chars)');
        // Notify main isolate of completion (for UI update, optional)
        FlutterForegroundTask.sendDataToMain({
          'type': 'cron_completed',
          'cron_id': cron.id,
          'cron_name': cron.name,
          'response_length': event.content.length,
        });
        break;
      } else if (event is ErrorEvent) {
        _log('ERROR in "${cron.name}": ${event.message}');
        break;
      }
    }

    // Save session
    _agentLoop!.sessions.save(_agentLoop!.sessions.get(sessionKey)!);
    _log('Session saved for "${cron.name}"');
  } catch (e) {
    _log('EXCEPTION in "${cron.name}": $e');
  }
}
```

- [x] Add `_agentLoop` field and `_initAgentLoop()` method
- [x] Import `service_agent_factory.dart` and agent event types
- [x] Modify `_checkCrons()` to use local execution when AgentLoop is available
- [x] Add `_executeCronLocally()` method
- [x] Keep fallback to pending queue if AgentLoop init fails
- [x] Handle `reload_crons` action to also re-init AgentLoop if config changed

### 4. Add StorageService workaround for SecureStorage

**`lib/data/local/storage_service.dart`**:

The service isolate cannot use `FlutterSecureStorage`. For `SkillLoader` and `MemoryManager`, only workspace filesystem access and SharedPreferences reads are needed — `getSecure()`/`setSecure()` are never called by these classes.

The current `StorageService` constructor accepts an optional `FlutterSecureStorage`. In the service isolate, we pass `null` and the code will fail only if `getSecure()` is called (which it won't be by MemoryManager or SkillLoader):

```dart
StorageService({
  required SharedPreferences prefs,
  FlutterSecureStorage? secure,
  String? overrideWorkspacePath,  // NEW: for service isolate
})  : _prefs = prefs,
     _secure = secure ?? const FlutterSecureStorage(),
     _workspacePath = overrideWorkspacePath;
```

- [x] Add `overrideWorkspacePath` parameter to `StorageService` constructor
- [ ] Use it in `ServiceAgentFactory` to avoid calling `getApplicationDocumentsDirectory()`

### 5. Add new constants

**`lib/shared/constants.dart`**:

```dart
// Cached secrets for service isolate (stored in SharedPreferences)
static const String cachedApiKeyKey = 'cached_api_key';
static const String cachedProviderNameKey = 'cached_provider_name';
static const String cachedBraveApiKeyKey = 'cached_brave_api_key';
static const String cachedWorkspacePathKey = 'cached_workspace_path';
```

- [x] Add 4 cached key constants

### 6. Handle Hive path in service isolate

The main app uses `Hive.initFlutter()` which resolves to `getApplicationDocumentsDirectory()/app_flutter/`. The service isolate needs the same path to access the same Hive boxes.

Since we already cache `workspacePath` (which is `getApplicationDocumentsDirectory()/droidclaw_workspace/`), we can derive the Hive path:

```dart
// workspacePath = /data/data/com.droidclaw.app/app_flutter/droidclaw_workspace
// hivePath      = /data/data/com.droidclaw.app/app_flutter
final hivePath = Directory(workspacePath).parent.path;
```

- [x] Verify Hive path derivation works (may need to cache explicitly)

### 7. Notify main isolate of cron results (optional UI update)

**`lib/providers/telegram_provider.dart`**:

Handle the new `cron_completed` message type for UI updates:

```dart
case 'cron_completed':
  _cronLog('Service isolate completed "${map['cron_name']}" '
      '(${map['response_length']} chars)');
  // Optionally refresh session list in UI
  break;
```

- [x] Add `cron_completed` handler in `_onReceiveTaskData()`

### 8. Security consideration: API key in SharedPreferences

Storing the API key in SharedPreferences (unencrypted) is a trade-off:
- SharedPreferences is in the app's private directory (`/data/data/com.droidclaw.app/`)
- On non-rooted devices, other apps cannot read it
- On rooted devices, FlutterSecureStorage is also compromised (Android Keystore accessible)
- The key is cached only when the service needs it, not exposed in UI

This is acceptable for the service isolate use case. The cached key mirrors what the service already has access to (it runs in the same app process).

- [x] Document trade-off in code comments

## Acceptance Criteria

- [x] Crons execute at exact scheduled time even when main app is killed
- [x] Service isolate initializes AgentLoop on startup
- [x] Sessions from cron execution are visible when app is opened (shared Hive box)
- [x] Fallback to pending queue if AgentLoop init fails (missing config, etc.)
- [x] `flutter analyze` passes
- [x] APK builds and installs
- [x] Manual test: schedule a cron, kill app, verify execution in logs

## Files Changed

| File | Change |
|------|--------|
| `lib/core/agent/service_agent_factory.dart` | **NEW** — Standalone factory for AgentLoop in service isolate |
| `lib/features/telegram/telegram_task_handler.dart` | Add AgentLoop init + direct cron execution |
| `lib/providers/telegram_provider.dart` | Cache secrets before service start + handle `cron_completed` |
| `lib/data/local/storage_service.dart` | Add `overrideWorkspacePath` constructor parameter |
| `lib/shared/constants.dart` | Add cached secret keys |

## Risks

1. **Hive concurrent access**: Both isolates access the same Hive box. Hive supports multiple isolates reading/writing to the same box IF both call `Hive.init()` with the same path. Hive uses file-level locking. Should work but monitor for data corruption.

2. **SharedPreferences staleness**: The service isolate must call `prefs.reload()` before reading cached values (SharedPreferences in a different isolate may have stale data). Already handled in the existing `reload_crons` logic.

3. **Memory usage**: A full AgentLoop in the service isolate adds memory overhead. Acceptable since crons are infrequent and the LLM HTTP client is lightweight.

## References

- `docs/solutions/runtime-errors/cron-triggers-lost-when-main-isolate-dead.md` — previous fix (pending queue)
- `docs/plans/2026-02-16-feat-scheduled-prompts-cron-plan.md` — original cron architecture
- `lib/providers/app_providers.dart` — main isolate provider wiring (reference for service isolate)
