import 'dart:async';

import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import '../config/app_config.dart';
import '../config/log_entry.dart';
import '../providers/llm_provider.dart';
import '../providers/llm_response.dart';
import '../services/app_logger.dart';
import '../session/session.dart';
import '../session/session_manager.dart';
import '../tools/tool.dart';
import 'context_builder.dart';

/// Events emitted by the agent loop for UI updates.
sealed class AgentEvent {
  const AgentEvent();
}

class ThinkingEvent extends AgentEvent {
  final int iteration;
  const ThinkingEvent({required this.iteration});
}

class SummarizingEvent extends AgentEvent {
  const SummarizingEvent();
}

class ResponseEvent extends AgentEvent {
  final String content;
  final UsageInfo? usage;
  const ResponseEvent({required this.content, this.usage});
}

class ToolCallEvent extends AgentEvent {
  final String name;
  final Map<String, dynamic> arguments;
  const ToolCallEvent({required this.name, required this.arguments});
}

class ToolResultEvent extends AgentEvent {
  final String name;
  final ToolResult result;
  const ToolResultEvent({required this.name, required this.result});
}

class ErrorEvent extends AgentEvent {
  final String message;
  const ErrorEvent(this.message);
}

/// The main agent loop: processes user messages through LLM + tool calling.
class AgentLoop {
  final LLMProvider provider;
  final AppConfig config;
  final SessionManager sessions;
  final ToolRegistry tools;
  final ContextBuilder contextBuilder;

  AgentLoop({
    required this.provider,
    required this.config,
    required this.sessions,
    required this.tools,
    required this.contextBuilder,
  });

  /// Process a user message and yield agent events.
  Stream<AgentEvent> processMessage(
    String userMessage,
    String sessionKey,
  ) async* {
    final session = sessions.getOrCreate(sessionKey);

    // Check if summarization is needed before processing
    if (_needsSummarization(session)) {
      yield const SummarizingEvent();
      await _summarize(session);
    }

    // Build system prompt
    final systemPrompt = await contextBuilder.buildSystemPrompt();

    // Add user message to session
    session.addMessage(Message(role: 'user', content: userMessage));

    // Agent loop: iterate up to maxToolIterations
    final maxIter = config.agent.maxToolIterations;
    for (var iteration = 0; iteration < maxIter; iteration++) {
      // Build messages list for LLM
      final messages = [
        Message(role: 'system', content: systemPrompt),
        ...session.getMessages(),
      ];

      final totalChars =
          messages.fold<int>(0, (sum, m) => sum + m.content.length);
      AppLogger.instance.debug(LogSource.agent,
          'iter=$iteration, msgs=${messages.length}, '
          'chars=$totalChars, model=${config.agent.model}');

      yield ThinkingEvent(iteration: iteration);

      LLMResponse response;
      try {
        response = await provider.chat(
          messages: messages,
          tools: tools.getDefinitions(),
          model: config.agent.model,
          options: {
            'max_tokens': config.agent.maxTokens,
            'temperature': config.agent.temperature,
          },
        );
        AppLogger.instance.info(LogSource.agent,
            'LLM responded: content=${response.content.length} chars, '
            'toolCalls=${response.toolCalls.length}, '
            'finish=${response.finishReason}',
            sessionKey: sessionKey);
      } catch (e) {
        AppLogger.instance.error(LogSource.agent, 'LLM error: $e',
            sessionKey: sessionKey);
        yield ErrorEvent(tr(config.resolvedLocale).agentLlmError(e.toString()));
        return;
      }

      // No tool calls → final response
      if (response.toolCalls.isEmpty) {
        session.addMessage(
            Message(role: 'assistant', content: response.content));
        await sessions.save(session);
        yield ResponseEvent(content: response.content, usage: response.usage);
        return;
      }

      // Add assistant message with tool calls to session
      session.addMessage(Message(
        role: 'assistant',
        content: response.content,
        toolCalls: response.toolCalls,
      ));

      // Execute each tool call
      for (final toolCall in response.toolCalls) {
        yield ToolCallEvent(name: toolCall.name, arguments: toolCall.arguments);

        final result = await tools.execute(toolCall.name, toolCall.arguments);
        AppLogger.instance.debug(LogSource.agent,
            'Tool ${toolCall.name} result: '
            '${result.forLLM.length} chars, error=${result.isError}');

        yield ToolResultEvent(name: toolCall.name, result: result);

        // Add tool result to session
        session.addMessage(Message(
          role: 'tool',
          content: result.forLLM,
          toolCallId: toolCall.id,
          name: toolCall.name,
        ));
      }
    }

    // Max iterations reached
    await sessions.save(session);
    yield ErrorEvent(tr(config.resolvedLocale).agentMaxIterations);
  }

  /// Check if the session needs summarization.
  /// Triggered at 20+ messages OR estimated tokens > 75% of maxTokens.
  bool _needsSummarization(Session session) {
    if (session.messageCount >= AppConstants.summarizationMessageCount) {
      return true;
    }
    // Rough token estimation: ~4 chars per token
    final estimatedTokens = session.messages
            .fold<int>(0, (sum, m) => sum + m.content.length) ~/
        4;
    final threshold =
        (config.agent.maxTokens * AppConstants.summarizationThreshold).toInt();
    return estimatedTokens > threshold;
  }

  /// Summarize the conversation history.
  Future<void> _summarize(Session session) async {
    final messagesToSummarize =
        session.truncateHistory(AppConstants.keepLastMessages);
    if (messagesToSummarize.isEmpty) return;

    final summaryContent = messagesToSummarize
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');

    try {
      final response = await provider.chat(
        messages: [
          const Message(
            role: 'system',
            content:
                'Summarize the following conversation concisely, preserving key facts, decisions, and context.',
          ),
          Message(role: 'user', content: summaryContent),
        ],
        model: config.agent.model,
        options: {'max_tokens': 1024, 'temperature': 0.3},
      );

      session.summary = response.content;
    } catch (_) {
      // If summarization fails, just set a basic summary from truncated messages
      session.summary =
          'Previous conversation (${messagesToSummarize.length} messages) about: '
          '${messagesToSummarize.firstWhere((m) => m.role == "user", orElse: () => const Message(role: "user", content: "various topics")).content.substring(0, 100)}...';
    }
  }
}
