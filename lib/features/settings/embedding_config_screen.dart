import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/embedding_provider_factory.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';

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

  static const _providers = ['', 'gemini', 'openai', 'openrouter'];
  static const _dimensionOptions = [256, 512, 768, 1536, 3072];

  @override
  void initState() {
    super.initState();
    _loadConfig();
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
      _testResult = null;
    });
  }

  Future<void> _testEmbedding() async {
    final l = AppLocalizations.of(context);
    if (_provider.isEmpty) return;

    // Resolve API key
    final configStorage = ref.read(configStorageProvider);
    final String? apiKey;
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

    setState(() {
      _testing = true;
      _testResult = null;
      _testPassed = false;
    });

    try {
      final model = _modelController.text.trim();
      final provider = EmbeddingProviderFactory.create(
        providerName: _provider,
        apiKey: apiKey,
        dimensions: _dimensions,
      );

      final sw = Stopwatch()..start();
      final result = await provider.embed(
        texts: ['Hello world'],
        model: model,
        dimensions: _dimensions,
        taskType: _provider == 'gemini' ? 'RETRIEVAL_DOCUMENT' : null,
      );
      sw.stop();

      await provider.dispose();

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
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final configStorage = ref.read(configStorageProvider);

    // Save dedicated API key if enabled
    if (_useOwnApiKey) {
      await configStorage.setEmbeddingApiKey(_apiKeyController.text.trim());
    }

    // Update config
    final config = ref.read(appConfigProvider);
    final newConfig = config.copyWith(
      embedding: EmbeddingConfig(
        provider: _provider,
        model: _modelController.text.trim(),
        dimensions: _dimensions,
        useOwnApiKey: _useOwnApiKey,
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
              return DropdownMenuItem(
                value: p,
                child: Text(p.isEmpty
                    ? l.embeddingProviderNone
                    : p[0].toUpperCase() + p.substring(1)),
              );
            }).toList(),
            onChanged: _onProviderChanged,
          ),

          if (_provider.isNotEmpty) ...[
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

            const SizedBox(height: 24),

            // Test button
            FilledButton.tonal(
              onPressed: _testing ? null : _testEmbedding,
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
        ],
      ),
    );
  }
}
