import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/log_entry.dart';
import '../../core/knowledge/services/embedding_backfill_service.dart';
import '../../core/providers/embedding_provider.dart';
import '../../core/providers/embedding_provider_factory.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/model_download_manager.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../shared/constants.dart';
import 'widgets/model_download_section.dart';

/// Screen for configuring the embedding provider.
class EmbeddingConfigScreen extends ConsumerStatefulWidget {
  const EmbeddingConfigScreen({super.key});

  @override
  ConsumerState<EmbeddingConfigScreen> createState() =>
      _EmbeddingConfigScreenState();
}

class _EmbeddingConfigScreenState
    extends ConsumerState<EmbeddingConfigScreen> {
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _testing = false;
  String? _testResult;
  bool _testPassed = false;

  String _provider = '';
  int _dimensions = 768;
  bool _useOwnApiKey = false;

  // Local (on-device) model state. The download status line / progress /
  // metered switch / download-cancel buttons live in the shared
  // [ModelDownloadSection]; this screen keeps only the manager (for the
  // benchmark's model dir) and the benchmark/delete extras.
  ModelDownloadManager? _modelManager;
  ModelStatus? _modelStatus;
  bool _benchmarkRunning = false;
  String? _benchmarkResult;

  // Versioned re-embed backfill (U3): manual "backfill now" with progress.
  // The service targets the SAVED provider config (not unsaved dropdown
  // changes) — the section is hidden when KG or the provider is off.
  EmbeddingBackfillService? _backfillService;
  BackfillProgress? _backfillProgress;
  bool _backfillRunning = false;

  static const _modelSpec = ModelSpec.embeddingGemmaInt8;

  static const _providers = [
    '',
    AppConstants.localEmbeddingProviderName,
    'gemini',
    'openai',
    'openrouter',
  ];
  static const _dimensionOptions = [256, 512, 768, 1536, 3072];

  /// Short realistic queries for the integrated latency benchmark.
  static const _benchmarkTexts = [
    'Where do I live?',
    'What is the weather tomorrow in Paris?',
    'Birthday of my sister',
    'Train schedule to Lyon',
  ];

  bool get _isLocal =>
      _provider == AppConstants.localEmbeddingProviderName;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _initModelManager();
    _refreshBackfillProgress();
  }

  void _loadConfig() {
    final config = ref.read(appConfigProvider);
    _provider = config.embedding.provider;
    _modelController.text = config.embedding.model;
    _dimensions = config.embedding.dimensions;
    _useOwnApiKey = config.embedding.useOwnApiKey;
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final configStorage = ref.read(configStorageProvider);
    final key = await configStorage.getEmbeddingApiKey() ?? '';
    if (mounted) {
      setState(() => _apiKeyController.text = key);
    }
  }

  Future<void> _initModelManager() async {
    final manager = await ref.read(modelDownloadManagerProvider.future);
    if (mounted) setState(() => _modelManager = manager);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onProviderChanged(String? value) {
    setState(() {
      _provider = value ?? '';
      if (_provider.isNotEmpty) {
        _modelController.text =
            EmbeddingProviderFactory.defaultModel(_provider);
      }
      if (_isLocal) {
        // The local provider's output space is fixed: 256-dim MRL.
        _dimensions = AppConstants.localEmbeddingDimensions;
        _useOwnApiKey = false;
      }
      _testResult = null;
      _benchmarkResult = null;
    });
  }

  Future<void> _testEmbedding() async {
    final l = AppLocalizations.of(context);
    if (_provider.isEmpty) return;

    String? apiKey;
    if (!_isLocal) {
      // Resolve API key (cloud providers only)
      final configStorage = ref.read(configStorageProvider);
      if (_useOwnApiKey) {
        apiKey = _apiKeyController.text.trim();
      } else {
        final config = ref.read(appConfigProvider);
        apiKey = await configStorage.getApiKey(config.agent.provider);
      }

      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _testResult = l.commonEnterApiKey;
          _testPassed = false;
        });
        return;
      }
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testPassed = false;
    });

    EmbeddingProvider? provider;
    try {
      final model = _modelController.text.trim();
      provider = EmbeddingProviderFactory.create(
        providerName: _provider,
        apiKey: apiKey,
        dimensions: _dimensions,
        localModelDir:
            _isLocal ? _modelManager?.modelDir(_modelSpec) : null,
      );

      final sw = Stopwatch()..start();
      final result = await provider.embed(
        texts: ['Hello world'],
        model: model,
        dimensions: _dimensions,
        taskType: (_provider == 'gemini' || _isLocal)
            ? 'RETRIEVAL_DOCUMENT'
            : null,
      );
      sw.stop();

      if (mounted) {
        setState(() {
          _testing = false;
          final dims = result.embeddings.first.length;
          _testResult = l.embeddingTestSuccess(dims, sw.elapsedMilliseconds);
          _testPassed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = l.commonFailed('$e');
          _testPassed = false;
        });
      }
    } finally {
      await provider?.dispose();
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final configStorage = ref.read(configStorageProvider);

    // Save dedicated API key if enabled
    if (!_isLocal && _useOwnApiKey) {
      await configStorage.setEmbeddingApiKey(_apiKeyController.text.trim());
    }

    // Update config
    final config = ref.read(appConfigProvider);
    final newConfig = config.copyWith(
      embedding: EmbeddingConfig(
        provider: _provider,
        model: _isLocal
            ? AppConstants.localEmbeddingModelId
            : _modelController.text.trim(),
        dimensions:
            _isLocal ? AppConstants.localEmbeddingDimensions : _dimensions,
        useOwnApiKey: _isLocal ? false : _useOwnApiKey,
      ),
    );

    await configStorage.save(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.embeddingSaved)),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _deleteModel() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.embeddingLocalDelete),
        content: Text(l.embeddingLocalDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.embeddingLocalDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _modelManager?.delete(_modelSpec);
      setState(() => _benchmarkResult = null);
    }
  }

  /// Integrated latency benchmark (U2 execution adaptation): the on-device
  /// latency spike runs here, after install, on the real hardware. Median
  /// over N short-text embeds after warmup, verdict against the 150/300 ms
  /// thresholds in AppConstants, logged prominently.
  Future<void> _runBenchmark() async {
    final l = AppLocalizations.of(context);
    final manager = _modelManager;
    if (manager == null) return;

    setState(() {
      _benchmarkRunning = true;
      _benchmarkResult = null;
    });

    EmbeddingProvider? provider;
    try {
      provider = EmbeddingProviderFactory.create(
        providerName: AppConstants.localEmbeddingProviderName,
        dimensions: AppConstants.localEmbeddingDimensions,
        localModelDir: manager.modelDir(_modelSpec),
      );

      for (var i = 0;
          i < AppConstants.localEmbeddingBenchmarkWarmupRuns;
          i++) {
        await provider.embed(
          texts: [_benchmarkTexts[i % _benchmarkTexts.length]],
          model: AppConstants.localEmbeddingModelId,
          taskType: 'RETRIEVAL_QUERY',
        );
      }

      final samples = <int>[];
      for (var i = 0; i < AppConstants.localEmbeddingBenchmarkRuns; i++) {
        final sw = Stopwatch()..start();
        await provider.embed(
          texts: [_benchmarkTexts[i % _benchmarkTexts.length]],
          model: AppConstants.localEmbeddingModelId,
          taskType: 'RETRIEVAL_QUERY',
        );
        sw.stop();
        samples.add(sw.elapsedMilliseconds);
      }

      samples.sort();
      final mid = samples.length ~/ 2;
      final median = samples.length.isEven
          ? ((samples[mid - 1] + samples[mid]) / 2).round()
          : samples[mid];

      final String verdict;
      if (median < AppConstants.localEmbeddingLatencyGoodMs) {
        verdict = l.embeddingLocalVerdictFast;
      } else if (median < AppConstants.localEmbeddingLatencyAcceptableMs) {
        verdict = l.embeddingLocalVerdictAcceptable;
      } else {
        verdict = l.embeddingLocalVerdictSlow;
      }

      AppLogger.instance.info(
          LogSource.app,
          'LOCAL EMBEDDING BENCHMARK VERDICT: median=${median}ms over '
          '${samples.length} runs (min=${samples.first}ms, '
          'max=${samples.last}ms; thresholds '
          '${AppConstants.localEmbeddingLatencyGoodMs}/'
          '${AppConstants.localEmbeddingLatencyAcceptableMs}ms) — $verdict');

      if (mounted) {
        setState(() {
          _benchmarkResult =
              l.embeddingLocalBenchmarkResult(median, samples.length, verdict);
        });
      }
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, 'Local embedding benchmark failed: $e');
      if (mounted) {
        setState(() => _benchmarkResult = l.commonFailed('$e'));
      }
    } finally {
      await provider?.dispose();
      if (mounted) {
        setState(() => _benchmarkRunning = false);
      }
    }
  }

  /// Build the backfill service against the SAVED configuration (Drift KG
  /// db + the active embedding provider from the provider graph). Null when
  /// KG is disabled or no provider is configured.
  Future<EmbeddingBackfillService?> _createBackfillService() async {
    final db = await ref.read(knowledgeGraphDbProvider.future);
    final provider = await ref.read(embeddingProviderProvider.future);
    if (db == null || provider == null) return null;
    final config = ref.read(appConfigProvider);
    return EmbeddingBackfillService(
      db: db,
      provider: provider,
      embeddingModel: config.embedding.model,
    );
  }

  Future<void> _refreshBackfillProgress() async {
    try {
      final service = _backfillService ??= await _createBackfillService();
      if (service == null) return;
      final progress = await service.progress();
      if (mounted) setState(() => _backfillProgress = progress);
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, 'Backfill progress check failed: $e');
    }
  }

  Future<void> _runBackfill() async {
    final l = AppLocalizations.of(context);
    final service = _backfillService ??= await _createBackfillService();
    if (service == null) return;

    setState(() => _backfillRunning = true);
    try {
      await service.runToCompletion(onProgress: (progress) {
        if (mounted) setState(() => _backfillProgress = progress);
      });
      // Coverage may have flipped the query space: rebuild the downstream
      // KnowledgeService so it re-resolves (and logs) its selection.
      ref.invalidate(knowledgeServiceProvider);
    } catch (e) {
      AppLogger.instance
          .warning(LogSource.app, 'Manual embedding backfill failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.commonFailed('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _backfillRunning = false);
        await _refreshBackfillProgress();
      }
    }
  }

  void _cancelBackfill() => _backfillService?.cancel();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.embeddingTitle),
        actions: [
          TextButton(onPressed: _save, child: Text(l.embeddingSave)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.embeddingDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          const SizedBox(height: 24),

          // Provider dropdown
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: InputDecoration(
              labelText: l.embeddingProvider,
              border: const OutlineInputBorder(),
            ),
            items: _providers.map((p) {
              final String label;
              if (p.isEmpty) {
                label = l.embeddingProviderNone;
              } else if (p == AppConstants.localEmbeddingProviderName) {
                label = l.embeddingProviderLocal;
              } else {
                label = p[0].toUpperCase() + p.substring(1);
              }
              return DropdownMenuItem(value: p, child: Text(label));
            }).toList(),
            onChanged: _onProviderChanged,
          ),

          if (_isLocal) ..._buildLocalSection(l),

          if (_provider.isNotEmpty && !_isLocal) ...[
            const SizedBox(height: 16),

            // Model
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: l.embeddingModel,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Dimensions dropdown
            DropdownButtonFormField<int>(
              initialValue: _dimensions,
              decoration: InputDecoration(
                labelText: l.embeddingDimensions,
                border: const OutlineInputBorder(),
              ),
              items: _dimensionOptions.map((d) {
                return DropdownMenuItem(value: d, child: Text('$d'));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _dimensions = value);
              },
            ),

            const SizedBox(height: 16),

            // Use own API key switch
            SwitchListTile(
              title: Text(l.embeddingUseOwnApiKey),
              subtitle: Text(l.embeddingUseOwnApiKeySubtitle),
              value: _useOwnApiKey,
              onChanged: (value) =>
                  setState(() => _useOwnApiKey = value),
              contentPadding: EdgeInsets.zero,
            ),

            // Dedicated API key field (only when switch is on)
            if (_useOwnApiKey) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: l.embeddingApiKey,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),
            ],
          ],

          if (_provider.isNotEmpty) ...[
            const SizedBox(height: 24),

            // Test button (local: only meaningful once the model is ready)
            FilledButton.tonal(
              onPressed: (_testing ||
                      (_isLocal &&
                          _modelStatus?.state != ModelState.ready))
                  ? null
                  : _testEmbedding,
              child: _testing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.embeddingTestButton),
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testPassed
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testPassed ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ],

          if (_backfillProgress != null) ..._buildBackfillSection(l),
        ],
      ),
    );
  }

  /// Versioned re-embed backfill controls (U3): progress toward the saved
  /// provider's embedding space, manual run, cancel.
  List<Widget> _buildBackfillSection(AppLocalizations l) {
    final theme = Theme.of(context);
    final progress = _backfillProgress!;
    final complete = progress.isComplete && !_backfillRunning;

    return [
      const SizedBox(height: 24),
      Text(l.embeddingBackfillSection, style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        l.embeddingBackfillHint,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.sync,
            size: 20,
            color: complete
                ? Colors.green
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(complete
                ? l.embeddingBackfillComplete
                : l.embeddingBackfillStatus(progress.done, progress.total)),
          ),
        ],
      ),
      if (_backfillRunning) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value:
              progress.total > 0 ? progress.done / progress.total : null,
        ),
      ],
      if (!complete) ...[
        const SizedBox(height: 12),
        _backfillRunning
            ? OutlinedButton.icon(
                onPressed: _cancelBackfill,
                icon: const Icon(Icons.close),
                label: Text(l.embeddingBackfillCancel),
              )
            : FilledButton.tonalIcon(
                onPressed: _runBackfill,
                icon: const Icon(Icons.sync),
                label: Text(l.embeddingBackfillStart),
              ),
      ],
    ];
  }

  List<Widget> _buildLocalSection(AppLocalizations l) {
    final theme = Theme.of(context);

    return [
      const SizedBox(height: 16),
      Text(l.embeddingLocalSection, style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        l.embeddingLocalConsent,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text(
        l.embeddingLocalDimensionsNote,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),

      // Shared download UI (status line + progress + metered switch +
      // download/retry/cancel). Benchmark + delete are embedding-only and
      // injected into the same action row when the model is ready.
      ModelDownloadSection(
        spec: _modelSpec,
        manager: _modelManager,
        onStatusChanged: (status) =>
            setState(() => _modelStatus = status),
        extraButtonsBuilder: (context, state) => [
          if (state == ModelState.ready) ...[
            FilledButton.tonalIcon(
              onPressed: _benchmarkRunning ? null : _runBenchmark,
              icon: _benchmarkRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.speed),
              label: Text(l.embeddingLocalBenchmark),
            ),
            OutlinedButton.icon(
              onPressed: _deleteModel,
              icon: const Icon(Icons.delete_outline),
              label: Text(l.embeddingLocalDelete),
            ),
          ],
        ],
      ),

      if (_benchmarkResult != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_benchmarkResult!),
        ),
      ],
    ];
  }
}
