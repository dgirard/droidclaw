import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tools/web_search_tool.dart';
import '../../providers/app_providers.dart';

/// Screen for configuring the Brave Search API key.
class WebSearchConfigScreen extends ConsumerStatefulWidget {
  const WebSearchConfigScreen({super.key});

  @override
  ConsumerState<WebSearchConfigScreen> createState() =>
      _WebSearchConfigScreenState();
}

class _WebSearchConfigScreenState
    extends ConsumerState<WebSearchConfigScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  Future<void> _loadCurrentKey() async {
    final configStorage = ref.read(configStorageProvider);
    final key = await configStorage.getBraveApiKey() ?? '';
    setState(() {
      _apiKeyController.text = key;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testSearch() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _testResult = 'Please enter an API key');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final tool = WebSearchTool(braveApiKey: apiKey, maxResults: 3);
      final result = await tool.execute({'query': 'test search'});

      setState(() {
        _testing = false;
        if (result.isError) {
          _testResult = 'Failed: ${result.forUser}';
        } else {
          _testResult = 'Search successful! Results received.';
        }
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = 'Failed: $e';
      });
    }
  }

  Future<void> _save() async {
    final configStorage = ref.read(configStorageProvider);
    final apiKey = _apiKeyController.text.trim();

    await configStorage.setBraveApiKey(apiKey);

    // Force tool registry to rebuild with new key.
    ref.invalidate(toolRegistryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brave API key saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Search'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Web search works without a key using DuckDuckGo, '
            'but Brave Search gives faster, higher-quality results.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          const SizedBox(height: 24),

          // API Key
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              labelText: 'Brave Search API Key',
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

          const SizedBox(height: 24),

          // Test button
          FilledButton.tonal(
            onPressed: _testing ? null : _testSearch,
            child: _testing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test Search'),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testResult!.startsWith('Search successful')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('Search successful')
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
