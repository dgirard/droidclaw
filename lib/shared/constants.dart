/// App-wide constants and defaults for DroidClaw.
class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'DroidClaw';
  static const String appVersion = '1.0.0';

  // Agent defaults
  static const int maxToolIterations = 10;
  static const int defaultMaxTokens = 4096;
  static const double defaultTemperature = 0.7;

  // Summarization
  static const double summarizationThreshold = 0.75;
  static const int summarizationMessageCount = 20;
  static const int keepLastMessages = 4;

  // Shared HTTP retry policy (RetryingHttpClient)
  static const int httpMaxRetries = 2;
  static const int httpRetryBaseDelayMs = 500;

  /// Upper bound applied to a server-sent `Retry-After` header so a
  /// misbehaving server cannot stall a tool call for minutes.
  static const int httpRetryAfterCapSeconds = 30;

  /// Default per-attempt request timeout for [RetryingHttpClient]. A hung
  /// connection throws `TimeoutException` promptly instead of blocking the
  /// caller (e.g. the service-isolate cron) forever. A timeout is NOT
  /// retried — a hang is not a 429/5xx, and retrying a hung host doubles
  /// the stall.
  static const int httpRequestTimeoutSeconds = 30;

  /// Per-attempt request budget for LLM chat calls (long generations need
  /// more headroom than tool HTTP calls).
  static const int llmRequestTimeoutSeconds = 120;

  // Web tools
  static const int webSearchMaxResults = 5;
  static const int webFetchMaxChars = 50000;
  static const int webFetchMaxRedirects = 5;
  static const int webScrapeMaxChars = 15000;
  static const int webScrapeJsTimeoutSeconds = 30;

  // Session
  static const String defaultSessionKey = 'default';

  /// Reserved Hive key prefix for per-session metadata records in the
  /// `sessions` box (lazy load: list/history screens read these instead of
  /// decoding full message histories). Session keys must never start with it.
  static const String sessionMetaKeyPrefix = '__meta__:';

  /// Max characters of message/summary text kept in a session metadata
  /// preview (the History screen itself truncates further for display).
  static const int sessionPreviewMaxChars = 120;

  // Memory
  static const int recentDailyNoteDays = 3;

  // Storage keys
  static const String configKey = 'app_config';
  static const String onboardingCompleteKey = 'onboarding_complete';

  // Default provider settings
  static const String defaultProvider = 'openrouter';
  static const String defaultModel = 'anthropic/claude-sonnet-4-20250514';
  static const String openRouterApiBase = 'https://openrouter.ai/api/v1';
  static const String anthropicApiBase = 'https://api.anthropic.com/v1';
  static const String geminiApiBase = 'https://generativelanguage.googleapis.com/v1beta/openai';
  static const String anthropicVersion = '2023-06-01';

  // Telegram
  static const String telegramApiBase = 'https://api.telegram.org/bot';
  static const String telegramBotTokenKey = 'telegram_bot_token';
  static const String telegramBotEnabledKey = 'telegram_bot_enabled';
  static const String telegramBotOffsetKey = 'telegram_bot_offset';
  static const String telegramAllowedUsersKey = 'telegram_allowed_users';
  static const int telegramPollTimeout = 30;
  static const int telegramHttpTimeout = 35;
  static const int telegramMaxMessageLength = 4000;
  static const int telegramMaxConcurrentChats = 3;
  static const String telegramSessionPrefix = 'telegram_';

  // Cron
  static const String cronSessionPrefix = 'cron_';
  static const String cronDefinitionsKey = 'cron_definitions';
  static const String cronPendingTriggersKey = 'cron_pending_triggers';

  // LLM Trace
  static const int llmTraceMaxEntries = 500;
  static const int llmTraceRetentionHours = 24;

  // Knowledge Graph
  static const String knowledgeDbFilename = 'knowledge_graph.db';
  static const int knowledgeDecayHalfLifeDays = 30;
  static const int knowledgeMaxContextChars = 2000;

  /// Minimum cosine similarity for an entity embedding to enter the
  /// retrieval candidate pool (vector path of [queryRelevant]).
  static const double knowledgeVectorSimilarityThreshold = 0.5;

  /// Number of top-ranked candidates used to seed spreading activation.
  static const int knowledgeActivationSeedCount = 5;

  /// Page size for the keyset-paged embedding scan in the vector path of
  /// [KnowledgeService.queryRelevant]. The scan covers ALL active entity
  /// embeddings (U14 removed the silent 1000-row cap); this only bounds how
  /// many BLOBs are resident at once. Benchmark
  /// (tool/benchmark_cosine_scan.dart): the inline paged scan beats
  /// Isolate.run at 1K-5K entities because the isolate copy cost dominates
  /// the cosine math.
  static const int knowledgeEmbeddingScanPageSize = 500;

  /// Maximum entity ids per `IN (...)` chunk in batched KG queries. Keeps
  /// each statement far below SQLite's bind-variable limit even when the id
  /// list is bound twice (source/target sides of a relation).
  static const int knowledgeSqlInChunkSize = 1000;

  /// Maximum characters per KB-snapshot chunk sent to the LLM during a
  /// `dream` cleanup. Each chunk is a self-contained entity + relation
  /// markdown table (~4K tokens at 16K chars), so cleanup prompts stay
  /// within context bounds at several-thousand-entity scale. Chunk
  /// boundaries never split an entity row.
  static const int kbSnapshotChunkMaxChars = 16000;
  static const String cachedKnowledgeEnabledKey = 'cached_knowledge_enabled';
  static const String cachedKbLanguageKey = 'cached_kb_language';

  // FlutterSecureStorage key names (Keystore-backed store, main isolate —
  // and the service isolate too on devices where the capability probe passes).
  static const String secureApiKeyPrefix = 'api_key_';
  static const String secureBraveApiKeyKey = 'brave_api_key';
  static const String secureOrsApiKeyKey = 'ors_api_key';
  static const String secureSncfApiKeyKey = 'sncf_api_key';
  static const String securePrimApiKeyKey = 'prim_api_key';
  static const String secureEmbeddingApiKeyKey = 'embedding_api_key';

  // Capability probe: the main isolate writes a known value to secure storage;
  // the service isolate tries to read it back. On success it reads secrets
  // directly from secure storage and the cleartext mirrors are wiped.
  static const String secureStorageProbeKey = 'secure_storage_probe';
  static const String secureStorageProbeValue = 'probe_ok_v1';

  /// Non-secret flag written by the service isolate after its probe so the
  /// main isolate knows whether cleartext mirrors are still needed.
  static const String serviceSecureStorageCapableKey =
      'service_secure_storage_capable';

  // Cached secrets for service isolate (SharedPreferences mirror of SecureStorage)
  static const String cachedApiKeyKey = 'cached_api_key';
  static const String cachedProviderNameKey = 'cached_provider_name';
  static const String cachedBraveApiKeyKey = 'cached_brave_api_key';
  static const String cachedOrsApiKeyKey = 'cached_ors_api_key';
  static const String cachedSncfApiKeyKey = 'cached_sncf_api_key';
  static const String cachedPrimApiKeyKey = 'cached_prim_api_key';
  static const String cachedTelegramBotTokenKey = 'cached_telegram_bot_token';
  static const String cachedWorkspacePathKey = 'cached_workspace_path';
  static const String cachedLocaleKey = 'cached_locale';

  // Embedding provider
  static const String geminiEmbeddingApiBase =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String cachedEmbeddingApiKeyKey = 'cached_embedding_api_key';
  static const String cachedEmbeddingProviderKey = 'cached_embedding_provider';
  static const String cachedEmbeddingModelKey = 'cached_embedding_model';
  static const String cachedEmbeddingDimensionsKey =
      'cached_embedding_dimensions';
  static const String cachedEmbeddingApiBaseKey = 'cached_embedding_api_base';
  static const String cachedEmbeddingUseOwnKeyKey =
      'cached_embedding_use_own_key';

  // Dream (KB dedup)
  static const String lastDreamAtKey = 'last_dream_at';

  // KB dedup thresholds (U17 — values unchanged from kb_maintenance_service)

  /// Maximum active entities loaded per dedup scan (entity rows and
  /// embedding BLOBs alike).
  static const int dedupEntityScanLimit = 5000;

  /// Default cap on candidate pairs returned by `findCandidates`.
  static const int dedupMaxPairsDefault = 40;

  /// Facts loaded per entity for dedup fact scoring.
  static const int dedupFactsPerEntityLimit = 10;

  /// Token-blocked pairs whose embedding cosine similarity falls below this
  /// are discarded before scoring (embedding pre-filter).
  static const double dedupEmbeddingPrefilterMinSim = 0.5;

  /// Minimum cosine similarity for the embedding-only candidate discovery
  /// path (semantic synonyms that share no tokens).
  static const double dedupEmbeddingCandidateMinSim = 0.75;

  /// Minimum best name similarity for a token-blocked pair.
  static const double dedupNameFloor = 0.60;

  /// Relaxed name floor when one name is contained in the other
  /// (e.g. "Noé" ⊂ "Noé Girard").
  static const double dedupContainmentNameFloor = 0.20;

  /// Minimum normalized name length for containment to count (avoids noise).
  static const int dedupContainmentMinNameLength = 3;

  /// Composite score weights: name / relations / facts.
  static const double dedupNameWeight = 0.50;
  static const double dedupRelationWeight = 0.35;
  static const double dedupFactWeight = 0.15;

  /// Composite-score floor when the pair has relations or facts.
  static const double dedupCompositeThresholdStructured = 0.50;

  /// Name-score floor when neither entity has relations or facts.
  static const double dedupCompositeThresholdNameOnly = 0.60;

  /// Candidate pairs per LLM verification call, and max calls per run.
  static const int dedupVerifyBatchSize = 20;
  static const int dedupVerifyMaxBatches = 2;

  /// Entities scanned per duplicate-facts run.
  static const int dedupFactScanMaxEntities = 100;

  /// Minimum [DateSimilarity.score] for two date facts to be candidates.
  static const double dedupFactDateScoreMin = 0.7;

  /// Minimum string similarity for two same-key fact values to be candidates.
  static const double dedupFactStringScoreMin = 0.60;

  /// Entity fact bundles per cross-key LLM call, and deterministic fact
  /// candidates per verification call.
  static const int dedupFactBundleLimit = 10;
  static const int dedupFactVerifyBatchSize = 20;

  /// Score boundaries for pair level classification (1 = auto-merge zone).
  static const double dedupLevel1MinScore = 0.85;
  static const double dedupLevel2MinScore = 0.50;

  /// Fact-score blend: date-aware value match vs fact-key Jaccard.
  static const double dedupFactMatchWeight = 0.6;
  static const double dedupFactKeyJaccardWeight = 0.4;

  // Security: one-time wipe of cleartext secret mirrors that earlier versions
  // wrote to SharedPreferences and never cleared on key delete/rotate.
  static const String secretsCacheMigratedKey = 'secrets_cache_migrated_v1';

  // file tool: cap on a single write so the LLM cannot fill the workspace.
  static const int fileWriteMaxChars = 2000000;

  // Voice narration (U1 — TTS for voice-initiated turns, main isolate only)

  /// Max characters of a single narrated utterance (same cap as the speak
  /// tool — Android TTS rejects longer input).
  static const int ttsNarrationMaxChars = 5000;

  /// Errors are spoken briefly: cap on narrated error text.
  static const int ttsErrorNarrationMaxChars = 300;

  /// TTS speech rate (matches the speak tool).
  static const double ttsSpeechRate = 0.5;

  /// App locale code → BCP-47 tag for the platform TTS engine.
  static const Map<String, String> ttsLocaleTags = {
    'en': 'en-US',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'de': 'de-DE',
    'it': 'it-IT',
  };

  // Local embedding provider (U2 — EmbeddingGemma 308M ONNX, on-device)

  /// EmbeddingConfig.provider value selecting the on-device provider.
  static const String localEmbeddingProviderName = 'local';

  /// Provenance id stored alongside vectors produced by the local provider.
  static const String localEmbeddingProviderId =
      'local:embeddinggemma-300m-int8';

  /// Model identifier shown in config (also the on-disk model directory name).
  static const String localEmbeddingModelId = 'embeddinggemma-300m-int8';

  /// MRL-truncated output dimensionality of the local provider. EmbeddingGemma
  /// natively outputs 768 dims; Matryoshka truncation to 256 + L2 renorm is
  /// the documented efficient configuration (HF model card).
  static const int localEmbeddingDimensions = 256;

  /// Native (pre-truncation) output dimensionality of EmbeddingGemma.
  static const int localEmbeddingFullDimensions = 768;

  /// Max token ids fed to the encoder (EmbeddingGemma context length).
  static const int localEmbeddingMaxTokens = 2048;

  /// EmbeddingGemma prompt prefixes (HF model card,
  /// onnx-community/embeddinggemma-300m-ONNX "Usage" section):
  /// queries use "task: search result | query: ", documents use
  /// "title: none | text: ".
  static const String localEmbeddingQueryPrefix =
      'task: search result | query: ';
  static const String localEmbeddingDocumentPrefix = 'title: none | text: ';

  /// Latency thresholds (ms, median over the integrated benchmark) deciding
  /// the verdict for the local provider on this device:
  /// < [localEmbeddingLatencyGoodMs] → fast enough to be a default;
  /// < [localEmbeddingLatencyAcceptableMs] → acceptable as opt-in;
  /// above → offline fallback only.
  static const int localEmbeddingLatencyGoodMs = 150;
  static const int localEmbeddingLatencyAcceptableMs = 300;

  /// Integrated benchmark: warmup runs (excluded) + measured runs (median).
  static const int localEmbeddingBenchmarkWarmupRuns = 3;
  static const int localEmbeddingBenchmarkRuns = 20;

  // Model download manager (large cached assets, shared with future models)

  /// Root directory name for downloaded models. Lives NEXT TO the workspace
  /// (in the app documents dir), not inside it: DataWiper wipes workspace
  /// contents, and models are cached assets, not user data.
  static const String modelsDirName = 'droidclaw_models';

  /// SHA-256 placeholder marker: verification runs in log-only warn mode and
  /// prints the computed hash so it can be pinned here after the first
  /// verified download. A real (pinned) hash mismatch rejects the file.
  static const String modelSha256Placeholder =
      'TODO-pin-on-first-verified-download';

  // EmbeddingGemma int8 ONNX export — onnx-community/embeddinggemma-300m-ONNX.
  // int8 (model_quantized) preferred per HF discussion #15 (q4 exports target
  // transformers.js and may not load on ORT mobile); q4f16 is the alternate.
  static const String embeddingGemmaRepoBase =
      'https://huggingface.co/onnx-community/embeddinggemma-300m-ONNX/resolve/main';
  static const String embeddingGemmaModelFilename = 'model_quantized.onnx';
  static const String embeddingGemmaModelDataFilename =
      'model_quantized.onnx_data';
  static const String embeddingGemmaTokenizerFilename = 'tokenizer.json';
  static const String embeddingGemmaModelUrl =
      '$embeddingGemmaRepoBase/onnx/model_quantized.onnx';
  static const String embeddingGemmaModelDataUrl =
      '$embeddingGemmaRepoBase/onnx/model_quantized.onnx_data';
  static const String embeddingGemmaTokenizerUrl =
      '$embeddingGemmaRepoBase/tokenizer.json';

  // Exact sizes from the HF repo tree (used for download progress weighting
  // and the consent text).
  static const int embeddingGemmaModelBytes = 567874;
  static const int embeddingGemmaModelDataBytes = 308890624;
  static const int embeddingGemmaTokenizerBytes = 20323312;
  static const int embeddingGemmaTotalBytes = embeddingGemmaModelBytes +
      embeddingGemmaModelDataBytes +
      embeddingGemmaTokenizerBytes;

  // SHA-256 hashes — log-only until pinned (see modelSha256Placeholder).
  static const String embeddingGemmaModelSha256 = modelSha256Placeholder;
  static const String embeddingGemmaModelDataSha256 = modelSha256Placeholder;
  static const String embeddingGemmaTokenizerSha256 = modelSha256Placeholder;
}
