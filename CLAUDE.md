# CLAUDE.md — DroidClaw

## Project

DroidClaw is a personal AI assistant Android app, ported from [PicoClaw](https://github.com/sipeed/picoclaw) (Go). Everything runs on-device: agent loop, LLM API calls, tool execution, session management. No external server.

- **Language**: Dart 3.10 / Flutter 3.38
- **Platform**: Android only (minSdk 24, targetSdk 34)
- **Package**: `com.droidclaw.app`
- **State management**: Riverpod 3.x

## Build & Run

```bash
flutter pub get
flutter analyze          # must pass with 0 issues
flutter build apk --release --split-per-abi
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Debug logs on device:
```bash
adb logcat -s flutter | grep '\[AgentLoop\]'
```

## Architecture

```
lib/
├── main.dart                    # Entry point (init Hive + SharedPrefs)
├── app.dart                     # MaterialApp, routing, Material 3 theme
├── core/                        # Business logic (NO Flutter UI imports)
│   ├── agent/                   # AgentLoop, ContextBuilder, MemoryManager, ServiceAgentFactory
│   ├── config/                  # AppConfig, ConfigStorage, CronConfig
│   ├── knowledge/               # Knowledge Graph (DB, ingestion, hybrid search, algorithms)
│   ├── providers/               # LLM + Embedding abstraction (Anthropic, HTTP, Gemini, factory)
│   ├── services/                # BackgroundTaskHandler, AudioManagerChannel
│   ├── session/                 # Session + SessionManager (Hive persistence)
│   ├── skills/                  # Three-tier loader + installer
│   └── tools/                   # Tool interface + 28 implementations
├── features/                    # Screens and platform features
│   ├── chat/                    # Chat screen, message bubbles, history
│   ├── onboarding/              # First-launch setup
│   ├── settings/                # Provider, tools, skills, cron, Telegram, routing
│   ├── telegram/                # Bot API, bot manager, rate limiter
│   └── voice/                   # Voice input (STT via Groq Whisper)
├── providers/                   # Riverpod: app, chat, background service, Telegram
├── data/local/                  # StorageService (SharedPrefs + SecureStorage)
└── shared/                      # Constants
```

## Critical Patterns

### Riverpod 3.x — No StateNotifier

Use `Notifier` / `NotifierProvider`, NOT `StateNotifier` / `StateProvider` (removed in Riverpod 3.x).

```dart
// CORRECT
final fooProvider = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);
class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() => FooState.initial();
}

// WRONG — will not compile
final fooProvider = StateNotifierProvider<FooNotifier, FooState>(...);
```

### Async Providers

`sessionManagerProvider` and `toolRegistryProvider` are `FutureProvider` (Hive init, workspace path). Access with `.future`:

```dart
final sessions = await ref.watch(sessionManagerProvider.future);
final tools = await ref.watch(toolRegistryProvider.future);
```

### Provider Cascade

Changing `appConfigProvider` automatically rebuilds everything downstream:

```
appConfigProvider → toolRegistryProvider → contextBuilderProvider → agentLoopProvider
                 → llmProviderProvider ↗
```

### Dual ToolResult (from Go codebase)

Every tool returns dual content. This is critical — do not use `.simple()` when the user display should differ from the LLM context.

```dart
ToolResult.dual(
  forLLM: 'Full structured data for reasoning...',
  forUser: 'Clean short summary for UI',
);
```

Factory constructors: `.simple()`, `.error()`, `.silent()`, `.dual()`.

### Anthropic vs OpenAI API Format

- **OpenAI/OpenRouter/Groq/Gemini**: system message in messages array, `tool_calls[].function.name`, `function.arguments` as JSON string
- **Anthropic**: separate `system` field, content blocks (`tool_use` / `tool_result`), `x-api-key` + `anthropic-version` headers

Both formats are handled by `AnthropicProvider` and `HttpProvider`. The `ToolCall.fromJson()` factory parses both formats.

### Tool Result Messages Must Include `name`

When adding tool results to the session, always include `name: toolCall.name`. Gemini API returns 400 without it:

```dart
session.addMessage(Message(
  role: 'tool',
  content: result.forLLM,
  toolCallId: toolCall.id,
  name: toolCall.name,  // REQUIRED for Gemini
));
```

### Agent Loop Event Stream

```dart
sealed class AgentEvent {}
// ThinkingEvent, ToolCallEvent, ToolResultEvent, ResponseEvent, ErrorEvent, SummarizingEvent
```

Both chat UI and Telegram consume the same `Stream<AgentEvent>`.

### Embedding Provider Architecture

Multi-provider embedding abstraction mirroring the LLM provider pattern:

- `EmbeddingProvider` (interface) → `BaseCloudEmbeddingProvider` (shared retry) → `GeminiEmbeddingProvider` / `OpenAIEmbeddingProvider`
- `EmbeddingProviderFactory.create()` routes by provider name
- Gemini uses native REST API (`generativelanguage.googleapis.com/v1beta`), NOT the OpenAI-compatible chat endpoint
- Config in `AppConfig.embedding` (`EmbeddingConfig`: provider, model, dimensions, useOwnApiKey)
- API key: either reuses LLM provider key (`useOwnApiKey: false`) or separate key in `FlutterSecureStorage`
- `embeddingProviderProvider` is a `FutureProvider<EmbeddingProvider?>` with `ref.onDispose`

### Knowledge Graph Pipeline

- **Ingestion**: `IngestionPipeline.extractAndStore()` → LLM extraction → entity resolution → bi-temporal storage → embedding computation
- **Retrieval**: `KnowledgeService.queryRelevant()` → FTS5 BM25 + vector cosine similarity + spreading activation + Ebbinghaus decay → `HybridScorer.fuse()`
- `KnowledgeService` receives `EmbeddingProvider?` — when non-null, embeds query and does brute-force cosine similarity over all active entity embeddings
- `hasEmbedder` is a getter (`embeddingProvider != null`), not a constructor parameter
- Embeddings stored as Float32 little-endian BLOBs in `entities.embedding` column
- Serialization: `Float32List.fromList(doubles).buffer.asUint8List()` → BLOB
- Deserialization: `Float32List.view(Uint8List.fromList(blob).buffer)`
- Cosine similarity reuses `MemoryClusterer.cosineSimilarity()` (no code duplication)

## Adding a New Tool

1. Create `lib/core/tools/my_tool.dart` extending `Tool` (name, description, parameters JSON Schema, `execute()`)
2. Register in `lib/providers/app_providers.dart` → `toolRegistryProvider`:
   ```dart
   if (!disabled.contains('my_tool')) {
     registry.register(MyTool());
   }
   ```
3. Add toggle in `lib/features/settings/tools_config_screen.dart` → `_tools` list
4. If service isolate compatible (pure HTTP, no Activity/UI): register in `lib/core/agent/service_agent_factory.dart`
5. If it needs an API key: add getter/setter in `config_storage.dart`, cache in `background_service_provider.dart:_cacheSecretsForService()`, pass through `background_task_handler.dart` → `service_agent_factory.dart`
6. If disabled by default: add to `_defaultDisabledTools` in `lib/core/config/app_config.dart`
7. Update README tools table + availability table

## Adding a New Settings Screen

1. Create screen in `lib/features/settings/`
2. Add route in `lib/app.dart`
3. Add `ListTile` in `lib/features/settings/settings_screen.dart`

### Dual-Isolate Architecture

- **Main isolate**: Flutter UI, Riverpod, AgentLoop, TelegramBotManager
- **Service isolate**: `BackgroundTaskHandler` (Telegram polling + cron scheduling), runs on separate FlutterEngine (NOT plain Dart isolate — platform channels work)
- Service isolate has its own AgentLoop via `ServiceAgentFactory` (autonomous cron execution)
- Communication: `FlutterForegroundTask` sendDataToMain/sendDataToTask
- No `FlutterSecureStorage` in service isolate → secrets cached in `SharedPreferences` by main isolate (`_cacheSecretsForService()`)

### API Key Pattern (Brave / ORS model)

For tools needing an API key that must work in both isolates:

1. `FlutterSecureStorage` getter/setter in `config_storage.dart`
2. Config screen saves key → invalidates `toolRegistryProvider`
3. `AppConstants.cachedXxxKeyKey` for SharedPreferences cache key
4. `_cacheSecretsForService()` in `background_service_provider.dart` copies to SharedPreferences
5. `background_task_handler.dart` reads from SharedPreferences, passes to `ServiceAgentFactory`
6. Tool constructor receives `apiKey` parameter

### Custom MethodChannel (volume_control)

- `AudioChannelPlugin.kt` implements `FlutterPlugin` — registered in `MainActivity.configureFlutterEngine()`
- `AudioManagerChannel` Dart wrapper in `lib/core/services/audio_manager_channel.dart`
- MethodChannel tools only work in main isolate (registered on Activity FlutterEngine)

## Key Constraints

- **No shell execution** on Android — no exec/shell tools
- **Summarization**: triggers at 20+ messages OR estimated tokens > 75% of maxTokens, keeps last 4 messages
- **Web scraping**: try `web_scrape` first (lightweight HTTP), fall back to `web_scrape_js` (WebView) for JS-rendered pages. Max 15K chars.
- **Telegram**: long polling (not webhook) via foreground service with `remoteMessaging|location` types (no 6h limit). Dual-isolate architecture.
- **API keys**: stored in `FlutterSecureStorage`, never in `SharedPreferences` or config JSON
- **File tool**: sandboxed to app workspace directory, path validation prevents traversal
- **Flutter 3.38**: `DropdownButtonFormField` uses `initialValue` (not `value`)

## Conventions

- Manual `fromJson()` / `toJson()` — no code generation (freezed/hive_generator removed)
- `AppConstants` in `lib/shared/constants.dart` for all magic values
- `print('[AgentLoop] ...')` for debug logging (visible via `adb logcat`)
- Config persisted in `SharedPreferences`, secrets in `FlutterSecureStorage`, sessions in Hive
- All tool names are snake_case: `web_search`, `web_scrape`, `web_scrape_js`, `file`, `get_location`, `get_address`, `subagent`, `message`, `clipboard`, `device_info`, `speak`, `open_app`, `set_alarm`, `notifications`, `contacts`, `calendar`, `ocr`, `qr_generate`, `pick_image`, `volume_control`, `get_directions`, `geocode`, `get_transit`, `weather`, `get_datetime`, `knowledge_search`, `knowledge_store`, `kb_query`, `radio`, `dream`
