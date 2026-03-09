import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/llm_trace.dart';
import '../../core/services/llm_trace_logger.dart';
import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import 'llm_session_timeline_screen.dart';

/// Session group for display.
class _SessionGroup {
  final String? sessionKey;
  final String sessionType;
  final String userPrompt;
  final List<LlmTrace> traces;
  final DateTime firstCall;
  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int totalLatencyMs;
  final Set<String> allTools;
  final bool hasError;

  _SessionGroup({
    required this.sessionKey,
    required this.sessionType,
    required this.userPrompt,
    required this.traces,
    required this.firstCall,
    required this.totalPromptTokens,
    required this.totalCompletionTokens,
    required this.totalLatencyMs,
    required this.allTools,
    required this.hasError,
  });
}

/// Screen displaying LLM call traces grouped by session.
class LlmTracesScreen extends StatefulWidget {
  const LlmTracesScreen({super.key});

  @override
  State<LlmTracesScreen> createState() => _LlmTracesScreenState();
}

class _LlmTracesScreenState extends State<LlmTracesScreen> {
  List<LlmTrace> _traces = [];
  List<_SessionGroup> _groups = [];
  LlmTraceStats _stats = const LlmTraceStats();
  bool _loading = true;

  String? _callTypeFilter;
  String? _providerFilter;

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
          _buildGroups();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _buildGroups() {
    // Apply filters first
    var filtered = _traces.toList();
    if (_callTypeFilter != null) {
      filtered = filtered.where((t) => t.callType == _callTypeFilter).toList();
    }
    if (_providerFilter != null) {
      filtered = filtered.where((t) => t.provider == _providerFilter).toList();
    }

    // Group by sessionKey
    final grouped = <String, List<LlmTrace>>{};
    for (final trace in filtered) {
      final key = trace.sessionKey ?? '';
      grouped.putIfAbsent(key, () => []).add(trace);
    }

    // Build session groups
    final groups = <_SessionGroup>[];
    for (final entry in grouped.entries) {
      final sessionKey = entry.key.isEmpty ? null : entry.key;
      final traces = entry.value
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      int totalPrompt = 0;
      int totalCompletion = 0;
      int totalLatency = 0;
      final allTools = <String>{};
      bool hasError = false;

      for (final t in traces) {
        totalPrompt += t.promptTokens ?? 0;
        totalCompletion += t.completionTokens ?? 0;
        totalLatency += t.latencyMs;
        allTools.addAll(t.toolCalls);
        if (t.isError) hasError = true;
      }

      groups.add(_SessionGroup(
        sessionKey: sessionKey,
        sessionType: _detectSessionType(sessionKey, traces),
        userPrompt: _extractUserPrompt(traces),
        traces: traces,
        firstCall: traces.first.timestamp,
        totalPromptTokens: totalPrompt,
        totalCompletionTokens: totalCompletion,
        totalLatencyMs: totalLatency,
        allTools: allTools,
        hasError: hasError,
      ));
    }

    // Sort by first call descending (newest first)
    groups.sort((a, b) => b.firstCall.compareTo(a.firstCall));
    _groups = groups;
  }

  String _detectSessionType(String? sessionKey, List<LlmTrace> traces) {
    if (sessionKey == null) return 'unknown';
    if (sessionKey.startsWith(AppConstants.cronSessionPrefix)) return 'cron';
    if (traces.every((t) => t.callType == 'extract')) return 'extract';
    return 'chat';
  }

  String _extractUserPrompt(List<LlmTrace> traces) {
    final firstChat = traces.cast<LlmTrace?>().firstWhere(
          (t) => t!.callType == 'chat',
          orElse: () => null,
        );
    final target = firstChat ?? traces.first;

    // Find last user message (the triggering prompt)
    final userMsg = target.messages.cast<LlmTraceMessage?>().lastWhere(
          (m) => m!.role == 'user',
          orElse: () => null,
        );
    if (userMsg != null) return userMsg.preview;
    if (target.messages.isNotEmpty) return target.messages.first.preview;
    return target.sessionKey ?? target.callType;
  }

  Set<String> get _availableProviders =>
      _traces.map((t) => t.provider).toSet();

  String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.llmTracesStatsHeader(
                      _stats.totalCalls,
                      _formatTokens(_stats.totalPromptTokens +
                          _stats.totalCompletionTokens),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l.llmTracesFilterAll,
                  selected: _callTypeFilter == null,
                  onSelected: (_) => setState(() {
                    _callTypeFilter = null;
                    _buildGroups();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.llmTracesFilterChat,
                  selected: _callTypeFilter == 'chat',
                  onSelected: (_) => setState(() {
                    _callTypeFilter =
                        _callTypeFilter == 'chat' ? null : 'chat';
                    _buildGroups();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.llmTracesFilterSummarize,
                  selected: _callTypeFilter == 'summarize',
                  onSelected: (_) => setState(() {
                    _callTypeFilter =
                        _callTypeFilter == 'summarize' ? null : 'summarize';
                    _buildGroups();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.llmTracesFilterExtract,
                  selected: _callTypeFilter == 'extract',
                  onSelected: (_) => setState(() {
                    _callTypeFilter =
                        _callTypeFilter == 'extract' ? null : 'extract';
                    _buildGroups();
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
                        _buildGroups();
                      }),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ],
            ),
          ),

          // Session groups list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
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
                          itemCount: _groups.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final group = _groups[index];
                            return _SessionGroupTile(
                              group: group,
                              formatTokens: _formatTokens,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LlmSessionTimelineScreen(
                                    sessionTitle: group.userPrompt,
                                    sessionType: group.sessionType,
                                    traces: group.traces,
                                  ),
                                ),
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

class _SessionGroupTile extends StatelessWidget {
  final _SessionGroup group;
  final String Function(int) formatTokens;
  final VoidCallback onTap;

  const _SessionGroupTile({
    required this.group,
    required this.formatTokens,
    required this.onTap,
  });

  Color _statusColor(BuildContext context) {
    if (group.hasError) return Colors.red;
    if (group.sessionType == 'cron') return Colors.amber;
    if (group.sessionType == 'extract') return Colors.deepPurple;
    return Colors.green;
  }

  String _formatTime(DateTime ts) =>
      DateFormat('HH:mm').format(ts);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final statusColor = _statusColor(context);
    final totalTokens =
        group.totalPromptTokens + group.totalCompletionTokens;

    final typeLabel = switch (group.sessionType) {
      'cron' => l.llmTracesSessionCron,
      'extract' => l.llmTracesSessionExtract,
      'unknown' => l.llmTracesUngrouped,
      _ => l.llmTracesSessionChat,
    };

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
                  // Line 1: time + user prompt
                  Row(
                    children: [
                      Text(
                        _formatTime(group.firstCall),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.userPrompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Line 2: type · calls · tokens · latency
                  Text(
                    '$typeLabel · ${l.llmTracesSessionCalls(group.traces.length)} · '
                    '${formatTokens(totalTokens)} tokens · '
                    '${(group.totalLatencyMs / 1000).toStringAsFixed(1)}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  // Line 3: tools (if any)
                  if (group.allTools.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      l.llmTimelineToolsCalled(group.allTools.join(', ')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
