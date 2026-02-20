import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tools/directions_tool.dart';
import '../../providers/app_providers.dart';

/// Screen for configuring the OpenRouteService API key.
class RoutingConfigScreen extends ConsumerStatefulWidget {
  const RoutingConfigScreen({super.key});

  @override
  ConsumerState<RoutingConfigScreen> createState() =>
      _RoutingConfigScreenState();
}

class _RoutingConfigScreenState extends ConsumerState<RoutingConfigScreen> {
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
    final key = await configStorage.getOrsApiKey() ?? '';
    setState(() {
      _apiKeyController.text = key;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testRoute() async {
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
      // Test with a short Paris → Versailles route
      final tool = DirectionsTool(apiKey: apiKey);
      final result = await tool.execute({
        'origin_lat': 48.8566,
        'origin_lon': 2.3522,
        'dest_lat': 48.8049,
        'dest_lon': 2.1204,
        'mode': 'car',
      });

      setState(() {
        _testing = false;
        if (result.isError) {
          _testResult = 'Failed: ${result.forUser}';
        } else {
          _testResult = 'Route OK! ${result.forUser}';
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

    await configStorage.setOrsApiKey(apiKey);

    // Force tool registry to rebuild with new key.
    ref.invalidate(toolRegistryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenRouteService API key saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routing'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Get a free API key at openrouteservice.org to enable '
            'car, bike, and walking route calculations.',
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
              labelText: 'OpenRouteService API Key',
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
            onPressed: _testing ? null : _testRoute,
            child: _testing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test Route (Paris → Versailles)'),
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testResult!.startsWith('Route OK')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('Route OK')
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
