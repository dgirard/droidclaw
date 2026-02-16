# PicoClaw : Guide de Conversion Go → Flutter/Dart (Android APK)

## 1. Analyse du Projet Source

### Vue d'ensemble
PicoClaw est un assistant IA ultra-léger écrit en Go (~16K lignes hors tests) qui fonctionne en CLI/gateway sur des petits hardware Linux. L'objectif est d'en faire une **app Android native** en Flutter/Dart pur.

### Architecture Go actuelle (modules principaux)

| Package Go | Rôle | Lignes |
|---|---|---|
| `cmd/picoclaw/main.go` | CLI, commandes (agent, gateway, onboard, cron, skills, auth) | ~1400 |
| `pkg/agent/loop.go` | Boucle agentique : system prompt → LLM → tool calls → itération | ~780 |
| `pkg/agent/context.go` | Construction du contexte (system prompt, mémoire, skills) | ~200 |
| `pkg/agent/memory.go` | Gestion mémoire conversationnelle | ~150 |
| `pkg/providers/*` | Abstraction LLM (Anthropic, OpenAI, OpenRouter, Gemini, vLLM…) | ~2200 |
| `pkg/channels/*` | Canaux messaging (Telegram, Discord, Slack, WhatsApp, DingTalk…) | ~3500 |
| `pkg/tools/*` | Outils agent (filesystem, shell, web search, I2C, SPI, cron, subagent) | ~2800 |
| `pkg/config/` | Configuration JSON | ~440 |
| `pkg/session/` | Gestion sessions/historique | ~250 |
| `pkg/bus/` | Message bus interne (pub/sub) | ~150 |
| `pkg/cron/` | Tâches planifiées | ~500 |
| `pkg/auth/` | OAuth/PKCE + token store | ~900 |
| `pkg/skills/` | Loader et installeur de skills | ~500 |
| `pkg/heartbeat/` | Service heartbeat | ~365 |
| `pkg/state/` | State manager | ~250 |
| `pkg/voice/` | Transcription vocale (Groq) | ~160 |

---

## 2. Stratégie de Conversion

### Ce qu'il faut GARDER (cœur de l'app)
- **Agent Loop** : la boucle agentique (LLM → tool calls → itération)
- **Providers** : abstraction multi-LLM (Anthropic, OpenAI, OpenRouter…)
- **Tools** : web search, web fetch (les plus utiles sur mobile)
- **Config** : gestion de configuration
- **Session/Memory** : historique de conversation
- **Skills** : chargement de skills

### Ce qu'il faut ADAPTER
- **Channels** → remplacé par l'UI Flutter (un seul "channel" : l'écran de chat)
- **Bus** → remplacé par des Streams Dart ou Riverpod/Bloc
- **Auth** → OAuth mobile via `flutter_appauth` ou `url_launcher`
- **Storage** → `shared_preferences` + fichiers locaux via `path_provider`
- **Cron** → `workmanager` pour tâches en arrière-plan Android

### Ce qu'il faut SUPPRIMER
- **Shell/Exec tool** : pas d'exécution shell sur Android
- **Filesystem tools** : limités au sandboxing Android (adapter avec scoped storage)
- **I2C/SPI tools** : hardware Linux uniquement
- **Device monitoring USB** : non pertinent sur Android
- **Health server HTTP** : pas nécessaire pour une app mobile
- **Migration OpenClaw** : pas pertinent
- **Gateway/CLI** : remplacé par l'UI Flutter

---

## 3. Architecture Flutter Cible

```
lib/
├── main.dart                    # Point d'entrée
├── app.dart                     # MaterialApp, routing, thème
│
├── core/
│   ├── config/
│   │   ├── app_config.dart      # ← pkg/config/config.go
│   │   └── config_storage.dart  # Persistence JSON locale
│   │
│   ├── providers/               # ← pkg/providers/
│   │   ├── llm_provider.dart    # Interface abstraite LLMProvider
│   │   ├── llm_response.dart    # Types : LLMResponse, ToolCall, Message
│   │   ├── http_provider.dart   # Provider générique OpenAI-compatible
│   │   ├── anthropic_provider.dart
│   │   ├── openai_provider.dart
│   │   ├── openrouter_provider.dart
│   │   └── provider_factory.dart
│   │
│   ├── agent/                   # ← pkg/agent/
│   │   ├── agent_loop.dart      # Boucle agentique principale
│   │   ├── context_builder.dart # Construction system prompt + context
│   │   └── memory_manager.dart  # Mémoire conversationnelle
│   │
│   ├── tools/                   # ← pkg/tools/ (sous-ensemble)
│   │   ├── tool.dart            # Interface Tool + ToolRegistry
│   │   ├── web_search_tool.dart # Recherche web (Brave/DuckDuckGo)
│   │   ├── web_fetch_tool.dart  # Fetch URL
│   │   └── file_tool.dart       # Lecture/écriture fichiers (sandboxed)
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
│   │   ├── chat_screen.dart     # Écran principal de chat
│   │   ├── chat_controller.dart # Logique métier (remplace bus + channel)
│   │   ├── message_bubble.dart  # Widget message
│   │   └── input_bar.dart       # Barre de saisie + micro
│   │
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── provider_config_screen.dart
│   │   └── skills_screen.dart
│   │
│   ├── onboarding/
│   │   └── onboard_screen.dart  # ← commande onboard
│   │
│   └── voice/
│       └── voice_input.dart     # STT via Groq ou speech_to_text
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

## 4. Conversion Module par Module

### 4.1 Types de base et Provider LLM

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
    // Gérer les 2 formats : OpenAI (function.name) et Anthropic (name)
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

**Interface Provider :**

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

### 4.3 Agent Loop (le cœur)

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

  /// Traite un message utilisateur et retourne la réponse finale.
  /// Gère la boucle tool-calling de manière itérative.
  Stream<AgentEvent> processMessage(String userMessage, String sessionKey) async* {
    final session = sessions.getOrCreate(sessionKey);

    // Construire le contexte (system prompt + skills + memory)
    final systemPrompt = contextBuilder.buildSystemPrompt();

    // Ajouter le message utilisateur à l'historique
    session.addMessage(Message(role: 'user', content: userMessage));

    // Boucle agentique
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

      // Pas de tool calls → réponse finale
      if (response.toolCalls.isEmpty) {
        session.addMessage(Message(role: 'assistant', content: response.content));
        yield AgentEvent.response(content: response.content, usage: response.usage);
        return;
      }

      // Ajouter la réponse assistant avec tool calls
      session.addMessage(Message(
        role: 'assistant',
        content: response.content,
        toolCalls: response.toolCalls,
      ));

      // Exécuter chaque tool call
      for (final toolCall in response.toolCalls) {
        yield AgentEvent.toolCall(name: toolCall.name, arguments: toolCall.arguments);

        final result = await tools.execute(toolCall.name, toolCall.arguments);

        yield AgentEvent.toolResult(name: toolCall.name, result: result);

        // Ajouter le résultat du tool à l'historique
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

/// Événements émis par l'agent loop (pour l'UI)
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

## 5. Dépendances Flutter (pubspec.yaml)

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
  dio: ^5.4.0               # Alternative plus riche à http

  # State Management (choisir un)
  flutter_riverpod: ^2.5.0   # Recommandé pour la réactivité
  # OU
  # flutter_bloc: ^8.1.0

  # Storage
  shared_preferences: ^2.2.0   # Config simple
  path_provider: ^2.1.0        # Accès filesystem sandboxé
  hive: ^4.0.0                 # Base NoSQL légère (sessions, mémoire)

  # UI
  flutter_markdown: ^0.7.0     # Rendu Markdown dans le chat
  flutter_highlight: ^0.7.0    # Syntax highlighting dans le code

  # Auth
  flutter_secure_storage: ^9.0.0  # Stockage sécurisé des API keys
  flutter_appauth: ^7.0.0         # OAuth PKCE (si login OpenAI)

  # Voice
  speech_to_text: ^7.0.0       # STT natif Android
  # OU pour Groq STT :
  record: ^5.1.0               # Enregistrement audio
  
  # Notifications & Background
  flutter_local_notifications: ^17.0.0
  workmanager: ^0.5.2          # Tâches en arrière-plan (cron)

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
  freezed: ^2.5.0              # Génération de classes immuables
  json_serializable: ^6.8.0
```

---

## 6. Mapping Complet Go → Dart

### Patterns de conversion

| Pattern Go | Équivalent Dart |
|---|---|
| `goroutine` + `chan` | `Stream` + `StreamController` ou `Isolate` |
| `context.Context` | `CancellationToken` custom ou timeout sur `Future` |
| `sync.Mutex` / `sync.Map` | Pas nécessaire (single-threaded) sauf avec `Isolate` |
| `interface{}` | `dynamic` ou `Object?` |
| `embed.FS` | `rootBundle` (assets Flutter) |
| `os.Signal` | `AppLifecycleState` dans Flutter |
| `http.Server` | Pas nécessaire (app mobile) |
| `filepath.Walk` | `Directory.list(recursive: true)` |
| `json.Marshal/Unmarshal` | `jsonEncode/jsonDecode` |
| `fmt.Sprintf` | String interpolation `'$var'` ou `'${expr}'` |
| `error` return | `throw Exception` ou `Result<T, E>` pattern |
| `struct` | `class` avec constructeur nommé |
| `map[string]interface{}` | `Map<String, dynamic>` |

### Fichier par fichier

| Fichier Go | Fichier Dart cible | Notes |
|---|---|---|
| `pkg/providers/types.go` | `core/providers/llm_response.dart` | Direct, 1:1 |
| `pkg/providers/http_provider.go` | `core/providers/http_provider.dart` | Utiliser `package:http` |
| `pkg/providers/claude_provider.go` | `core/providers/anthropic_provider.dart` | API Anthropic spécifique |
| `pkg/providers/tool_call_extract.go` | Intégré dans chaque provider | Parsing tool calls |
| `pkg/agent/loop.go` | `core/agent/agent_loop.dart` | Stream au lieu de callback |
| `pkg/agent/context.go` | `core/agent/context_builder.dart` | Chargement assets Flutter |
| `pkg/agent/memory.go` | `core/agent/memory_manager.dart` | Stockage via Hive |
| `pkg/tools/base.go` | `core/tools/tool.dart` | Interface + registry |
| `pkg/tools/web.go` | `core/tools/web_search_tool.dart` | HTTP pur |
| `pkg/tools/filesystem.go` | `core/tools/file_tool.dart` | Scoped au app dir |
| `pkg/config/config.go` | `core/config/app_config.dart` | `json_serializable` |
| `pkg/session/manager.go` | `core/session/session_manager.dart` | Hive pour persistence |
| `pkg/skills/loader.go` | `core/skills/skill_loader.dart` | Assets + téléchargement |
| `pkg/bus/bus.go` | Remplacé par Riverpod/Streams | — |
| `pkg/channels/*` | Remplacé par `features/chat/` | UI Flutter = le seul channel |
| `pkg/cron/service.go` | `WorkManager` integration | Background tasks Android |
| `pkg/auth/oauth.go` | `flutter_appauth` | OAuth mobile |
| `pkg/auth/store.go` | `flutter_secure_storage` | Keychain Android |
| `pkg/voice/transcriber.go` | `features/voice/voice_input.dart` | `speech_to_text` ou HTTP Groq |
| `pkg/health/server.go` | **Supprimer** | Pas de serveur HTTP |
| `pkg/heartbeat/service.go` | **Supprimer** ou `WorkManager` | Optionnel |
| `pkg/devices/*` | **Supprimer** | USB monitoring non pertinent |
| `pkg/migrate/*` | **Supprimer** | Pas de migration |

---

## 7. Plan d'Implémentation (ordre recommandé)

### Phase 1 : Fondations (2-3 jours)
1. **Créer le projet Flutter** : `flutter create picoclaw --platforms android`
2. **Config** : Convertir `config.go` → `app_config.dart` avec `json_serializable`
3. **Types Provider** : `types.go` → `llm_response.dart`
4. **HTTP Provider** : `http_provider.go` → `http_provider.dart`
5. **Test** : Vérifier un appel API simple à OpenRouter

### Phase 2 : Agent Core (3-4 jours)
6. **Tool abstraction** : Interface `Tool`, `ToolRegistry`, `ToolResult`
7. **Web Search** : Convertir `web.go` → `web_search_tool.dart`
8. **Web Fetch** : Convertir la partie fetch de `web.go`
9. **Session Manager** : Convertir `session/manager.go` avec Hive
10. **Context Builder** : Convertir `context.go`
11. **Agent Loop** : Convertir `loop.go` en Stream-based
12. **Test** : Conversation complète avec tool calling

### Phase 3 : UI Flutter (3-4 jours)
13. **Écran de chat** : Bulles de messages, scroll, markdown
14. **Input bar** : Saisie texte + bouton envoi
15. **Settings** : Configuration des API keys et du modèle
16. **Onboarding** : Premier lancement, saisie API key
17. **État de l'agent** : Afficher thinking/tool calls en live

### Phase 4 : Polish (2-3 jours)
18. **Skills** : Loader depuis assets ou téléchargement
19. **Voice** : Input vocal (optionnel)
20. **Stockage sécurisé** : API keys dans flutter_secure_storage
21. **Thème** : Material 3, mode sombre
22. **Build APK** : `flutter build apk --release`

---

## 8. Commandes pour Démarrer

```bash
# Créer le projet
flutter create picoclaw --platforms android
cd picoclaw

# Ajouter les dépendances
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

## 9. Points d'Attention

### Concurrence Go → Dart
Go utilise des goroutines partout. En Dart/Flutter, le modèle est single-threaded avec des `Future`/`Stream`. Les appels HTTP sont déjà async. Pour les calculs lourds (parsing de gros JSON), utiliser `compute()` ou `Isolate`.

### Taille de l'APK
Go produit un binaire de ~10MB. L'APK Flutter fera ~15-25MB en release (inclut le moteur Flutter). C'est acceptable pour Android.

### Sécurité des API Keys
Ne jamais stocker les API keys en clair. Utiliser `flutter_secure_storage` qui utilise le Keystore Android.

### Gestion réseau
Ajouter `connectivity_plus` pour détecter l'état réseau et gérer le mode offline gracieusement (afficher les sessions en cache, désactiver l'envoi).

### Provider Anthropic
L'API Anthropic utilise un format légèrement différent d'OpenAI (`messages` API avec `type: "tool_use"` au lieu de `tool_calls`). Il faudra un provider dédié, pas juste le HTTP provider générique.
