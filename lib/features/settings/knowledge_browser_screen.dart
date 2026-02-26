import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/knowledge/models/entity.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';

/// Browse screen listing all Knowledge Graph entities with search and filters.
class KnowledgeBrowserScreen extends ConsumerStatefulWidget {
  const KnowledgeBrowserScreen({super.key});

  @override
  ConsumerState<KnowledgeBrowserScreen> createState() =>
      _KnowledgeBrowserScreenState();
}

class _KnowledgeBrowserScreenState
    extends ConsumerState<KnowledgeBrowserScreen> {
  List<(KnowledgeEntity, int)> _entities = [];
  bool _loading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 50;

  String? _typeFilter;
  String? _tempFilter;
  String _searchQuery = '';
  Timer? _debounce;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntities({bool append = false}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _offset = 0;
        _hasMore = true;
      });
    }

    try {
      final kgService = await ref.read(knowledgeServiceProvider.future);
      if (kgService == null) return;

      final results = await kgService.listEntities(
        limit: _pageSize,
        offset: _offset,
        type: _typeFilter,
        temperature: _tempFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          if (append) {
            _entities.addAll(results);
          } else {
            _entities = results;
          }
          _hasMore = results.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchQuery = value;
      _loadEntities();
    });
  }

  void _setTypeFilter(String? type) {
    setState(() {
      _typeFilter = _typeFilter == type ? null : type;
      _tempFilter = null;
    });
    _loadEntities();
  }

  void _setTempFilter(String? temp) {
    setState(() {
      _tempFilter = _tempFilter == temp ? null : temp;
      _typeFilter = null;
    });
    _loadEntities();
  }

  void _loadMore() {
    _offset += _pageSize;
    _loadEntities(append: true);
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

  String _timeAgo(int? epoch) {
    if (epoch == null) return '';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
    );
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _typeLabel(EntityType type, AppLocalizations l) => switch (type) {
        EntityType.person => l.kgFilterPerson,
        EntityType.place => l.kgFilterPlace,
        EntityType.organization => l.kgFilterOrg,
        EntityType.event => l.kgFilterEvent,
        EntityType.concept => l.kgFilterConcept,
        EntityType.date => l.kgFilterDate,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.kgBrowserTitle)),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.kgBrowserSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _loadEntities();
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Type filter chips
          if (_searchQuery.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _FilterChip(
                    label: l.kgFilterAll,
                    selected: _typeFilter == null && _tempFilter == null,
                    onSelected: (_) {
                      setState(() {
                        _typeFilter = null;
                        _tempFilter = null;
                      });
                      _loadEntities();
                    },
                  ),
                  const SizedBox(width: 6),
                  for (final type in EntityType.values) ...[
                    _FilterChip(
                      label: _typeLabel(type, l),
                      selected: _typeFilter == type.label,
                      onSelected: (_) => _setTypeFilter(type.label),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),

          // Temperature filter chips
          if (_searchQuery.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  for (final temp in Temperature.values) ...[
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _tempColor(temp),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(_tempLabel(temp, l)),
                        ],
                      ),
                      selected: _tempFilter == temp.name,
                      onSelected: (_) => _setTempFilter(temp.name),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),

          // Entity list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entities.isEmpty
                    ? Center(
                        child: Text(
                          l.kgBrowserEmpty,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEntities,
                        child: ListView.builder(
                          itemCount: _entities.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _entities.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: TextButton(
                                    onPressed: _loadMore,
                                    child: Text(l.kgLoadMore),
                                  ),
                                ),
                              );
                            }
                            final (entity, factCount) = _entities[index];
                            return _EntityTile(
                              entity: entity,
                              factCount: factCount,
                              typeIcon: _typeIcon(entity.entityType),
                              tempColor: _tempColor(entity.temperature),
                              timeAgo: _timeAgo(entity.lastAccessed),
                              factCountLabel: l.kgFactCount(factCount),
                              onTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/settings/knowledge-entity',
                                  arguments: entity.id,
                                );
                                // Refresh after returning (entity might have been deleted)
                                _loadEntities();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _tempLabel(Temperature temp, AppLocalizations l) => switch (temp) {
        Temperature.hot => l.kgFilterHot,
        Temperature.warm => l.kgFilterWarm,
        Temperature.cool => l.kgFilterCool,
        Temperature.cold => l.kgFilterCold,
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EntityTile extends StatelessWidget {
  final KnowledgeEntity entity;
  final int factCount;
  final IconData typeIcon;
  final Color tempColor;
  final String timeAgo;
  final String factCountLabel;
  final VoidCallback onTap;

  const _EntityTile({
    required this.entity,
    required this.factCount,
    required this.typeIcon,
    required this.tempColor,
    required this.timeAgo,
    required this.factCountLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(typeIcon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        factCountLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (timeAgo.isNotEmpty) ...[
                        Text(
                          ' · $timeAgo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: tempColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
