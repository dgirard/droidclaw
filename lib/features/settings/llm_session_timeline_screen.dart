import 'package:flutter/material.dart';

import '../../core/config/llm_trace.dart';
import '../../l10n/l10n.dart';

/// Timeline view showing the agent loop flow for a single session.
class LlmSessionTimelineScreen extends StatelessWidget {
  final String sessionTitle;
  final String sessionType;
  final List<LlmTrace> traces;

  const LlmSessionTimelineScreen({
    super.key,
    required this.sessionTitle,
    required this.sessionType,
    required this.traces,
  });

  String _formatTokens(int tokens) {
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Aggregate stats
    int totalTokens = 0;
    int totalLatency = 0;
    for (final t in traces) {
      totalTokens += (t.promptTokens ?? 0) + (t.completionTokens ?? 0);
      totalLatency += t.latencyMs;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.llmTimelineTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card: user prompt + stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SessionTypeBadge(type: sessionType, l: l),
                      const SizedBox(width: 8),
                      Text(
                        '${traces.length} ${l.llmTracesSessionCalls(traces.length).split(' ').last} · '
                        '${_formatTokens(totalTokens)} tokens · '
                        '${(totalLatency / 1000).toStringAsFixed(1)}s',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.llmTimelineUserPrompt,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sessionTitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Timeline nodes
          ...List.generate(traces.length, (index) {
            final trace = traces[index];
            final isLast = index == traces.length - 1;
            return _TimelineNode(
              trace: trace,
              isLast: isLast,
              l: l,
              formatTokens: _formatTokens,
              onTap: () => Navigator.pushNamed(
                context,
                '/settings/llm-trace-detail',
                arguments: trace,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SessionTypeBadge extends StatelessWidget {
  final String type;
  final AppLocalizations l;

  const _SessionTypeBadge({required this.type, required this.l});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (type) {
      'cron' => l.llmTracesSessionCron,
      'extract' => l.llmTracesSessionExtract,
      _ => l.llmTracesSessionChat,
    };
    final color = switch (type) {
      'cron' => Colors.amber,
      'extract' => Colors.deepPurple,
      _ => theme.colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final LlmTrace trace;
  final bool isLast;
  final AppLocalizations l;
  final String Function(int) formatTokens;
  final VoidCallback onTap;

  const _TimelineNode({
    required this.trace,
    required this.isLast,
    required this.l,
    required this.formatTokens,
    required this.onTap,
  });

  Color _dotColor(BuildContext context) {
    if (trace.isError) return Colors.red;
    if (trace.callType == 'summarize') return Colors.amber;
    if (trace.callType == 'extract') return Colors.deepPurple;
    // Final response (no tool calls, finish=stop)
    if (trace.toolCalls.isEmpty && trace.finishReason == 'stop') {
      return Colors.green;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _nodeTitle() {
    if (trace.callType == 'summarize') return l.llmTimelineSummarize;
    if (trace.callType == 'extract') return l.llmTimelineExtract;
    if (trace.toolCalls.isEmpty && trace.finishReason == 'stop') {
      return l.llmTimelineFinalResponse;
    }
    return l.llmTimelineLlmCall(trace.iteration);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = _dotColor(context);
    final lineColor = theme.colorScheme.outlineVariant;
    final totalTokens =
        (trace.promptTokens ?? 0) + (trace.completionTokens ?? 0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vertical line + dot
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 8,
                    color: lineColor,
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: lineColor,
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + stats
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _nodeTitle(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(trace.latencyMs / 1000).toStringAsFixed(1)}s',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${formatTokens(totalTokens)} tok',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),

                    // Tool calls
                    if (trace.toolCalls.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.llmTimelineToolsCalled(trace.toolCalls.join(', ')),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    // Response preview for final response
                    if (trace.toolCalls.isEmpty &&
                        trace.finishReason == 'stop' &&
                        trace.responseContent != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        trace.responseContent!.length > 120
                            ? '${trace.responseContent!.substring(0, 120)}...'
                            : trace.responseContent!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    // Error
                    if (trace.isError) ...[
                      const SizedBox(height: 4),
                      Text(
                        trace.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
