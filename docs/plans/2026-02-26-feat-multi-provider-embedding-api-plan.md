---
title: Multi-Provider Remote Embedding API
type: feat
date: 2026-02-26
---

# Multi-Provider Remote Embedding API

## Overview

Add a multi-provider embedding abstraction layer to DroidClaw. The system lets users choose their embedding provider (Gemini, OpenAI, OpenRouter) and configure it from settings. This phase covers **only the embedding infrastructure** — KG integration (ingestion + retrieval) is Phase 2.

The KG codebase is already prepared: `embedding BLOB` columns exist on `entities`, `relations`, and `summary_nodes` tables, `HybridScorer` has full/degraded mode weights, and `KnowledgeService` has a `hasEmbedder` placeholder. This plan fills the missing piece: the actual embedding provider.

## Problem Statement

DroidClaw's Knowledge Graph uses BM25 (lexical search) which cannot bridge semantic gaps — e.g., querying "Where do I live?" won't match a stored fact "address: 9 rue la Paix". A workaround exists (LLM query expansion via `_expandQueryForKG()`), but embeddings are the proper solution. First, we need the provider infrastructure.

## Proposed Solution

Mirror the existing `LLMProvider` / `ProviderFactory` pattern with a parallel `EmbeddingProvider` / `EmbeddingProviderFactory` abstraction. Two concrete implementations: `GeminiEmbeddingProvider` (native Gemini REST API) and `OpenAIEmbeddingProvider` (OpenAI-compatible format for OpenAI, OpenRouter, Together AI). Both extend a shared `BaseCloudEmbeddingProvider` that centralizes HTTP retry logic. Config stored in `AppConfig.embedding`, API key in `FlutterSecureStorage`.

### Key Design Decision: Separate vs Reuse LLM API Key

The embedding provider may or may not be the same as the LLM provider. Three scenarios:

| Scenario | API Key | Example |
|---|---|---|
| Same provider as LLM | Reuse LLM key | User uses Gemini for chat + Gemini for embeddings |
| Different provider | Separate key | User uses Anthropic for chat + Gemini for embeddings (free tier) |
| OpenRouter for both | Reuse LLM key | OpenRouter supports both chat + embeddings |

**Solution**: `EmbeddingConfig.useOwnApiKey` boolean. When `false` (default), reuse the LLM provider's API key. When `true`, use a dedicated embedding API key stored separately.

**Recommended default**: Gemini `gemini-embedding-001` at 768 dimensions — free tier, high quality, no extra cost.

## Technical Approach

### Architecture

```
lib/core/providers/
├── llm_provider.dart                    # existing
├── anthropic_provider.dart              # existing
├── http_provider.dart                   # existing
├── provider_factory.dart                # existing
├── embedding_provider.dart              # NEW — interface + EmbeddingResult + base class
├── openai_embedding_provider.dart       # NEW — OpenAI/OpenRouter/Together
├── gemini_embedding_provider.dart       # NEW — native Gemini API
└── embedding_provider_factory.dart      # NEW — factory
```

### File-by-File Changes

#### New Files

**1. `lib/core/providers/embedding_provider.dart`** — Interface, result class, and base class with shared retry

```dart
/// Result of an embedding request.
class EmbeddingResult {
  final List<List<double>> embeddings;
  final int? promptTokens;
  const EmbeddingResult({required this.embeddings, this.promptTokens});
}

/// Abstract interface for embedding providers.
abstract class EmbeddingProvider {
  /// Embed one or more texts, returning one vector per input.
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  });

  /// Human-readable provider name for logging.
  String get providerName;

  /// Unique provider key stored alongside vectors for provenance tracking.
  String get providerId;

  /// Output vector dimensionality for this provider configuration.
  int get outputDimensions;

  /// Release HTTP client resources.
  Future<void> dispose();
}

/// Shared base class for cloud embedding providers.
/// Centralizes HTTP retry logic (max 2 retries, exponential backoff on 429/5xx).
abstract class BaseCloudEmbeddingProvider implements EmbeddingProvider {
  final String apiKey;
  final String apiBase;
  final http.Client _client = http.Client();

  BaseCloudEmbeddingProvider({required this.apiKey, required this.apiBase});

  /// Subclasses implement the actual HTTP call.
  Future<EmbeddingResult> callApi({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  });

  @override
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  }) async {
    const maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await callApi(
          texts: texts, model: model,
          dimensions: dimensions, taskType: taskType,
        );
      } on HttpRetryException catch (e) {
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * pow(2, attempt)));
      }
    }
    throw StateError('Unreachable');
  }

  /// Helper: POST with retry-eligible status code detection.
  Future<http.Response> post(Uri uri, Map<String, String> headers, String body) async {
    final response = await _client.post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw HttpRetryException(response.statusCode, response.body);
    }
    if (response.statusCode != 200) {
      throw EmbeddingApiException(response.statusCode, response.body);
    }
    return response;
  }

  @override
  Future<void> dispose() async => _client.close();
}

class HttpRetryException implements Exception {
  final int statusCode;
  final String body;
  const HttpRetryException(this.statusCode, this.body);
}

class EmbeddingApiException implements Exception {
  final int statusCode;
  final String body;
  const EmbeddingApiException(this.statusCode, this.body);
  @override
  String toString() => 'EmbeddingApiException($statusCode): $body';
}
```

**2. `lib/core/providers/openai_embedding_provider.dart`** — OpenAI-compatible

Extends `BaseCloudEmbeddingProvider`. Covers OpenAI, OpenRouter, Together AI.

- Endpoint: `POST $apiBase/embeddings`
- Auth: `Authorization: Bearer $apiKey`
- Body: `{"model": "...", "input": [...], "dimensions": N, "encoding_format": "float"}`
- Response: `data[i].embedding` (sorted by `index`)
- `providerId`: `'openai'`, `'openrouter'`, or `'together'` (passed at construction)

**3. `lib/core/providers/gemini_embedding_provider.dart`** — Native Gemini

Extends `BaseCloudEmbeddingProvider`. Two internal methods:

- Single: `POST $apiBase/models/$model:embedContent`
- Batch (2+ texts): `POST $apiBase/models/$model:batchEmbedContents`
- Auth: `x-goog-api-key: $apiKey` (NOT Bearer token)
- Body: `{"content": {"parts": [{"text": "..."}]}, "taskType": "...", "output_dimensionality": N}`
- Response: `embedding.values` (single) or `embeddings[i].values` (batch)
- **Important**: base URL is `generativelanguage.googleapis.com/v1beta` (NOT `.../v1beta/openai` used for chat)
- Supports `taskType` (RETRIEVAL_DOCUMENT, RETRIEVAL_QUERY, SEMANTIC_SIMILARITY)
- `providerId`: `'gemini'`

**4. `lib/core/providers/embedding_provider_factory.dart`** — Factory

```dart
class EmbeddingProviderFactory {
  EmbeddingProviderFactory._();

  static EmbeddingProvider create({
    required String providerName,
    required String apiKey,
    String? apiBase,
    int dimensions = 768,
  }) {
    final lower = providerName.toLowerCase();
    if (lower == 'gemini') {
      return GeminiEmbeddingProvider(
        apiKey: apiKey,
        apiBase: apiBase ?? AppConstants.geminiEmbeddingApiBase,
        dimensions: dimensions,
      );
    }
    return OpenAIEmbeddingProvider(
      apiKey: apiKey,
      apiBase: apiBase ?? _defaultApiBase(lower),
      providerId: lower,
      dimensions: dimensions,
    );
  }

  static String _defaultApiBase(String name) => switch (name) {
    'openai' => 'https://api.openai.com/v1',
    'openrouter' => 'https://openrouter.ai/api/v1',
    'together' => 'https://api.together.xyz/v1',
    _ => 'https://api.openai.com/v1',
  };

  static String defaultModel(String providerName) => switch (providerName.toLowerCase()) {
    'gemini' => 'gemini-embedding-001',
    'openai' => 'text-embedding-3-small',
    'openrouter' => 'openai/text-embedding-3-small',
    'together' => 'togethercomputer/m2-bert-80M-8k-retrieval',
    _ => 'text-embedding-3-small',
  };
}
```

Default models and dimensions per provider:

| Provider | Default Model | Default Dimensions | Max Dimensions |
|---|---|---|---|
| `gemini` | `gemini-embedding-001` | 768 | 3072 |
| `openai` | `text-embedding-3-small` | 768 | 1536 |
| `openrouter` | `openai/text-embedding-3-small` | 768 | 1536 |

**5. `lib/features/settings/embedding_config_screen.dart`** — Settings UI

- Provider dropdown: Gemini, OpenAI, OpenRouter, (disabled: None)
- Model text field (pre-filled with default per provider)
- Dimensions dropdown: 256, 512, 768, 1536, 3072
- "Use same API key as LLM" switch (default: on)
- Dedicated API key field (shown only when switch is off), with obscure toggle
- Test button: embeds "Hello world", shows vector length + response time in ms
- Save: updates `appConfigProvider` + caches for service isolate

#### Modified Files

**6. `lib/core/config/app_config.dart`** — Add `EmbeddingConfig`

```dart
class EmbeddingConfig {
  final String provider;     // 'gemini', 'openai', 'openrouter', '' (disabled)
  final String model;        // e.g. 'gemini-embedding-001'
  final int dimensions;      // e.g. 768
  final String apiBase;      // custom API base (empty = default)
  final bool useOwnApiKey;   // false = reuse LLM key

  const EmbeddingConfig({
    this.provider = '',
    this.model = '',
    this.dimensions = 768,
    this.apiBase = '',
    this.useOwnApiKey = false,
  });
  // + fromJson, toJson, copyWith
}
```

Add to `AppConfig`:

```dart
class AppConfig {
  final AgentConfig agent;
  final Map<String, ProviderConfig> providers;
  final ToolsConfig tools;
  final KnowledgeConfig knowledge;
  final EmbeddingConfig embedding;  // NEW
  final String locale;
  // ...
}
```

**7. `lib/shared/constants.dart`** — New constants

```dart
static const String geminiEmbeddingApiBase = 'https://generativelanguage.googleapis.com/v1beta';
static const String cachedEmbeddingApiKeyKey = 'cached_embedding_api_key';
static const String cachedEmbeddingProviderKey = 'cached_embedding_provider';
static const String cachedEmbeddingModelKey = 'cached_embedding_model';
static const String cachedEmbeddingDimensionsKey = 'cached_embedding_dimensions';
static const String cachedEmbeddingApiBaseKey = 'cached_embedding_api_base';
static const String cachedEmbeddingUseOwnKeyKey = 'cached_embedding_use_own_key';
```

**8. `lib/core/config/config_storage.dart`** — Add embedding API key getter/setter

```dart
Future<String?> getEmbeddingApiKey() => _storage.getSecure('embedding_api_key');
Future<void> setEmbeddingApiKey(String key) => _storage.setSecure('embedding_api_key', key);
```

**9. `lib/providers/app_providers.dart`** — New `embeddingProviderProvider`

```dart
final embeddingProviderProvider = FutureProvider<EmbeddingProvider?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (config.embedding.provider.isEmpty) return null;

  final configStorage = await ref.watch(configStorageProvider.future);
  final String? apiKey;
  if (config.embedding.useOwnApiKey) {
    apiKey = await configStorage.getEmbeddingApiKey();
  } else {
    apiKey = await configStorage.getApiKey(config.agent.provider);
  }
  if (apiKey == null || apiKey.isEmpty) return null;

  return EmbeddingProviderFactory.create(
    providerName: config.embedding.provider,
    apiKey: apiKey,
    apiBase: config.embedding.apiBase.isNotEmpty ? config.embedding.apiBase : null,
    dimensions: config.embedding.dimensions,
  );
});
```

Provider cascade becomes:

```
appConfigProvider → embeddingProviderProvider (NEW)
                 → toolRegistryProvider → contextBuilderProvider → agentLoopProvider
                 → llmProviderProvider ↗
```

**10. `lib/providers/background_service_provider.dart`** — Cache embedding secrets

In `_cacheSecretsForService()`, add:

```dart
final embeddingKey = await configStorage.getEmbeddingApiKey();
if (embeddingKey != null) {
  await prefs.setString(AppConstants.cachedEmbeddingApiKeyKey, embeddingKey);
}
await prefs.setString(AppConstants.cachedEmbeddingProviderKey, config.embedding.provider);
await prefs.setString(AppConstants.cachedEmbeddingModelKey, config.embedding.model);
await prefs.setInt(AppConstants.cachedEmbeddingDimensionsKey, config.embedding.dimensions);
await prefs.setString(AppConstants.cachedEmbeddingApiBaseKey, config.embedding.apiBase);
await prefs.setBool(AppConstants.cachedEmbeddingUseOwnKeyKey, config.embedding.useOwnApiKey);
```

**11. `lib/core/agent/service_agent_factory.dart`** — Accept embedding config, create `EmbeddingProvider`

Add parameters: `embeddingApiKey?`, `embeddingProvider`, `embeddingModel`, `embeddingDimensions`, `embeddingApiBase`, `embeddingUseOwnKey`. Instantiate `EmbeddingProvider` via factory if provider is configured. Store as field for Phase 2 KG integration.

**12. `lib/app.dart`** — Add route `/settings/embedding`

**13. `lib/features/settings/settings_screen.dart`** — Add ListTile for embedding config (under Knowledge section)

### API Format Comparison (for implementation reference)

| Aspect | Gemini | OpenAI / OpenRouter |
|---|---|---|
| Auth header | `x-goog-api-key: KEY` | `Authorization: Bearer KEY` |
| Endpoint | `/models/{model}:embedContent` | `/embeddings` |
| Model in | URL path | Body `"model"` field |
| Input | `{"content": {"parts": [{"text": "..."}]}}` | `{"input": "..." or ["...", "..."]}` |
| Batch | Separate `:batchEmbedContents` endpoint | Same endpoint, array `"input"` |
| Dimensions | `"output_dimensionality": N` | `"dimensions": N` |
| Task type | `"taskType": "RETRIEVAL_DOCUMENT"` | N/A |
| Response vector | `embeddings[i].values` or `embedding.values` | `data[i].embedding` |

### Pricing Reference

| Provider | Model | Free Tier | Cost/1M tokens |
|---|---|---|---|
| Gemini | gemini-embedding-001 | Yes (generous) | $0.15 |
| OpenAI | text-embedding-3-small | No | $0.02 |
| OpenAI | text-embedding-3-large | No | $0.13 |
| OpenRouter | varies | No | Proxied pricing |

## Acceptance Criteria

### Functional

- [x] `EmbeddingProvider` interface with `embed()`, `providerName`, `providerId`, `outputDimensions`, `dispose()`
- [x] `BaseCloudEmbeddingProvider` base class with shared HTTP retry logic (max 2 retries, exponential backoff on 429/5xx)
- [x] `GeminiEmbeddingProvider` implementation (single + batch, taskType support)
- [x] `OpenAIEmbeddingProvider` implementation (single + batch via array input)
- [x] `EmbeddingProviderFactory.create()` routing to correct provider + `defaultModel()` helper
- [x] `EmbeddingConfig` in `AppConfig` with `fromJson`/`toJson`/`copyWith`
- [x] Embedding API key in `FlutterSecureStorage` via `ConfigStorage`
- [x] `embeddingProviderProvider` Riverpod `FutureProvider` in provider cascade
- [x] Settings screen with provider dropdown, model field, dimensions, API key toggle, test button
- [x] Service isolate secret caching for embedding config
- [x] `ServiceAgentFactory` receives and creates embedding provider
- [x] `flutter analyze` passes with 0 issues

### Non-Functional

- [x] "Use same API key as LLM" works for Gemini, OpenAI, OpenRouter
- [x] Graceful `null` when no provider configured (downstream can check `hasEmbedder`)
- [x] HTTP retry on 429/5xx with exponential backoff (500ms, 1000ms)
- [x] 30s timeout on HTTP calls
- [x] Batch support: embed up to 100 texts in a single API call
- [x] `dispose()` called on provider when Riverpod rebuilds (via `ref.onDispose`)

### Edge Cases to Handle

- [x] No embedding provider configured → `embeddingProviderProvider` returns `null` → degraded mode (existing behavior)
- [x] "Use same key" but LLM provider has no key → `embeddingProviderProvider` returns `null`
- [x] User changes LLM provider → embedding provider using shared key rebuilds automatically (watches `appConfigProvider`)
- [x] Invalid API key → test button shows clear error message
- [x] Rate limit (429) → retry with backoff, surface error after retries exhausted
- [x] Network timeout → 30s timeout, clear error
- [x] Gemini `embedContent` vs `batchEmbedContents` — different response shapes handled correctly

## Phase 2: KG Integration (IMPLEMENTED)

Phase 2 integrates the embedding infrastructure into the Knowledge Graph pipeline:

- [x] **Vector storage**: Float32 little-endian BLOBs (`Float32List.fromList(v).buffer.asUint8List()`). `updateEntityEmbedding()` and `getActiveEntityEmbeddings()` methods in `KnowledgeGraphDB`.
- [x] **Ingestion pipeline**: `IngestionPipeline` computes embeddings after entity resolution (stage 2b). Texts formatted as `"Name (TYPE): summary"` for rich context. Uses `taskType: RETRIEVAL_DOCUMENT`. Errors logged but don't block ingestion.
- [x] **Retrieval**: `KnowledgeService.queryRelevant()` embeds query text (`taskType: RETRIEVAL_QUERY`), loads all active entity embeddings, computes cosine similarity (reuses `MemoryClusterer.cosineSimilarity()`), filters by threshold (>0.5), passes `vectorScores` to `HybridScorer.fuse()`.
- [x] **Full/degraded mode**: HybridScorer automatically uses full weights (0.30 BM25 + 0.30 vector + 0.25 activation + 0.15 decay) when vectorScores available, degrades gracefully when null.
- [x] **KnowledgeService refactored**: `hasEmbedder` bool replaced with `EmbeddingProvider?` + model/dimensions. `hasEmbedder` is now a getter.
- [x] **Riverpod wiring**: `knowledgeServiceProvider` watches `embeddingProviderProvider`, passes provider to KnowledgeService. `agentLoopProvider` passes provider to IngestionPipeline.
- [x] **Service isolate**: `ServiceAgentFactory` passes embedding provider to both `KnowledgeService` and `IngestionPipeline`. Cron-executed conversations get both vector search and embedding ingestion.

### Not yet implemented (future work)

- **Model provenance**: Track `providerId` + `dimensions` alongside each embedding BLOB for stale detection.
- **Dimension normalization**: Matryoshka truncation when provider returns more dimensions than configured.
- **Dimension change warning**: UI warning when changing model/dimensions after data is embedded.
- **Re-embedding**: Batch re-embed all existing entities when model/dimensions change.

## Dependencies & Risks

| Risk | Mitigation |
|---|---|
| Gemini embedding API format differs from chat endpoint | Separate `geminiEmbeddingApiBase` constant, dedicated provider class |
| User changes dimensions after data embedded | Phase 2 concern — warn in UI, track provenance |
| Groq has no embedding API | Not listed as option, clear in UI |
| Anthropic has no embedding API | Not listed as option |
| HTTP client leak on provider rebuild | `dispose()` via `ref.onDispose` in Riverpod provider |

## References

### Internal

- `lib/core/providers/provider_factory.dart` — existing LLM factory pattern to mirror
- `lib/core/providers/http_provider.dart` — retry logic pattern to follow
- `lib/core/config/app_config.dart:224-259` — `KnowledgeConfig` pattern for `EmbeddingConfig`
- `lib/core/config/config_storage.dart:39-64` — API key getter/setter pattern
- `lib/providers/background_service_provider.dart:153-206` — service isolate caching
- `lib/core/knowledge/algorithms/hybrid_scorer.dart:15-23` — full/degraded weights (Phase 2 consumer)
- `lib/core/knowledge/services/knowledge_service.dart:19` — `hasEmbedder` placeholder (Phase 2)
- `lib/core/knowledge/database/schema.drift:10,42,106` — existing `embedding BLOB` columns (Phase 2)
- `lib/features/settings/web_search_config_screen.dart` — simple API key screen pattern
- `lib/features/settings/provider_config_screen.dart` — provider selection screen pattern

### External

- [Gemini Embedding API](https://ai.google.dev/gemini-api/docs/embeddings) — REST docs
- [OpenAI Embeddings API](https://platform.openai.com/docs/api-reference/embeddings) — REST reference
- [OpenRouter Embeddings](https://openrouter.ai/docs/api/reference/embeddings) — OpenAI-compatible

### Learnings Applied

- `docs/solutions/architecture/decouple-cron-from-telegram-autonomous-service.md` — provider cascade pattern
- `docs/solutions/architecture/implement-i18n-with-dual-isolate-support.md` — config injection into service isolate
- `docs/solutions/architecture/enable-location-tools-in-service-isolate.md` — service isolate capabilities
- Expert analysis review — `BaseCloudEmbeddingProvider` base class, `providerId` provenance, `dispose()` lifecycle, `DimensionNormalizer` concept
