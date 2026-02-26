import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/llm_trace.dart';
import '../../l10n/l10n.dart';

/// Detail screen for a single LLM trace, with expandable sections.
class LlmTraceDetailScreen extends StatelessWidget {
  const LlmTraceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trace = ModalRoute.of(context)!.settings.arguments as LlmTrace;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.llmTraceDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header: time + model + call type
          _HeaderCard(trace: trace, l: l, theme: theme),
          const SizedBox(height: 12),

          // Tokens table
          _TokensCard(trace: trace, l: l, theme: theme),
          const SizedBox(height: 12),

          // Latency
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l.llmTraceLatency(trace.latencyMs)),
            ),
          ),
          const SizedBox(height: 12),

          // Error (if any)
          if (trace.isError) ...[
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.llmTraceError,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              )),
                          const SizedBox(height: 4),
                          Text(trace.error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // System prompt (expandable)
          _ExpandableSection(
            title: l.llmTraceSystemPrompt(trace.systemPromptChars),
            icon: Icons.settings_suggest_outlined,
            content: trace.systemPromptPreview,
            copyable: true,
          ),
          const SizedBox(height: 8),

          // Messages (expandable)
          _MessagesSection(
            title: l.llmTraceMessages(trace.messageCount),
            messages: trace.messages,
          ),
          const SizedBox(height: 8),

          // Response (expandable)
          if (trace.responseContent != null)
            _ExpandableSection(
              title: l.llmTraceResponse(trace.responseChars ?? 0),
              icon: Icons.chat_bubble_outline,
              content: trace.responseContent!,
              copyable: true,
            ),
          if (trace.responseContent != null) const SizedBox(height: 8),

          // Tool calls
          if (trace.toolCalls.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.build_outlined),
                title: Text(l.llmTraceToolsCalled),
                subtitle: Text(trace.toolCalls.join(', ')),
              ),
            ),
          if (trace.toolCalls.isNotEmpty) const SizedBox(height: 8),

          // Finish reason
          if (trace.finishReason != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l.llmTraceFinishReason),
                subtitle: Text(trace.finishReason!),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final LlmTrace trace;
  final AppLocalizations l;
  final ThemeData theme;

  const _HeaderCard({
    required this.trace,
    required this.l,
    required this.theme,
  });

  String _formatTime(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:'
      '${ts.minute.toString().padLeft(2, '0')}:'
      '${ts.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _formatTime(trace.timestamp),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trace.model,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                trace.callType,
                if (trace.callType == 'chat')
                  l.llmTraceIteration(trace.iteration),
                if (trace.sessionKey != null) 'session: ${trace.sessionKey}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'provider: ${trace.provider}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokensCard extends StatelessWidget {
  final LlmTrace trace;
  final AppLocalizations l;
  final ThemeData theme;

  const _TokensCard({
    required this.trace,
    required this.l,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.llmTraceTokens,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TokenColumn(
                    label: l.llmTraceTokensIn,
                    value: trace.promptTokens ?? 0,
                    color: theme.colorScheme.primary,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _TokenColumn(
                    label: l.llmTraceTokensOut,
                    value: trace.completionTokens ?? 0,
                    color: theme.colorScheme.secondary,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _TokenColumn(
                    label: l.llmTraceTokensTotal,
                    value: trace.totalTokens ??
                        ((trace.promptTokens ?? 0) +
                            (trace.completionTokens ?? 0)),
                    color: theme.colorScheme.tertiary,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenColumn extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ThemeData theme;

  const _TokenColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  String _format(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 4),
        Text(
          _format(value),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool copyable;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.content,
    this.copyable = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    widget.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  if (widget.copyable) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)
                                  .chatCopied),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessagesSection extends StatefulWidget {
  final String title;
  final List<LlmTraceMessage> messages;

  const _MessagesSection({
    required this.title,
    required this.messages,
  });

  @override
  State<_MessagesSection> createState() => _MessagesSectionState();
}

class _MessagesSectionState extends State<_MessagesSection> {
  bool _expanded = false;

  IconData _roleIcon(String role) => switch (role) {
        'user' => Icons.person_outline,
        'assistant' => Icons.smart_toy_outlined,
        'tool' => Icons.build_outlined,
        'system' => Icons.settings_suggest_outlined,
        _ => Icons.chat_outlined,
      };

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
                  const Icon(Icons.forum_outlined, size: 20),
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
            ...widget.messages.map((msg) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_roleIcon(msg.role), size: 16,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                msg.role,
                                if (msg.toolName != null) '[${msg.toolName}]',
                                '(${msg.contentLength} chars)',
                              ].join(' '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.preview,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
