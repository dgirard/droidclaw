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
│   ├── agent/                   # AgentLoop, ContextBuilder, MemoryManager
│   ├── config/                  # AppConfig, ConfigStorage, CronConfig
│   ├── providers/               # LLM abstraction (Anthropic, HTTP, factory)
│   ├── session/                 # Session + SessionManager (Hive persistence)
│   ├── skills/                  # Three-tier loader + installer
│   └── tools/                   # Tool interface + 8 implementations
├── features/                    # Screens and platform features
│   ├── chat/                    # Chat screen, message bubbles, history
│   ├── onboarding/              # First-launch setup
│   ├── settings/                # Provider, tools, skills, cron, Telegram
│   ├── telegram/                # Bot API, task handler, bot manager
│   └── voice/                   # Voice input (STT via Groq Whisper)
├── providers/                   # Riverpod providers (app, chat, telegram)
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

## Adding a New Tool

1. Create `lib/core/tools/my_tool.dart` extending `Tool` (name, description, parameters JSON Schema, `execute()`)
2. Register in `lib/providers/app_providers.dart` → `toolRegistryProvider`:
   ```dart
   if (!disabled.contains('my_tool')) {
     registry.register(MyTool());
   }
   ```
3. Add toggle in `lib/features/settings/tools_config_screen.dart` → `_tools` list
4. Update README tools table

## Adding a New Settings Screen

1. Create screen in `lib/features/settings/`
2. Add route in `lib/app.dart`
3. Add `ListTile` in `lib/features/settings/settings_screen.dart`

## Key Constraints

- **No shell execution** on Android — no exec/shell tools
- **Summarization**: triggers at 20+ messages OR estimated tokens > 75% of maxTokens, keeps last 4 messages
- **Web scraping**: try `web_scrape` first (lightweight HTTP), fall back to `web_scrape_js` (WebView) for JS-rendered pages. Max 15K chars.
- **Telegram**: long polling (not webhook) via foreground service with `remoteMessaging` type (no 6h limit). Dual-isolate architecture.
- **API keys**: stored in `FlutterSecureStorage`, never in `SharedPreferences` or config JSON
- **File tool**: sandboxed to app workspace directory, path validation prevents traversal
- **Flutter 3.38**: `DropdownButtonFormField` uses `initialValue` (not `value`)

## Conventions

- Manual `fromJson()` / `toJson()` — no code generation (freezed/hive_generator removed)
- `AppConstants` in `lib/shared/constants.dart` for all magic values
- `print('[AgentLoop] ...')` for debug logging (visible via `adb logcat`)
- Config persisted in `SharedPreferences`, secrets in `FlutterSecureStorage`, sessions in Hive
- All tool names are snake_case: `web_search`, `web_scrape`, `web_scrape_js`, `file`, `get_location`, `get_address`, `subagent`, `message`
