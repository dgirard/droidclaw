import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../core/knowledge/services/ingestion_pipeline.dart';
import '../../core/session/session.dart';
import '../../core/session/session_manager.dart';
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
  bool _rebuildInProgress = false;
  bool _rebuildCancelled = false;
  int _rebuildCurrent = 0;
  int _rebuildTotal = 0;

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

            // KB language display (read-only)
            if (config.knowledge.kbLanguage != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l.knowledgeLanguageLabel),
                subtitle: Text(l.knowledgeLanguageLocked(
                    KnowledgeConfig.languageName(config.knowledge.kbLanguage!))),
              ),
            ],

            const Divider(),

            // Stats section
            if (_loadingStats)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entityCount != null && _entityCount! > 0) ...[
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

            // Rebuild from conversations
            ListTile(
              leading: Icon(_rebuildInProgress ? Icons.sync : Icons.replay),
              title: Text(l.knowledgeRebuild),
              subtitle: _rebuildInProgress
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _rebuildTotal > 0
                              ? _rebuildCurrent / _rebuildTotal
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(l.knowledgeRebuildProgress(
                            _rebuildCurrent, _rebuildTotal)),
                      ],
                    )
                  : Text(l.knowledgeRebuildDesc),
              trailing: _rebuildInProgress
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _rebuildCancelled = true),
                    )
                  : null,
              onTap: _rebuildInProgress ? null : () => _confirmRebuild(context),
            ),

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
    var kgConfig = config.knowledge.copyWith(enabled: value);

    // Set kbLanguage on first enable (when null)
    if (value && kgConfig.kbLanguage == null) {
      kgConfig = kgConfig.copyWith(kbLanguage: config.resolvedLocale);
    }

    final newConfig = config.copyWith(knowledge: kgConfig);
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

        // Reset kbLanguage so next enable sets a fresh language
        final config = ref.read(appConfigProvider);
        final newConfig = config.copyWith(
          knowledge: config.knowledge.copyWith(clearKbLanguage: true),
        );
        ref.read(configStorageProvider).save(newConfig);
        ref.read(appConfigProvider.notifier).update(newConfig);

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.knowledgeForgotten)),
          );
          _loadStats();
        }
      } catch (e) {
        print('[KG] deleteAll error: $e');
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmRebuild(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sessionManagerAsync = ref.read(sessionManagerProvider);
    final SessionManager sessionManager;
    switch (sessionManagerAsync) {
      case AsyncData(:final value):
        sessionManager = value;
      default:
        return; // Not loaded yet
    }
    final allSessions = sessionManager.getAllSessions();

    // Count pairs across all sessions
    int totalPairs = 0;
    int sessionCount = 0;
    for (final session in allSessions) {
      final pairs = IngestionPipeline.extractPairs(session.messages);
      final hasSummary =
          session.summary != null && session.summary!.isNotEmpty;
      final count = pairs.length + (hasSummary ? 1 : 0);
      if (count > 0) sessionCount++;
      totalPairs += count;
    }

    if (totalPairs == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.knowledgeRebuildEmpty)),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.knowledgeRebuildConfirmTitle),
        content:
            Text(l.knowledgeRebuildConfirmBody(totalPairs, sessionCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.knowledgeRebuild),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _runRebuild(allSessions, totalPairs);
    }
  }

  Future<void> _runRebuild(
      List<Session> sessions, int totalPairs) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pipeline = await ref.read(ingestionPipelineProvider.future);
    if (pipeline == null) return;

    setState(() {
      _rebuildInProgress = true;
      _rebuildCancelled = false;
      _rebuildCurrent = 0;
      _rebuildTotal = totalPairs;
    });

    int processed = 0;
    int failed = 0;

    for (final session in sessions) {
      if (_rebuildCancelled) break;

      // Process summary if present
      if (session.summary != null && session.summary!.isNotEmpty) {
        try {
          await pipeline.extractAndStore(
            userMessage: session.summary!,
            assistantResponse: '',
          );
          processed++;
        } catch (_) {
          failed++;
        }
        if (mounted) setState(() => _rebuildCurrent++);
        await Future.delayed(const Duration(seconds: 2));
      }

      // Process message pairs
      final pairs = IngestionPipeline.extractPairs(session.messages);
      for (final (userMsg, assistantMsg) in pairs) {
        if (_rebuildCancelled) break;
        try {
          await pipeline.extractAndStore(
            userMessage: userMsg,
            assistantResponse: assistantMsg,
          );
          processed++;
        } catch (_) {
          failed++;
        }
        if (mounted) setState(() => _rebuildCurrent++);
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (mounted) {
      setState(() => _rebuildInProgress = false);
      _loadStats();
    }

    messenger.showSnackBar(SnackBar(
      content: Text(_rebuildCancelled
          ? l.knowledgeRebuildCancelled(processed)
          : l.knowledgeRebuildComplete(processed, failed)),
    ));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
