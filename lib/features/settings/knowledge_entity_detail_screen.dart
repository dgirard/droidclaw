import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/log_entry.dart';
import '../../core/knowledge/algorithms/memory_decay.dart';
import '../../core/knowledge/models/entity.dart';
import '../../core/services/app_logger.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';

/// Detail screen for a single Knowledge Graph entity.
class KnowledgeEntityDetailScreen extends ConsumerStatefulWidget {
  const KnowledgeEntityDetailScreen({super.key});

  @override
  ConsumerState<KnowledgeEntityDetailScreen> createState() =>
      _KnowledgeEntityDetailScreenState();
}

class _KnowledgeEntityDetailScreenState
    extends ConsumerState<KnowledgeEntityDetailScreen> {
  KnowledgeEntityDetail? _detail;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detail == null && _loading) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    final entityId = ModalRoute.of(context)!.settings.arguments as int;
    setState(() => _loading = true);

    try {
      final kgService = await ref.read(knowledgeServiceProvider.future);
      if (kgService == null) return;

      final detail = await kgService.getEntityDetail(entityId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteEntity(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.kgEntityDelete),
        content: Text(l.kgEntityDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final kgService = await ref.read(knowledgeServiceProvider.future);
        await kgService?.deactivateEntity(_detail!.entity.id!);
        messenger.showSnackBar(
          SnackBar(content: Text(l.kgEntityDeleted)),
        );
        navigator.pop();
      } catch (e) {
        // Keep the screen open so the user can retry; record the failure.
        AppLogger.instance.error(
            LogSource.app, 'Failed to deactivate entity: $e');
      }
    }
  }

  IconData _typeIcon(EntityType type) => switch (type) {
        EntityType.person => Icons.person_outline,
        EntityType.place => Icons.place_outlined,
        EntityType.organization => Icons.business_outlined,
        EntityType.event => Icons.event_outlined,
        EntityType.concept => Icons.lightbulb_outline,
        EntityType.date => Icons.calendar_today_outlined,
      };

  Color _tempColor(Temperature temp) => switch (temp) {
        Temperature.hot => Colors.red,
        Temperature.warm => Colors.orange,
        Temperature.cool => Colors.blue,
        Temperature.cold => Colors.grey,
      };

  String _formatEpoch(int? epoch) {
    if (epoch == null) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.kgBrowserTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.kgBrowserTitle)),
        body: Center(child: Text(l.kgBrowserEmpty)),
      );
    }

    final entity = _detail!.entity;
    final facts = _detail!.facts;
    final relations = _detail!.relations;
    final aliases = _detail!.aliases;

    return Scaffold(
      appBar: AppBar(
        title: Text(entity.name),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: theme.colorScheme.error),
            tooltip: l.kgEntityDelete,
            onPressed: () => _deleteEntity(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_typeIcon(entity.entityType),
                          size: 28, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entity.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _tempColor(entity.temperature)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          entity.temperature.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _tempColor(entity.temperature),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: 'Type', value: entity.entityType.label),
                  _InfoRow(label: 'ID', value: '${entity.id}'),
                  _InfoRow(
                      label: 'Created',
                      value: _formatEpoch(entity.createdAt)),
                  _InfoRow(
                      label: 'Last accessed',
                      value: _formatEpoch(entity.lastAccessed)),
                  _InfoRow(
                      label: 'Access count',
                      value: '${entity.accessCount}'),
                  if (entity.summary != null) ...[
                    const SizedBox(height: 8),
                    Text(entity.summary!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Facts section
          _ExpandableSection(
            title: '${l.kgEntityFacts} (${facts.length})',
            icon: Icons.list_alt_outlined,
            initiallyExpanded: true,
            child: facts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l.kgBrowserEmpty,
                        style: theme.textTheme.bodySmall),
                  )
                : Column(
                    children: [
                      for (final fact in facts)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  fact.key,
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fact.value,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
          const SizedBox(height: 8),

          // Relations section
          _ExpandableSection(
            title: '${l.kgEntityRelations} (${relations.length})',
            icon: Icons.link_outlined,
            child: relations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l.kgBrowserEmpty,
                        style: theme.textTheme.bodySmall),
                  )
                : Column(
                    children: [
                      for (final rel in relations)
                        InkWell(
                          onTap: () {
                            // Navigate to the other entity
                            final otherId =
                                rel.relation.sourceId == entity.id
                                    ? rel.relation.targetId
                                    : rel.relation.sourceId;
                            Navigator.pushNamed(
                              context,
                              '/settings/knowledge-entity',
                              arguments: otherId,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rel.relation.predicate,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        rel.relation.sourceId == entity.id
                                            ? rel.targetName
                                            : rel.sourceName,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18,
                                    color: theme
                                        .colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
          const SizedBox(height: 8),

          // Aliases section
          if (aliases.isNotEmpty)
            _ExpandableSection(
              title: '${l.kgEntityAliases} (${aliases.length})',
              icon: Icons.label_outline,
              child: Column(
                children: [
                  for (final alias in aliases)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(alias.aliasName,
                                style: theme.textTheme.bodySmall),
                          ),
                          Text(
                            '${alias.aliasType} (${(alias.confidence * 100).toInt()}%)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          if (aliases.isNotEmpty) const SizedBox(height: 8),

          // Decay diagnostics section
          _ExpandableSection(
            title: l.kgEntityDecay,
            icon: Icons.timeline_outlined,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: l.kgRetentionScore,
                    value:
                        '${(_detail!.decayScore * 100).toStringAsFixed(1)}%',
                  ),
                  _InfoRow(
                    label: 'Stability',
                    value:
                        '${(MemoryDecay.stability(entity.accessCount) / 3600).toStringAsFixed(1)}h',
                  ),
                  const Divider(),
                  Text(
                    'R = e^(-t/S)\n'
                    'S = ${MemoryDecay.baseStability}s * (1 + 1.5 * ln(${entity.accessCount} + 1))\n'
                    'Hot >= ${MemoryDecay.hotThreshold}, '
                    'Warm >= ${MemoryDecay.warmThreshold}, '
                    'Cool >= ${MemoryDecay.coolThreshold}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.title,
                        style: theme.textTheme.titleSmall),
                  ),
                  Icon(_expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            widget.child,
          ],
        ],
      ),
    );
  }
}
