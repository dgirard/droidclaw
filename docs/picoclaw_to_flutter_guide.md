# PicoClaw: Go → Flutter/Dart (Android APK) Conversion Guide

## 1. Source Project Analysis

### Overview
PicoClaw is an ultra-lightweight AI assistant written in Go (~16K lines excluding tests) that runs as a CLI/gateway on small Linux hardware. The goal is to make it a **native Android app** in pure Flutter/Dart.

### Current Go Architecture (main modules)

| Go Package | Role | Lines |
|---|---|---|
| `cmd/picoclaw/main.go` | CLI, commands (agent, gateway, onboard, cron, skills, auth) | ~1400 |
| `pkg/agent/loop.go` | Agentic loop: system prompt → LLM → tool calls → iteration | ~780 |
| `pkg/agent/context.go` | Context building (system prompt, memory, skills) | ~200 |
| `pkg/agent/memory.go` | Conversational memory management | ~150 |
| `pkg/providers/*` | LLM abstraction (Anthropic, OpenAI, OpenRouter, Gemini, vLLM…) | ~2200 |
| `pkg/channels/*` | Messaging channels (Telegram, Discord, Slack, WhatsApp, DingTalk…) | ~3500 |
| `pkg/tools/*` | Agent tools (filesystem, shell, web search, I2C, SPI, cron, subagent) | ~2800 |
| `pkg/config/` | JSON configuration | ~440 |
| `pkg/session/` | Session/history management | ~250 |
| `pkg/bus/` | Internal message bus (pub/sub) | ~150 |
| `pkg/cron/` | Scheduled tasks | ~500 |
| `pkg/auth/` | OAuth/PKCE + token store | ~900 |
| `pkg/skills/` | Skills loader and installer | ~500 |
| `pkg/heartbeat/` | Heartbeat service | ~365 |
| `pkg/state/` | State manager | ~250 |
| `pkg/voice/` | Voice transcription (Groq) | ~160 |

---

## 2. Conversion Strategy

### What to KEEP (app core)
- **Agent Loop**: the agentic loop (LLM → tool calls → iteration)
- **Providers**: multi-LLM abstraction (Anthropic, OpenAI, OpenRouter…)
- **Tools**: web search, web fetch (most useful on mobile)
- **Config**: configuration management
- **Session/Memory**: conversation history
- **Skills**: skills loading

### What to ADAPT
- **Channels** → replaced by Flutter UI (single "channel": the chat screen)
- **Bus** → replaced by Dart Streams or Riverpod/Bloc
- **Auth** → Mobile OAuth via `flutter_appauth` or `url_launcher`
- **Storage** → `shared_preferences` + local files via `path_provider`
- **Cron** → `workmanager` for Android background tasks

### What to REMOVE
- **Shell/Exec tool**: no shell execution on Android
- **Filesystem tools**: limited to Android sandboxing (adapt with scoped storage)
- **I2C/SPI tools**: Linux hardware only
- **USB device monitoring**: not relevant on Android
- **HTTP health server**: not necessary for a mobile app
- **OpenClaw migration**: not relevant
- **Gateway/CLI**: replaced by Flutter UI

---

## 3. Target Flutter Architecture

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MaterialApp, routing, theme
│
├── core/
│   ├── config/
│   │   ├── app_config.dart      # ← pkg/config/config.go
│   │   └── config_storage.dart  # Local JSON persistence
│   │
│   ├── providers/               # ← pkg/providers/
│   │   ├── llm_provider.dart    # Abstract LLMProvider interface
│   │   ├── llm_response.dart    # Types: LLMResponse, ToolCall, Message
│   │   ├── http_provider.dart   # Generic OpenAI-compatible provider
│   │   ├── anthropic_provider.dart
│   │   ├── openai_provider.dart
│   │   ├── openrouter_provider.dart
│   │   └── provider_factory.dart
│   │
│   ├── agent/                   # ← pkg/agent/
│   │   ├── agent_loop.dart      # Main agentic loop
│   │   ├── context_builder.dart # System prompt + context building
│   │   └── memory_manager.dart  # Conversational memory
│   │
│   ├── tools/                   # ← pkg/tools/ (subset)
│   │   ├── tool.dart            # Tool interface + ToolRegistry
│   │   ├── web_search_tool.dart # Web search (Brave/DuckDuckGo)
│   │   ├── web_fetch_tool.dart  # URL fetch
│   │   └── file_tool.dart       # File read/write (sandboxed)
│   │
│   ├── session/
│   │   └── session_manager.dart # ← pkg/session/manager.go
│   │
│   └── skills/
│       ├── skill_loader.dart    # ← pkg/skills/loader.go
│       └── skill_installer.dart # ← pkg/skills/installer.go
│
├── features/
│   ├── chat/
│   │   ├── chat_screen.dart     # Main chat screen
│   │   ├── chat_controller.dart # Business logic (replaces bus + channel)
│   │   ├── message_bubble.dart  # Message widget
│   │   └── input_bar.dart       # Input bar + mic
│   │
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── provider_config_screen.dart
│   │   └── skills_screen.dart
│   │
│   ├── onboarding/
│   │   └── onboard_screen.dart  # ← onboard command
│   │
│   └── voice/
│       └── voice_input.dart     # STT via Groq or speech_to_text
│
├── data/
│   ├── repositories/
│   │   ├── config_repository.dart
│   │   ├── session_repository.dart
│   │   └── skills_repository.dart
│   │
│   └── local/
│       └── storage_service.dart # shared_preferences + File I/O
│
└── shared/
    ├── utils/
    │   ├── media_utils.dart     # ← pkg/utils/media.go
    │   └── string_utils.dart    # ← pkg/utils/string.go
    └── constants.dart
```

---

## 4. Module-by-Module Conversion

### 4.1 Base Types and LLM Provider

**Go (pkg/providers/types.go) → Dart**

```dart
// lib/core/providers/llm_response.dart

class ToolCall {
  final String id;
  final String type;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.id,
    this.type = 'function',
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    // Handle both formats: OpenAI (function.name) and Anthropic (name)
    final function = json['function'] as Map<String, dynamic>?;
    return ToolCall(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'function',
      name: function?['name'] as String? ?? json['name'] as String,
      arguments: function != null
          ? jsonDecode(function['arguments'] as String)
          : json['arguments'] as Map<String, dynamic>,
    );
  }
}

class LLMResponse {
  final String content;
  final List<ToolCall> toolCalls;
  final String finishReason;
  final UsageInfo? usage;

  LLMResponse({
    required this.content,
    this.toolCalls = const [],
    required this.finishReason,
    this.usage,
  });
}

class UsageInfo {
  final int promptTokens;
  final int completionTokens;
  int get totalTokens => promptTokens + completionTokens;

  UsageInfo({required this.promptTokens, required this.completionTokens});
}

class Message {
  final String role;
  final String content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;

  Message({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (toolCalls != null) 'tool_calls': toolCalls!.map((t) => t.toJson()).toList(),
    if (toolCallId != null) 'tool_call_id': toolCallId,
  };
}
```

**Provider Interface:**

```dart
// lib/core/providers/llm_provider.dart

abstract class LLMProvider {
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  });

  String get defaultModel;
}

class ToolDefinition {
  final String type;
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  ToolDefinition({
    this.type = 'function',
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}
```

### 4.2 HTTP Provider (OpenAI-compatible)

**Go (pkg/providers/http_provider.go) → Dart**

```dart
// lib/core/providers/http_provider.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpProvider implements LLMProvider {
  final String apiKey;
  final String apiBase;
  final String _defaultModel;
  final Map<String, String> _extraHeaders;

  HttpProvider({
    required this.apiKey,
    required this.apiBase,
    required String defaultModel,
    Map<String, String>? extraHeaders,
  })  : _defaultModel = defaultModel,
        _extraHeaders = extraHeaders ?? {};

  @override
  String get defaultModel => _defaultModel;

  @override
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }

    if (options != null) {
      if (options.containsKey('max_tokens')) {
        body['max_tokens'] = options['max_tokens'];
      }
      if (options.containsKey('temperature')) {
        body['temperature'] = options['temperature'];
      }
    }

    final uri = Uri.parse('$apiBase/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        ..._extraHeaders,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('LLM API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choice = (data['choices'] as List).first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    final toolCalls = (message['tool_calls'] as List?)
        ?.map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
        .toList();

    final usage = data['usage'] as Map<String, dynamic>?;

    return LLMResponse(
      content: message['content'] as String? ?? '',
      toolCalls: toolCalls ?? [],
      finishReason: choice['finish_reason'] as String? ?? 'stop',
      usage: usage != null
          ? UsageInfo(
              promptTokens: usage['prompt_tokens'] as int,
              completionTokens: usage['completion_tokens'] as int,
            )
          : null,
    );
  }
}
```

### 4.3 Agent Loop (the core)

**Go (pkg/agent/loop.go) → Dart**

```dart
// lib/core/agent/agent_loop.dart

import 'dart:async';

class AgentLoop {
  final LLMProvider provider;
  final AppConfig config;
  final SessionManager sessions;
  final ToolRegistry tools;
  final ContextBuilder contextBuilder;

  AgentLoop({
    required this.provider,
    required this.config,
    required this.sessions,
    required this.tools,
    required this.contextBuilder,
  });

  /// Processes a user message and returns the final response.
  /// Manages the tool-calling loop iteratively.
  Stream<AgentEvent> processMessage(String userMessage, String sessionKey) async* {
    final session = sessions.getOrCreate(sessionKey);

    // Build context (system prompt + skills + memory)
    final systemPrompt = contextBuilder.buildSystemPrompt();

    // Add user message to history
    session.addMessage(Message(role: 'user', content: userMessage));

    // Agentic loop
    for (var iteration = 0; iteration < config.maxToolIterations; iteration++) {
      final messages = [
        Message(role: 'system', content: systemPrompt),
        ...session.getMessages(),
      ];

      yield AgentEvent.thinking(iteration: iteration);

      final response = await provider.chat(
        messages: messages,
        tools: tools.getDefinitions(),
        model: config.model,
        options: {
          'max_tokens': config.maxTokens,
          'temperature': config.temperature,
        },
      );

      // No tool calls → final response
      if (response.toolCalls.isEmpty) {
        session.addMessage(Message(role: 'assistant', content: response.content));
        yield AgentEvent.response(content: response.content, usage: response.usage);
        return;
      }

      // Add assistant response with tool calls
      session.addMessage(Message(
        role: 'assistant',
        content: response.content,
        toolCalls: response.toolCalls,
      ));

      // Execute each tool call
      for (final toolCall in response.toolCalls) {
        yield AgentEvent.toolCall(name: toolCall.name, arguments: toolCall.arguments);

        final result = await tools.execute(toolCall.name, toolCall.arguments);

        yield AgentEvent.toolResult(name: toolCall.name, result: result);

        // Add tool result to history
        session.addMessage(Message(
          role: 'tool',
          content: result.content,
          toolCallId: toolCall.id,
        ));
      }
    }

    yield AgentEvent.error('Max iterations reached');
  }
}

/// Events emitted by the agent loop (for UI)
sealed class AgentEvent {
  const AgentEvent();

  factory AgentEvent.thinking({required int iteration}) = ThinkingEvent;
  factory AgentEvent.response({required String content, UsageInfo? usage}) = ResponseEvent;
  factory AgentEvent.toolCall({required String name, required Map<String, dynamic> arguments}) = ToolCallEvent;
  factory AgentEvent.toolResult({required String name, required ToolResult result}) = ToolResultEvent;
  factory AgentEvent.error(String message) = ErrorEvent;
}

class ThinkingEvent extends AgentEvent {
  final int iteration;
  const ThinkingEvent({required this.iteration});
}

class ResponseEvent extends AgentEvent {
  final String content;
  final UsageInfo? usage;
  const ResponseEvent({required this.content, this.usage});
}

class ToolCallEvent extends AgentEvent {
  final String name;
  final Map<String, dynamic> arguments;
  const ToolCallEvent({required this.name, required this.arguments});
}

class ToolResultEvent extends AgentEvent {
  final String name;
  final ToolResult result;
  const ToolResultEvent({required this.name, required this.result});
}

class ErrorEvent extends AgentEvent {
  final String message;
  const ErrorEvent(this.message);
}
```

### 4.4 Tool Registry

```dart
// lib/core/tools/tool.dart

class ToolResult {
  final String content;
  final bool isError;
  final bool isSilent;

  ToolResult({required this.content, this.isError = false, this.isSilent = false});

  factory ToolResult.error(String message) =>
      ToolResult(content: message, isError: true);

  factory ToolResult.silent(String content) =>
      ToolResult(content: content, isSilent: true);
}

abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters;

  Future<ToolResult> execute(Map<String, dynamic> arguments);

  ToolDefinition get definition => ToolDefinition(
    name: name,
    description: description,
    parameters: parameters,
  );
}

class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) => _tools[tool.name] = tool;
  void unregister(String name) => _tools.remove(name);

  List<ToolDefinition> getDefinitions() =>
      _tools.values.map((t) => t.definition).toList();

  Future<ToolResult> execute(String name, Map<String, dynamic> arguments) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult.error('Unknown tool: $name');
    }
    try {
      return await tool.execute(arguments);
    } catch (e) {
      return ToolResult.error('Tool $name error: $e');
    }
  }
}
```

### 4.5 Web Search Tool

```dart
// lib/core/tools/web_search_tool.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchTool extends Tool {
  final String? braveApiKey;
  final int maxResults;

  WebSearchTool({this.braveApiKey, this.maxResults = 5});

  @override
  String get name => 'web_search';

  @override
  String get description => 'Search the web for information';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': 'Search query'},
    },
    'required': ['query'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String;

    if (braveApiKey != null && braveApiKey!.isNotEmpty) {
      return _searchBrave(query);
    }
    return _searchDuckDuckGo(query);
  }

  Future<ToolResult> _searchBrave(String query) async {
    final uri = Uri.parse('https://api.search.brave.com/res/v1/web/search')
        .replace(queryParameters: {'q': query, 'count': '$maxResults'});

    final response = await http.get(uri, headers: {
      'X-Subscription-Token': braveApiKey!,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      return ToolResult.error('Brave search error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final results = (data['web']?['results'] as List?) ?? [];

    final buffer = StringBuffer();
    for (final result in results.take(maxResults)) {
      buffer.writeln('Title: ${result['title']}');
      buffer.writeln('URL: ${result['url']}');
      buffer.writeln('Description: ${result['description'] ?? 'N/A'}');
      buffer.writeln();
    }

    return ToolResult(content: buffer.toString());
  }

  Future<ToolResult> _searchDuckDuckGo(String query) async {
    final uri = Uri.parse('https://api.duckduckgo.com/')
        .replace(queryParameters: {'q': query, 'format': 'json', 'no_html': '1'});

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return ToolResult.error('DuckDuckGo search error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final buffer = StringBuffer();

    if (data['Abstract'] != null && (data['Abstract'] as String).isNotEmpty) {
      buffer.writeln('Summary: ${data['Abstract']}');
      buffer.writeln('Source: ${data['AbstractURL']}');
      buffer.writeln();
    }

    final relatedTopics = data['RelatedTopics'] as List? ?? [];
    for (final topic in relatedTopics.take(maxResults)) {
      if (topic is Map && topic.containsKey('Text')) {
        buffer.writeln('- ${topic['Text']}');
        if (topic['FirstURL'] != null) buffer.writeln('  URL: ${topic['FirstURL']}');
      }
    }

    return ToolResult(content: buffer.toString());
  }
}
```

---

## 5. Flutter Dependencies (pubspec.yaml)

```yaml
name: picoclaw
description: Ultra-lightweight personal AI assistant
version: 1.0.0

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # HTTP & Networking
  http: ^1.2.0
  dio: ^5.4.0               # Richer alternative to http

  # State Management (choose one)
  flutter_riverpod: ^2.5.0   # Recommended for reactivity
  # OR
  # flutter_bloc: ^8.1.0

  # Storage
  shared_preferences: ^2.2.0   # Simple config
  path_provider: ^2.1.0        # Sandboxed filesystem access
  hive: ^4.0.0                 # Lightweight NoSQL database (sessions, memory)

  # UI
  flutter_markdown: ^0.7.0     # Markdown rendering in chat
  flutter_highlight: ^0.7.0    # Syntax highlighting in code

  # Auth
  flutter_secure_storage: ^9.0.0  # Secure storage for API keys
  flutter_appauth: ^7.0.0         # OAuth PKCE (if OpenAI login)

  # Voice
  speech_to_text: ^7.0.0       # Native Android STT
  # OR for Groq STT:
  record: ^5.1.0               # Audio recording

  # Notifications & Background
  flutter_local_notifications: ^17.0.0
  workmanager: ^0.5.2          # Background tasks (cron)

  # Utils
  uuid: ^4.3.0
  intl: ^0.19.0
  url_launcher: ^6.2.0
  connectivity_plus: ^6.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.0
  freezed: ^2.5.0              # Immutable class generation
  json_serializable: ^6.8.0
```

---

## 6. Complete Go → Dart Mapping

### Conversion patterns

| Go Pattern | Dart Equivalent |
|---|---|
| `goroutine` + `chan` | `Stream` + `StreamController` or `Isolate` |
| `context.Context` | Custom `CancellationToken` or timeout on `Future` |
| `sync.Mutex` / `sync.Map` | Not necessary (single-threaded) except with `Isolate` |
| `interface{}` | `dynamic` or `Object?` |
| `embed.FS` | `rootBundle` (Flutter assets) |
| `os.Signal` | `AppLifecycleState` in Flutter |
| `http.Server` | Not necessary (mobile app) |
| `filepath.Walk` | `Directory.list(recursive: true)` |
| `json.Marshal/Unmarshal` | `jsonEncode/jsonDecode` |
| `fmt.Sprintf` | String interpolation `'$var'` or `'${expr}'` |
| `error` return | `throw Exception` or `Result<T, E>` pattern |
| `struct` | `class` with named constructor |
| `map[string]interface{}` | `Map<String, dynamic>` |

### File by file

| Go File | Target Dart File | Notes |
|---|---|---|
| `pkg/providers/types.go` | `core/providers/llm_response.dart` | Direct, 1:1 |
| `pkg/providers/http_provider.go` | `core/providers/http_provider.dart` | Use `package:http` |
| `pkg/providers/claude_provider.go` | `core/providers/anthropic_provider.dart` | Anthropic-specific API |
| `pkg/providers/tool_call_extract.go` | Integrated into each provider | Tool call parsing |
| `pkg/agent/loop.go` | `core/agent/agent_loop.dart` | Stream instead of callback |
| `pkg/agent/context.go` | `core/agent/context_builder.dart` | Flutter asset loading |
| `pkg/agent/memory.go` | `core/agent/memory_manager.dart` | Storage via Hive |
| `pkg/tools/base.go` | `core/tools/tool.dart` | Interface + registry |
| `pkg/tools/web.go` | `core/tools/web_search_tool.dart` | Pure HTTP |
| `pkg/tools/filesystem.go` | `core/tools/file_tool.dart` | Scoped to app dir |
| `pkg/config/config.go` | `core/config/app_config.dart` | `json_serializable` |
| `pkg/session/manager.go` | `core/session/session_manager.dart` | Hive for persistence |
| `pkg/skills/loader.go` | `core/skills/skill_loader.dart` | Assets + download |
| `pkg/bus/bus.go` | Replaced by Riverpod/Streams | — |
| `pkg/channels/*` | Replaced by `features/chat/` | Flutter UI = the only channel |
| `pkg/cron/service.go` | `WorkManager` integration | Android background tasks |
| `pkg/auth/oauth.go` | `flutter_appauth` | Mobile OAuth |
| `pkg/auth/store.go` | `flutter_secure_storage` | Android Keychain |
| `pkg/voice/transcriber.go` | `features/voice/voice_input.dart` | `speech_to_text` or Groq HTTP |
| `pkg/health/server.go` | **Remove** | No HTTP server |
| `pkg/heartbeat/service.go` | **Remove** or `WorkManager` | Optional |
| `pkg/devices/*` | **Remove** | USB monitoring not relevant |
| `pkg/migrate/*` | **Remove** | No migration |

---

## 7. Implementation Plan (recommended order)

### Phase 1: Foundations (2-3 days)
1. **Create Flutter project**: `flutter create picoclaw --platforms android`
2. **Config**: Convert `config.go` → `app_config.dart` with `json_serializable`
3. **Provider Types**: `types.go` → `llm_response.dart`
4. **HTTP Provider**: `http_provider.go` → `http_provider.dart`
5. **Test**: Verify a simple API call to OpenRouter

### Phase 2: Agent Core (3-4 days)
6. **Tool abstraction**: `Tool` interface, `ToolRegistry`, `ToolResult`
7. **Web Search**: Convert `web.go` → `web_search_tool.dart`
8. **Web Fetch**: Convert the fetch part of `web.go`
9. **Session Manager**: Convert `session/manager.go` with Hive
10. **Context Builder**: Convert `context.go`
11. **Agent Loop**: Convert `loop.go` to Stream-based
12. **Test**: Complete conversation with tool calling

### Phase 3: Flutter UI (3-4 days)
13. **Chat screen**: Message bubbles, scroll, markdown
14. **Input bar**: Text input + send button
15. **Settings**: API keys and model configuration
16. **Onboarding**: First launch, API key entry
17. **Agent state**: Display thinking/tool calls live

### Phase 4: Polish (2-3 days)
18. **Skills**: Loader from assets or download
19. **Voice**: Voice input (optional)
20. **Secure storage**: API keys in flutter_secure_storage
21. **Theme**: Material 3, dark mode
22. **Build APK**: `flutter build apk --release`

---

## 8. Commands to Get Started

```bash
# Create project
flutter create picoclaw --platforms android
cd picoclaw

# Add dependencies
flutter pub add http shared_preferences path_provider hive \
  flutter_secure_storage uuid flutter_markdown flutter_riverpod \
  connectivity_plus

flutter pub add --dev build_runner json_serializable freezed flutter_lints

# Structure
mkdir -p lib/core/{config,providers,agent,tools,session,skills}
mkdir -p lib/features/{chat,settings,onboarding,voice}
mkdir -p lib/data/{repositories,local}
mkdir -p lib/shared/utils

# Build APK
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. Points of Attention

### Go Concurrency → Dart
Go uses goroutines everywhere. In Dart/Flutter, the model is single-threaded with `Future`/`Stream`. HTTP calls are already async. For heavy computation (parsing large JSON), use `compute()` or `Isolate`.

### APK Size
Go produces a ~10MB binary. The Flutter APK will be ~15-25MB in release (includes Flutter engine). This is acceptable for Android.

### API Key Security
Never store API keys in plain text. Use `flutter_secure_storage` which uses the Android Keystore.

### Network Management
Add `connectivity_plus` to detect network status and gracefully handle offline mode (display cached sessions, disable sending).

### Anthropic Provider
The Anthropic API uses a slightly different format from OpenAI (`messages` API with `type: "tool_use"` instead of `tool_calls`). A dedicated provider will be needed, not just the generic HTTP provider.
