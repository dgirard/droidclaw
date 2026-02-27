import 'dart:async';
import 'dart:math';

import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import '../config/app_config.dart';
import '../config/llm_trace.dart';
import '../config/log_entry.dart';
import '../knowledge/models/ranked_result.dart';
import '../knowledge/services/ingestion_pipeline.dart';
import '../knowledge/services/knowledge_service.dart';
import '../providers/llm_provider.dart';
import '../providers/llm_response.dart';
import '../services/app_logger.dart';
import '../services/llm_trace_logger.dart';
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
  final KnowledgeService? knowledgeService;
  final IngestionPipeline? ingestionPipeline;

  AgentLoop({
    required this.provider,
    required this.config,
    required this.sessions,
    required this.tools,
    required this.contextBuilder,
    this.knowledgeService,
    this.ingestionPipeline,
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

    // Pre-query: inject Knowledge Graph context if available
    String? kgContext;
    if (knowledgeService != null) {
      try {
        // LLM query expansion: extract search keywords from user message
        final expandedQuery = await _expandQueryForKG(userMessage);

        final results = await knowledgeService!.queryRelevant(
          expandedQuery,
          limit: 10,
        );
        if (results.isNotEmpty) {
          kgContext = formatKnowledgeContext(results);
          AppLogger.instance.debug(LogSource.agent,
              'KG pre-query: ${results.length} results '
              '(expanded: "${expandedQuery.substring(0, min(100, expandedQuery.length))}...")');
        }
      } catch (e) {
        AppLogger.instance.warning(LogSource.agent,
            'KG pre-query failed: $e', sessionKey: sessionKey);
      }
    }

    // Build system prompt (with optional KG context)
    final systemPrompt = await contextBuilder.buildSystemPrompt(
      knowledgeContext: kgContext,
    );

    // Add user message to session
    session.addMessage(Message(role: 'user', content: userMessage));

    // Agent loop: iterate up to maxToolIterations
    final maxIter = config.agent.maxToolIterations;
    final resolvedLocale = config.resolvedLocale;
    for (var iteration = 0; iteration < maxIter; iteration++) {
      // Build messages list for LLM
      final messages = [
        Message(role: 'system', content: systemPrompt),
        ...session.getMessages(),
      ];

      // For non-English locales, tag the last user message with a language hint
      // in the target language. This improves compliance with weaker models
      // (e.g. Gemini Flash) that tend to follow conversation patterns over
      // system instructions. The tag is on the copy, not the stored session.
      if (resolvedLocale != 'en') {
        final hint = _languageHint(resolvedLocale);
        for (var i = messages.length - 1; i >= 0; i--) {
          if (messages[i].role == 'user') {
            messages[i] = messages[i].copyWith(
              content: '${messages[i].content}\n\n[$hint]',
            );
            break;
          }
        }
      }

      final totalChars =
          messages.fold<int>(0, (sum, m) => sum + m.content.length);
      AppLogger.instance.debug(LogSource.agent,
          'iter=$iteration, msgs=${messages.length}, '
          'chars=$totalChars, model=${config.agent.model}');

      yield ThinkingEvent(iteration: iteration);

      LLMResponse response;
      final stopwatch = Stopwatch()..start();
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
        stopwatch.stop();
        AppLogger.instance.info(LogSource.agent,
            'LLM responded: content=${response.content.length} chars, '
            'toolCalls=${response.toolCalls.length}, '
            'finish=${response.finishReason}',
            sessionKey: sessionKey);

        LlmTraceLogger.instance.log(LlmTrace(
          provider: provider.providerName,
          model: config.agent.model,
          callType: 'chat',
          iteration: iteration,
          sessionKey: sessionKey,
          messageCount: messages.length,
          systemPromptChars: systemPrompt.length,
          systemPromptPreview: systemPrompt.substring(
              0, min(500, systemPrompt.length)),
          messages: _buildTraceMessages(messages),
          toolDefinitionCount: tools.getDefinitions().length,
          responseContent: response.content,
          responseChars: response.content.length,
          toolCalls:
              response.toolCalls.map((tc) => tc.name).toList(),
          finishReason: response.finishReason,
          promptTokens: response.usage?.promptTokens,
          completionTokens: response.usage?.completionTokens,
          totalTokens: response.usage?.totalTokens,
          latencyMs: stopwatch.elapsedMilliseconds,
        ));
      } catch (e) {
        stopwatch.stop();
        AppLogger.instance.error(LogSource.agent, 'LLM error: $e',
            sessionKey: sessionKey);

        LlmTraceLogger.instance.log(LlmTrace(
          provider: provider.providerName,
          model: config.agent.model,
          callType: 'chat',
          iteration: iteration,
          sessionKey: sessionKey,
          messageCount: messages.length,
          systemPromptChars: systemPrompt.length,
          systemPromptPreview: systemPrompt.substring(
              0, min(500, systemPrompt.length)),
          messages: _buildTraceMessages(messages),
          toolDefinitionCount: tools.getDefinitions().length,
          error: e.toString(),
          latencyMs: stopwatch.elapsedMilliseconds,
        ));

        yield ErrorEvent(tr(config.resolvedLocale).agentLlmError(e.toString()));
        return;
      }

      // No tool calls → final response
      if (response.toolCalls.isEmpty) {
        session.addMessage(
            Message(role: 'assistant', content: response.content));
        await sessions.save(session);
        yield ResponseEvent(content: response.content, usage: response.usage);

        // Post-response: fire-and-forget KG extraction
        if (ingestionPipeline != null && config.knowledge.autoExtract) {
          _extractAsync(userMessage, response.content, sessionKey);
        }
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

  /// Expand a user query into search keywords for Knowledge Graph retrieval.
  ///
  /// Uses a fast LLM call (max_tokens: 50) to bridge the semantic gap between
  /// natural language questions and stored entity/fact tokens.
  /// When the KG has a fixed language, translates keywords to that language.
  Future<String> _expandQueryForKG(String userMessage) async {
    try {
      final kbLang = config.knowledge.kbLanguage;
      final String systemContent;
      if (kbLang != null) {
        final langName = KnowledgeConfig.languageName(kbLang);
        systemContent =
            'You are a keyword extractor for a knowledge graph search. '
            'The knowledge base stores all data in $langName. '
            'Given a user message, translate it to $langName if needed, '
            'then output ONLY search keywords (single words) in $langName '
            'that would match stored entities, facts, or relations. '
            'Include: key terms, synonyms, and related concepts. '
            'Output one line of space-separated keywords. '
            'No punctuation, no explanations.';
      } else {
        systemContent =
            'You are a keyword extractor for a knowledge graph search. '
            'Given a user message, output ONLY search keywords (single words) '
            'that would match stored entities, facts, or relations. '
            'Include: the original key terms, synonyms, translations (FR/EN/DE/ES/IT), '
            'and related concepts. Output one line of space-separated keywords. '
            'No punctuation, no explanations.';
      }

      final response = await provider.chat(
        messages: [
          Message(role: 'system', content: systemContent),
          Message(role: 'user', content: userMessage),
        ],
        model: config.agent.model,
        options: {'max_tokens': 50, 'temperature': 0.0},
      );
      final keywords = response.content.trim();
      if (keywords.isNotEmpty) {
        // Combine original message with expanded keywords for broader FTS matching
        return '$userMessage $keywords';
      }
    } catch (e) {
      AppLogger.instance.debug(LogSource.agent,
          'KG query expansion failed, using raw query: $e');
    }
    return userMessage;
  }

  /// Fire-and-forget async Knowledge Graph extraction.
  /// Does NOT block the agent stream. Errors are logged, not surfaced.
  void _extractAsync(
      String userMessage, String assistantResponse, String sessionKey) {
    Future(() async {
      try {
        final count = await ingestionPipeline!.extractAndStore(
          userMessage: userMessage,
          assistantResponse: assistantResponse,
        );
        if (count > 0) {
          AppLogger.instance.debug(LogSource.agent,
              'KG extraction: $count items stored (session=$sessionKey)');
        }
      } catch (e) {
        AppLogger.instance.warning(LogSource.agent,
            'KG extraction failed: $e', sessionKey: sessionKey);
      }
    });
  }

  /// Brief language hint in the target language.
  /// Appended to the last user message to nudge weaker models.
  static String _languageHint(String locale) => switch (locale) {
        'fr' => 'Réponds en français',
        'es' => 'Responde en español',
        'de' => 'Antworte auf Deutsch',
        'it' => 'Rispondi in italiano',
        _ => 'Reply in English',
      };

  /// Build compact trace messages from a message list.
  List<LlmTraceMessage> _buildTraceMessages(List<Message> messages) {
    return messages.map((m) {
      final previewLen = m.role == 'tool' ? 200 : 200;
      return LlmTraceMessage(
        role: m.role,
        contentLength: m.content.length,
        preview: m.content.substring(0, min(previewLen, m.content.length)),
        toolName: m.name,
      );
    }).toList();
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
      final summaryLang = tr(config.resolvedLocale).agentSummarizeInstructions;
      final summarizeSystemPrompt =
          'Summarize the following conversation concisely, preserving key facts, decisions, and context. $summaryLang';
      final summarizeMessages = [
        Message(role: 'system', content: summarizeSystemPrompt),
        Message(role: 'user', content: summaryContent),
      ];
      final sw = Stopwatch()..start();
      final response = await provider.chat(
        messages: summarizeMessages,
        model: config.agent.model,
        options: {'max_tokens': 1024, 'temperature': 0.3},
      );
      sw.stop();

      LlmTraceLogger.instance.log(LlmTrace(
        provider: provider.providerName,
        model: config.agent.model,
        callType: 'summarize',
        messageCount: summarizeMessages.length,
        systemPromptChars: summarizeSystemPrompt.length,
        systemPromptPreview: summarizeSystemPrompt.substring(
            0, min(500, summarizeSystemPrompt.length)),
        messages: _buildTraceMessages(summarizeMessages),
        responseContent: response.content,
        responseChars: response.content.length,
        finishReason: response.finishReason,
        promptTokens: response.usage?.promptTokens,
        completionTokens: response.usage?.completionTokens,
        totalTokens: response.usage?.totalTokens,
        latencyMs: sw.elapsedMilliseconds,
      ));

      session.summary = response.content;
    } catch (_) {
      // If summarization fails, just set a basic summary from truncated messages
      session.summary =
          'Previous conversation (${messagesToSummarize.length} messages) about: '
          '${messagesToSummarize.firstWhere((m) => m.role == "user", orElse: () => const Message(role: "user", content: "various topics")).content.substring(0, 100)}...';
    }
  }
}
