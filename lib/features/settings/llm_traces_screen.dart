import 'package:flutter/material.dart';

import '../../core/config/llm_trace.dart';
import '../../core/services/llm_trace_logger.dart';
import '../../l10n/l10n.dart';

/// Screen displaying LLM call traces with stats header and filters.
class LlmTracesScreen extends StatefulWidget {
  const LlmTracesScreen({super.key});

  @override
  State<LlmTracesScreen> createState() => _LlmTracesScreenState();
}

class _LlmTracesScreenState extends State<LlmTracesScreen> {
  List<LlmTrace> _traces = [];
  List<LlmTrace> _filtered = [];
  LlmTraceStats _stats = const LlmTraceStats();
  bool _loading = true;

  String? _callTypeFilter; // null = all, 'chat', 'summarize', 'extract'
  String? _providerFilter; // null = all, else provider name

  @override
  void initState() {
    super.initState();
    _loadTraces();
  }

  Future<void> _loadTraces() async {
    setState(() => _loading = true);
    try {
      final traces = await LlmTraceLogger.instance.readAll();
      final stats = await LlmTraceLogger.instance.getStats();
      if (mounted) {
        setState(() {
          _traces = traces;
          _stats = stats;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var result = _traces;
    if (_callTypeFilter != null) {
      result = result.where((t) => t.callType == _callTypeFilter).toList();
    }
    if (_providerFilter != null) {
      result = result.where((t) => t.provider == _providerFilter).toList();
    }
    _filtered = result;
  }

  Set<String> get _availableProviders =>
      _traces.map((t) => t.provider).toSet();

  String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }

  String _absoluteTime(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:'
      '${ts.minute.toString().padLeft(2, '0')}:'
      '${ts.second.toString().padLeft(2, '0')}';

  String _callTypeLabel(String type, AppLocalizations l) => switch (type) {
        'chat' => l.llmTracesFilterChat,
        'summarize' => l.llmTracesFilterSummarize,
        'extract' => l.llmTracesFilterExtract,
        _ => type,
      };

  Future<void> _clearAll() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.llmTracesClearAll),
        content: Text(l.llmTracesClearConfirm),
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
      await LlmTraceLogger.instance.clearAll();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.llmTracesCleared)),
        );
        _loadTraces();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.llmTracesTitle),
        actions: [
          if (_traces.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.llmTracesClearAll,
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          if (_stats.totalCalls > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.llmTracesStatsHeader(
                      _stats.totalCalls,
                      _formatTokens(
                          _stats.totalPromptTokens + _stats.totalCompletionTokens),
                      (_stats.avgLatencyMs / 1000).toStringAsFixed(1),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.llmTracesLast24h,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Call type filters
                _FilterChip(
                  label: l.llmTracesFilterAll,
                  selected: _callTypeFilter == null,
                  onSelected: (_) => setState(() {
                    _callTypeFilter = null;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.llmTracesFilterChat,
                  selected: _callTypeFilter == 'chat',
                  onSelected: (_) => setState(() {
                    _callTypeFilter =
                        _callTypeFilter == 'chat' ? null : 'chat';
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.llmTracesFilterSummarize,
                  selected: _callTypeFilter == 'summarize',
                  onSelected: (_) => setState(() {
                    _callTypeFilter =
                        _callTypeFilter == 'summarize' ? null : 'summarize';
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.llmTracesFilterExtract,
                  selected: _callTypeFilter == 'extract',
                  onSelected: (_) => setState(() {
                    _callTypeFilter =
                        _callTypeFilter == 'extract' ? null : 'extract';
                    _applyFilters();
                  }),
                ),
                if (_availableProviders.length > 1) ...[
                  const SizedBox(width: 16),
                  for (final provider in _availableProviders) ...[
                    _FilterChip(
                      label: provider,
                      selected: _providerFilter == provider,
                      onSelected: (_) => setState(() {
                        _providerFilter =
                            _providerFilter == provider ? null : provider;
                        _applyFilters();
                      }),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ],
            ),
          ),

          // Trace list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l.llmTracesEmpty,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTraces,
                        child: ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final trace = _filtered[index];
                            return _TraceTile(
                              trace: trace,
                              callTypeLabel:
                                  _callTypeLabel(trace.callType, l),
                              timeStr: _absoluteTime(trace.timestamp),
                              formatTokens: _formatTokens,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/settings/llm-trace-detail',
                                arguments: trace,
                              ),
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

class _TraceTile extends StatelessWidget {
  final LlmTrace trace;
  final String callTypeLabel;
  final String timeStr;
  final String Function(int) formatTokens;
  final VoidCallback onTap;

  const _TraceTile({
    required this.trace,
    required this.callTypeLabel,
    required this.timeStr,
    required this.formatTokens,
    required this.onTap,
  });

  Color _statusColor(BuildContext context) {
    if (trace.isError) return Colors.red;
    if (trace.callType == 'summarize' || trace.callType == 'extract') {
      return Colors.amber;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status dot
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: time + model
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trace.model,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Line 2: call type + iteration + latency
                  Row(
                    children: [
                      Text(
                        callTypeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (trace.callType == 'chat') ...[
                        Text(
                          ' · iter ${trace.iteration}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      Text(
                        ' · ${(trace.latencyMs / 1000).toStringAsFixed(1)}s',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (trace.isError)
                        Text(
                          '  ERROR',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Line 3: tokens in/out
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        formatTokens(trace.promptTokens ?? 0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_downward, size: 12,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        formatTokens(trace.completionTokens ?? 0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'tokens',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
