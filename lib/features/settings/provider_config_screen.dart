import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/llm_response.dart';
import '../../core/providers/provider_factory.dart';
import '../../providers/app_providers.dart';
import '../../shared/constants.dart';

/// Screen for configuring LLM provider: API key, provider type, model.
class ProviderConfigScreen extends ConsumerStatefulWidget {
  const ProviderConfigScreen({super.key});

  @override
  ConsumerState<ProviderConfigScreen> createState() =>
      _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends ConsumerState<ProviderConfigScreen> {
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiBaseController = TextEditingController();
  String _selectedProvider = AppConstants.defaultProvider;
  bool _obscureApiKey = true;
  bool _testing = false;
  String? _testResult;

  static const _providers = ['openrouter', 'anthropic', 'openai', 'groq'];

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final config = ref.read(appConfigProvider);
    final configStorage = ref.read(configStorageProvider);
    final apiKey =
        await configStorage.getApiKey(config.agent.provider) ?? '';

    setState(() {
      _selectedProvider = config.agent.provider;
      _modelController.text = config.agent.model;
      _apiKeyController.text = apiKey;
      final providerConfig = config.providers[_selectedProvider];
      _apiBaseController.text = providerConfig?.apiBase ?? '';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _apiBaseController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final apiKey = _apiKeyController.text.trim();
      final model = _modelController.text.trim();
      final apiBase = _apiBaseController.text.trim();

      if (apiKey.isEmpty) {
        setState(() {
          _testResult = 'Please enter an API key';
          _testing = false;
        });
        return;
      }

      final providerConfig = ProviderConfig(
        apiBase: apiBase,
      );

      final provider = ProviderFactory.create(
        name: _selectedProvider,
        config: providerConfig,
        apiKey: apiKey,
        defaultModel: model.isNotEmpty ? model : null,
      );

      final response = await provider.chat(
        messages: [
          const Message(role: 'user', content: 'Say "hello" in one word.'),
        ],
        model: model.isNotEmpty ? model : provider.defaultModel,
        options: {'max_tokens': 50, 'temperature': 0},
      );

      setState(() {
        _testResult = 'Connection successful! Response: ${response.content}';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testResult = 'Connection failed: $e';
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    final configStorage = ref.read(configStorageProvider);
    final currentConfig = ref.read(appConfigProvider);

    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final apiBase = _apiBaseController.text.trim();

    // Save API key securely
    await configStorage.setApiKey(_selectedProvider, apiKey);

    // Update config
    final providers = Map<String, ProviderConfig>.from(currentConfig.providers);
    providers[_selectedProvider] = ProviderConfig(apiBase: apiBase);

    final newConfig = currentConfig.copyWith(
      agent: currentConfig.agent.copyWith(
        provider: _selectedProvider,
        model: model.isNotEmpty ? model : null,
      ),
      providers: providers,
    );

    await configStorage.save(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Config'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider selection
          DropdownButtonFormField<String>(
            initialValue: _selectedProvider,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
            ),
            items: _providers
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedProvider = value);
              }
            },
          ),

          const SizedBox(height: 16),

          // API Key
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Model
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model (optional)',
              hintText: 'e.g. claude-sonnet-4-20250514',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // API Base
          TextField(
            controller: _apiBaseController,
            decoration: const InputDecoration(
              labelText: 'API Base URL (optional)',
              hintText: 'Leave empty for default',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // Test connection
          FilledButton.tonal(
            onPressed: _testing ? null : _testConnection,
            child: _testing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test Connection'),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testResult!.startsWith('Connection successful')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('Connection successful')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

