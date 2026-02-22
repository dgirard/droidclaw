import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tools/directions_tool.dart';
import '../../core/tools/geocode_tool.dart';
import '../../core/tools/transit_tool.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';

/// Screen for configuring routing and transit API keys.
class RoutingConfigScreen extends ConsumerStatefulWidget {
  const RoutingConfigScreen({super.key});

  @override
  ConsumerState<RoutingConfigScreen> createState() =>
      _RoutingConfigScreenState();
}

class _RoutingConfigScreenState extends ConsumerState<RoutingConfigScreen> {
  final _orsKeyController = TextEditingController();
  final _sncfKeyController = TextEditingController();
  final _primKeyController = TextEditingController();
  bool _obscureOrs = true;
  bool _obscureSncf = true;
  bool _obscurePrim = true;

  bool _testingOrs = false;
  String? _orsTestResult;
  bool _testingGeocode = false;
  String? _geocodeTestResult;
  bool _testingSncf = false;
  String? _sncfTestResult;
  bool _testingPrim = false;
  String? _primTestResult;

  @override
  void initState() {
    super.initState();
    _loadCurrentKeys();
  }

  Future<void> _loadCurrentKeys() async {
    final configStorage = ref.read(configStorageProvider);
    final orsKey = await configStorage.getOrsApiKey() ?? '';
    final sncfKey = await configStorage.getSncfApiKey() ?? '';
    final primKey = await configStorage.getPrimApiKey() ?? '';
    setState(() {
      _orsKeyController.text = orsKey;
      _sncfKeyController.text = sncfKey;
      _primKeyController.text = primKey;
    });
  }

  @override
  void dispose() {
    _orsKeyController.dispose();
    _sncfKeyController.dispose();
    _primKeyController.dispose();
    super.dispose();
  }

  Future<void> _testOrs() async {
    final l = AppLocalizations.of(context);
    final apiKey = _orsKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _orsTestResult = l.commonEnterApiKey);
      return;
    }

    setState(() {
      _testingOrs = true;
      _orsTestResult = null;
    });

    try {
      final tool = DirectionsTool(apiKey: apiKey);
      final result = await tool.execute({
        'origin_lat': 48.8566,
        'origin_lon': 2.3522,
        'dest_lat': 48.8049,
        'dest_lon': 2.1204,
        'mode': 'car',
      });

      setState(() {
        _testingOrs = false;
        _orsTestResult = result.isError
            ? l.commonFailed(result.forUser)
            : 'Route OK! ${result.forUser}';
      });
    } catch (e) {
      setState(() {
        _testingOrs = false;
        _orsTestResult = l.commonFailed('$e');
      });
    }
  }

  Future<void> _testGeocode() async {
    final l = AppLocalizations.of(context);
    final apiKey = _orsKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _geocodeTestResult = l.commonEnterApiKey);
      return;
    }

    setState(() {
      _testingGeocode = true;
      _geocodeTestResult = null;
    });

    try {
      final tool = GeocodeTool(apiKey: apiKey);
      final result = await tool.execute({
        'address': 'Tour Eiffel, Paris',
        'max_results': 1,
      });

      setState(() {
        _testingGeocode = false;
        _geocodeTestResult = result.isError
            ? l.commonFailed(result.forUser)
            : 'Geocode OK! ${result.forUser}';
      });
    } catch (e) {
      setState(() {
        _testingGeocode = false;
        _geocodeTestResult = l.commonFailed('$e');
      });
    }
  }

  Future<void> _testSncf() async {
    final l = AppLocalizations.of(context);
    final apiKey = _sncfKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _sncfTestResult = l.commonEnterApiKey);
      return;
    }

    setState(() {
      _testingSncf = true;
      _sncfTestResult = null;
    });

    try {
      // Test: Paris Gare de Lyon → Lyon Part-Dieu
      final tool = TransitTool(sncfApiKey: apiKey);
      final result = await tool.execute({
        'origin_lat': 48.8448,
        'origin_lon': 2.3735,
        'dest_lat': 45.7606,
        'dest_lon': 4.8602,
      });

      setState(() {
        _testingSncf = false;
        _sncfTestResult = result.isError
            ? l.commonFailed(result.forUser)
            : 'Transit OK! ${result.forUser}';
      });
    } catch (e) {
      setState(() {
        _testingSncf = false;
        _sncfTestResult = l.commonFailed('$e');
      });
    }
  }

  Future<void> _testPrim() async {
    final l = AppLocalizations.of(context);
    final apiKey = _primKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _primTestResult = l.commonEnterApiKey);
      return;
    }

    setState(() {
      _testingPrim = true;
      _primTestResult = null;
    });

    try {
      // Test: Gare de Lyon → Chatelet (IDF-only)
      final tool = TransitTool(primApiKey: apiKey);
      final result = await tool.execute({
        'origin_lat': 48.8448,
        'origin_lon': 2.3735,
        'dest_lat': 48.8584,
        'dest_lon': 2.3474,
      });

      setState(() {
        _testingPrim = false;
        _primTestResult = result.isError
            ? l.commonFailed(result.forUser)
            : 'Transit OK! ${result.forUser}';
      });
    } catch (e) {
      setState(() {
        _testingPrim = false;
        _primTestResult = l.commonFailed('$e');
      });
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final configStorage = ref.read(configStorageProvider);

    await configStorage.setOrsApiKey(_orsKeyController.text.trim());
    await configStorage.setSncfApiKey(_sncfKeyController.text.trim());
    await configStorage.setPrimApiKey(_primKeyController.text.trim());

    ref.invalidate(toolRegistryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.routingSaved)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.routingTitle),
        actions: [
          TextButton(onPressed: _save, child: Text(l.routingSave)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- ORS Section ---
          Text(l.routingOrsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l.routingOrsDesc,
            style: subtitleStyle,
          ),
          const SizedBox(height: 12),
          _buildKeyField(
            controller: _orsKeyController,
            label: l.routingOrsKeyLabel,
            obscure: _obscureOrs,
            onToggle: () => setState(() => _obscureOrs = !_obscureOrs),
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            testing: _testingOrs,
            label: l.routingOrsTestRoute,
            onPressed: _testOrs,
          ),
          _buildTestResult(_orsTestResult),
          const SizedBox(height: 12),
          _buildTestButton(
            testing: _testingGeocode,
            label: l.routingOrsTestGeocode,
            onPressed: _testGeocode,
          ),
          _buildTestResult(_geocodeTestResult),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // --- SNCF Section ---
          Text(l.routingSncfTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l.routingSncfDesc,
            style: subtitleStyle,
          ),
          const SizedBox(height: 12),
          _buildKeyField(
            controller: _sncfKeyController,
            label: l.routingSncfKeyLabel,
            obscure: _obscureSncf,
            onToggle: () => setState(() => _obscureSncf = !_obscureSncf),
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            testing: _testingSncf,
            label: l.routingSncfTestTransit,
            onPressed: _testSncf,
          ),
          _buildTestResult(_sncfTestResult),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // --- PRIM Section ---
          Text(l.routingPrimTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l.routingPrimDesc,
            style: subtitleStyle,
          ),
          const SizedBox(height: 12),
          _buildKeyField(
            controller: _primKeyController,
            label: l.routingPrimKeyLabel,
            obscure: _obscurePrim,
            onToggle: () => setState(() => _obscurePrim = !_obscurePrim),
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            testing: _testingPrim,
            label: l.routingPrimTestTransit,
            onPressed: _testPrim,
          ),
          _buildTestResult(_primTestResult),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildKeyField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required bool testing,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonal(
      onPressed: testing ? null : onPressed,
      child: testing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }

  Widget _buildTestResult(String? result) {
    if (result == null) return const SizedBox.shrink();
    final isOk = result.contains('OK!');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOk
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          result,
          style: TextStyle(color: isOk ? Colors.green : Colors.red),
        ),
      ),
    );
  }
}
