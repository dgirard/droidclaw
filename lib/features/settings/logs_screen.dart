import 'package:flutter/material.dart';

import '../../core/config/log_entry.dart';
import '../../core/services/app_logger.dart';
import '../../l10n/l10n.dart';

/// Screen displaying persistent application logs with filters.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry> _entries = [];
  List<LogEntry> _filtered = [];
  bool _loading = true;

  LogLevel? _levelFilter;
  LogSource? _sourceFilter;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final entries = await AppLogger.instance.readAll();
      if (mounted) {
        setState(() {
          _entries = entries;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var result = _entries;
    if (_levelFilter != null) {
      result = result
          .where((e) => e.level.index >= _levelFilter!.index)
          .toList();
    }
    if (_sourceFilter != null) {
      result = result.where((e) => e.source == _sourceFilter).toList();
    }
    _filtered = result;
  }

  String _sourceName(LogSource source, AppLocalizations l) => switch (source) {
        LogSource.agent => l.logsSourceAgent,
        LogSource.cron => l.logsSourceCron,
        LogSource.service => l.logsSourceService,
        LogSource.telegram => l.logsSourceTelegram,
        LogSource.app => l.logsSourceApp,
      };

  String _levelName(LogLevel level, AppLocalizations l) => switch (level) {
        LogLevel.debug => 'Debug',
        LogLevel.info => l.logsFilterInfo,
        LogLevel.warning => l.logsFilterWarning,
        LogLevel.error => l.logsFilterError,
      };

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.debug => Colors.grey,
        LogLevel.info => Colors.blue,
        LogLevel.warning => Colors.orange,
        LogLevel.error => Colors.red,
      };

  IconData _levelIcon(LogLevel level) => switch (level) {
        LogLevel.debug => Icons.bug_report_outlined,
        LogLevel.info => Icons.info_outline,
        LogLevel.warning => Icons.warning_amber_outlined,
        LogLevel.error => Icons.error_outline,
      };

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return '<1m';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _absoluteTime(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:'
      '${ts.minute.toString().padLeft(2, '0')}:'
      '${ts.second.toString().padLeft(2, '0')}';

  Future<void> _clearAll() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logsClearAll),
        content: Text(l.logsClearConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (confirmed == true) {
      await AppLogger.instance.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.logsCleared)),
        );
        _loadEntries();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.logsTitle),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.logsClearAll,
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Level filters
                _FilterChip(
                  label: l.logsFilterAll,
                  selected: _levelFilter == null,
                  onSelected: (_) => setState(() {
                    _levelFilter = null;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.logsFilterInfo,
                  selected: _levelFilter == LogLevel.info,
                  onSelected: (_) => setState(() {
                    _levelFilter = LogLevel.info;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.logsFilterWarning,
                  selected: _levelFilter == LogLevel.warning,
                  onSelected: (_) => setState(() {
                    _levelFilter = LogLevel.warning;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.logsFilterError,
                  selected: _levelFilter == LogLevel.error,
                  onSelected: (_) => setState(() {
                    _levelFilter = LogLevel.error;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 16),
                // Source filters
                _FilterChip(
                  label: l.logsSourceAgent,
                  selected: _sourceFilter == LogSource.agent,
                  onSelected: (_) => setState(() {
                    _sourceFilter =
                        _sourceFilter == LogSource.agent ? null : LogSource.agent;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.logsSourceCron,
                  selected: _sourceFilter == LogSource.cron,
                  onSelected: (_) => setState(() {
                    _sourceFilter =
                        _sourceFilter == LogSource.cron ? null : LogSource.cron;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.logsSourceService,
                  selected: _sourceFilter == LogSource.service,
                  onSelected: (_) => setState(() {
                    _sourceFilter = _sourceFilter == LogSource.service
                        ? null
                        : LogSource.service;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.logsSourceTelegram,
                  selected: _sourceFilter == LogSource.telegram,
                  onSelected: (_) => setState(() {
                    _sourceFilter = _sourceFilter == LogSource.telegram
                        ? null
                        : LogSource.telegram;
                    _applyFilters();
                  }),
                ),
              ],
            ),
          ),

          // Entry count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.logsEntryCount(_filtered.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Entries list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l.logsEmpty,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEntries,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final entry = _filtered[index];
                            return _LogEntryTile(
                              entry: entry,
                              levelColor: _levelColor(entry.level),
                              levelIcon: _levelIcon(entry.level),
                              levelName: _levelName(entry.level, l),
                              sourceName: _sourceName(entry.source, l),
                              relativeTime: _relativeTime(entry.timestamp),
                              absoluteTime: _absoluteTime(entry.timestamp),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
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

class _LogEntryTile extends StatefulWidget {
  final LogEntry entry;
  final Color levelColor;
  final IconData levelIcon;
  final String levelName;
  final String sourceName;
  final String relativeTime;
  final String absoluteTime;

  const _LogEntryTile({
    required this.entry,
    required this.levelColor,
    required this.levelIcon,
    required this.levelName,
    required this.sourceName,
    required this.relativeTime,
    required this.absoluteTime,
  });

  @override
  State<_LogEntryTile> createState() => _LogEntryTileState();
}

class _LogEntryTileState extends State<_LogEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.levelIcon, color: widget.levelColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.message,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        widget.sourceName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.levelName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.levelColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.relativeTime} (${widget.absoluteTime})',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (_expanded && entry.cronId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Cron: ${entry.cronId}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_expanded && entry.sessionKey != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Session: ${entry.sessionKey}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
