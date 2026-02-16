import 'package:flutter/material.dart';

import '../../core/agent/agent_loop.dart';

/// Shows the current agent status (thinking, tool call, summarizing).
class AgentStatusIndicator extends StatelessWidget {
  final AgentEvent? event;

  const AgentStatusIndicator({super.key, this.event});

  @override
  Widget build(BuildContext context) {
    if (event == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final (icon, label) = _eventInfo(event!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String) _eventInfo(AgentEvent event) => switch (event) {
        ThinkingEvent(iteration: final i) => (
            Icons.psychology_outlined,
            i == 0 ? 'Thinking...' : 'Thinking (step ${i + 1})...'
          ),
        SummarizingEvent() => (
            Icons.compress_outlined,
            'Summarizing conversation...'
          ),
        ToolCallEvent(name: final name) => (
            Icons.build_outlined,
            'Using $name...'
          ),
        ToolResultEvent(name: final name) => (
            Icons.check_circle_outline,
            'Got result from $name'
          ),
        _ => (Icons.hourglass_empty, 'Processing...'),
      };
}
