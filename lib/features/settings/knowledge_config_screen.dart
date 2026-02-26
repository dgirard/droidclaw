import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../shared/constants.dart';

/// Settings screen for the Knowledge Graph.
///
/// Allows enabling/disabling, toggling auto-extract,
/// viewing stats, and forgetting all knowledge.
class KnowledgeConfigScreen extends ConsumerStatefulWidget {
  const KnowledgeConfigScreen({super.key});

  @override
  ConsumerState<KnowledgeConfigScreen> createState() =>
      _KnowledgeConfigScreenState();
}

class _KnowledgeConfigScreenState
    extends ConsumerState<KnowledgeConfigScreen> {
  int? _entityCount;
  int? _relationCount;
  int? _dbSizeBytes;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final config = ref.read(appConfigProvider);
    if (!config.knowledge.enabled) return;

    setState(() => _loadingStats = true);

    try {
      final kgService = await ref.read(knowledgeServiceProvider.future);
      if (kgService == null) return;

      final storage = ref.read(storageServiceProvider);
      final workspacePath = await storage.workspacePath;
      final dbPath = p.join(workspacePath, AppConstants.knowledgeDbFilename);

      final entities = await kgService.entityCount();
      final relations = await kgService.relationCount();
      final size = await kgService.databaseSize(dbPath);

      if (mounted) {
        setState(() {
          _entityCount = entities;
          _relationCount = relations;
          _dbSizeBytes = size;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final l = AppLocalizations.of(context);
    final enabled = config.knowledge.enabled;

    return Scaffold(
      appBar: AppBar(title: Text(l.knowledgeTitle)),
      body: ListView(
        children: [
          // Enable/disable toggle
          SwitchListTile(
            secondary: const Icon(Icons.psychology_outlined),
            title: Text(l.knowledgeEnable),
            subtitle: Text(l.knowledgeEnableDesc),
            value: enabled,
            onChanged: (value) => _toggleEnabled(value),
          ),

          if (enabled) ...[
            const Divider(),

            // Auto-extract toggle
            SwitchListTile(
              secondary: const Icon(Icons.auto_fix_high_outlined),
              title: Text(l.knowledgeAutoExtract),
              subtitle: Text(l.knowledgeAutoExtractDesc),
              value: config.knowledge.autoExtract,
              onChanged: (value) => _toggleAutoExtract(value),
            ),

            const Divider(),

            // Stats section
            if (_loadingStats)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entityCount != null) ...[
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: Text(l.knowledgeStatsEntities(_entityCount!)),
              ),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: Text(l.knowledgeStatsRelations(_relationCount ?? 0)),
              ),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(l.knowledgeStatsSize(_formatSize(_dbSizeBytes ?? 0))),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.knowledgeEmpty),
              ),

            // Browse button (only when entities > 0)
            if (_entityCount != null && _entityCount! > 0) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.explore_outlined),
                title: Text(l.knowledgeBrowse),
                subtitle: Text(l.knowledgeBrowseSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.pushNamed(
                      context, '/settings/knowledge-browser');
                  _loadStats();
                },
              ),
            ],

            const Divider(),

            // Forget everything
            ListTile(
              leading: Icon(Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: Text(l.knowledgeForgetAll,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              subtitle: Text(l.knowledgeForgetAllDesc),
              onTap: () => _confirmForgetAll(context),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleEnabled(bool value) {
    final config = ref.read(appConfigProvider);
    final newConfig = config.copyWith(
      knowledge: config.knowledge.copyWith(enabled: value),
    );
    ref.read(configStorageProvider).save(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);

    if (value) {
      // Reload stats after enabling
      Future.delayed(const Duration(milliseconds: 500), _loadStats);
    } else {
      setState(() {
        _entityCount = null;
        _relationCount = null;
        _dbSizeBytes = null;
      });
    }
  }

  void _toggleAutoExtract(bool value) {
    final config = ref.read(appConfigProvider);
    final newConfig = config.copyWith(
      knowledge: config.knowledge.copyWith(autoExtract: value),
    );
    ref.read(configStorageProvider).save(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);
  }

  Future<void> _confirmForgetAll(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.knowledgeForgetConfirmTitle),
        content: Text(l.knowledgeForgetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.knowledgeForgetConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final kgService = await ref.read(knowledgeServiceProvider.future);
        await kgService?.deleteAll();
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.knowledgeForgotten)),
          );
          _loadStats();
        }
      } catch (_) {}
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
