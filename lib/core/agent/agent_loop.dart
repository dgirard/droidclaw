import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import '../config/app_config.dart';
import '../config/llm_trace.dart';
import '../config/log_entry.dart';
import '../knowledge/models/ranked_result.dart';
import '../knowledge/services/episode_store.dart';
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

  /// The arguments the tool was (or, on a cache hit, would have been)
  /// executed with — `force_fresh` already stripped. Additive (U4): existing
  /// consumers switch on the event type and ignore unknown fields.
  final Map<String, dynamic> arguments;

  const ToolResultEvent({
    required this.name,
    required this.result,
    this.arguments = const {},
  });
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

  /// Episodic memory (U4): when non-null, cacheable read-only tool calls are
  /// intercepted BEFORE execution (fresh episode → served from cache) and
  /// recorded after a successful execution.
  final EpisodeStore? episodeStore;

  AgentLoop({
    required this.provider,
    required this.config,
    required this.sessions,
    required this.tools,
    required this.contextBuilder,
    this.knowledgeService,
    this.ingestionPipeline,
    this.episodeStore,
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
      await _summarize(session, sessionKey);
      // No fsync: if this write is lost, the on-disk session still holds the
      // full pre-summarization history (a superset) — summarization simply
      // re-runs. The turn-ending save below flushes everything anyway.
      await sessions.save(session, flush: false);
    }

    // Pre-query: inject Knowledge Graph context if available
    String? kgContext;
    if (knowledgeService != null) {
      try {
        // With an embedder configured, queryRelevant's vector path bridges
        // the semantic gap directly — no extra LLM round-trip per turn.
        // Without one, LLM keyword expansion remains the only bridge between
        // paraphrased questions and stored fact tokens (see docs/solutions/
        // logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-
        // semantic-gap.md), so it stays on in that degraded mode.
        final hasEmbedder = knowledgeService!.hasEmbedder;
        var kgQuery = hasEmbedder
            ? userMessage
            : await _expandQueryForKG(userMessage);

        var results = await knowledgeService!.queryRelevant(
          kgQuery,
          limit: 10,
        );

        // The embedder was supposed to bridge the semantic gap, but the
        // embed call failed at query time (API down, bad key, ...): the
        // call above silently degraded to lexical-only on the RAW query —
        // exactly the documented pre-fix failure. Retry once with LLM
        // keyword expansion (degraded mode).
        if (hasEmbedder && knowledgeService!.lastQueryVectorPathFailed) {
          AppLogger.instance.warning(LogSource.agent,
              'KG retrieval degraded: query embedding failed, retrying '
              'pre-query with LLM keyword expansion',
              sessionKey: sessionKey);
          // The retry has its own try/catch: if the expansion LLM call (or
          // the second query) throws, the first query's LEXICAL results must
          // survive — discarding them would doubly degrade the turn.
          try {
            final expandedQuery = await _expandQueryForKG(userMessage);
            results = await knowledgeService!.queryRelevant(
              expandedQuery,
              limit: 10,
            );
            kgQuery = expandedQuery;
          } catch (e) {
            AppLogger.instance.warning(LogSource.agent,
                'KG degraded retry failed: $e — keeping the lexical results '
                'from the first query',
                sessionKey: sessionKey);
          }
        }
        if (results.isNotEmpty) {
          kgContext = formatKnowledgeContext(results);
          AppLogger.instance.debug(LogSource.agent,
              'KG pre-query: ${results.length} results '
              '(query: "${kgQuery.substring(0, min(100, kgQuery.length))}")');
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
        final hint = languageHint(resolvedLocale);
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

        await sessions.save(session);
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

        // Episodic interception (U4): strip the cache-control param FIRST so
        // neither the cache key nor the tool ever sees it, then serve a
        // fresh episode instead of re-executing a cacheable read-only tool.
        final args = Map<String, dynamic>.from(toolCall.arguments);
        final forceFresh = args.remove('force_fresh') == true;

        ToolResult result;
        Episode? episode;
        if (episodeStore != null &&
            !forceFresh &&
            EpisodeStore.isCacheable(toolCall.name)) {
          try {
            episode = await episodeStore!.lookup(toolCall.name, args);
          } catch (e) {
            AppLogger.instance.warning(LogSource.agent,
                'Episode lookup failed for ${toolCall.name}: $e',
                sessionKey: sessionKey);
          }
        }

        if (episode != null) {
          final ageMin =
              DateTime.now().difference(episode.createdAt).inMinutes;
          result = ToolResult(
            forLLM: '(cached result from $ageMin min ago — pass '
                'force_fresh=true if staleness matters)\n'
                '${episode.resultRedacted}',
            forUser: '${episode.resultRedacted} (cached, ${ageMin}min)',
          );
          AppLogger.instance.debug(LogSource.agent,
              'Tool ${toolCall.name}: served from episode cache '
              '(age=${ageMin}min)');
        } else {
          result = await tools.execute(toolCall.name, args);
          if (episodeStore != null && !result.isError) {
            // record() is a structural no-op for non-cacheable tools, error
            // results, and geo-keyed tools with no known location cell.
            try {
              await episodeStore!
                  .record(toolCall.name, args, result, sessionKey: sessionKey);
            } catch (e) {
              AppLogger.instance.warning(LogSource.agent,
                  'Episode record failed for ${toolCall.name}: $e',
                  sessionKey: sessionKey);
            }
          }
        }

        // A successful device-location reading updates the geo context that
        // keys weather/transit/directions episodes.
        if (!result.isError) {
          episodeStore?.maybeUpdateLocationContext(
              toolCall.name, result.forLLM);
        }

        AppLogger.instance.debug(LogSource.agent,
            'Tool ${toolCall.name} result: '
            '${result.forLLM.length} chars, error=${result.isError}');

        yield ToolResultEvent(
            name: toolCall.name, result: result, arguments: args);

        // Add tool result to session
        session.addMessage(Message(
          role: 'tool',
          content: result.forLLM,
          toolCallId: toolCall.id,
          name: toolCall.name,
        ));
      }
      // Persist once after the tool batch, WITHOUT fsync (~10-50ms each on
      // Android): the awaited Hive put survives a process kill via the OS
      // page cache; the residual power-loss window is accepted for
      // reproducible tool results. The turn always ends in a flushed save
      // (final response / error / max-iterations). See the flush policy on
      // SessionManager.
      await sessions.save(session, flush: false);
    }

    // Max iterations reached
    await sessions.save(session);
    yield ErrorEvent(tr(config.resolvedLocale).agentMaxIterations);
  }

  /// Expand a user query into search keywords for Knowledge Graph retrieval.
  ///
  /// Degraded-mode fallback only: called when no embedding provider is
  /// configured, so lexical FTS is the sole retrieval signal. Uses a fast
  /// LLM call (max_tokens: 50) to bridge the semantic gap between natural
  /// language questions and stored entity/fact tokens. When an embedder is
  /// available, the vector path in [KnowledgeService.queryRelevant] does
  /// this without an extra LLM round-trip.
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

  /// Fire-and-forget KG extraction over the conversation text a
  /// summarization is about to drop (U4). Role-prefixed and capped by the
  /// caller. Errors are logged, never surfaced — same posture as
  /// [_extractAsync].
  void _ingestCompressedHistoryAsync(
      String compressedText, String summary, String sessionKey) {
    Future(() async {
      try {
        final count = await ingestionPipeline!.extractAndStore(
          userMessage: compressedText,
          assistantResponse: summary,
          sessionKey: sessionKey,
        );
        AppLogger.instance.debug(LogSource.agent,
            'Summarization ingestion: $count items stored '
            '(session=$sessionKey, ${compressedText.length} chars)');
      } catch (e) {
        AppLogger.instance.warning(LogSource.agent,
            'Summarization ingestion failed: $e', sessionKey: sessionKey);
      }
    });
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
          sessionKey: sessionKey,
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

  /// Brief language hint written IN the target language (Layer 2 of the
  /// language-enforcement contract; see docs/solutions/runtime-errors/
  /// gemini-flash-ignores-system-prompt-language-instructions.md).
  /// Appended to the LLM-bound copy of the last user message only — never
  /// stored — to nudge weak models that follow history language patterns
  /// over system-prompt directives.
  ///
  /// This is NOT a language-NAME map (that single source is
  /// [KnowledgeConfig.languageName]); the hint must use target-language
  /// tokens for priming. Keys mirror the supported-locale set; unknown
  /// locales fall back to English, consistent with `languageName`.
  /// Pinned by test/agent/language_compliance_test.dart.
  @visibleForTesting
  static String languageHint(String locale) => switch (locale) {
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
  Future<void> _summarize(Session session, String sessionKey) async {
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
        sessionKey: sessionKey,
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

      // U4: the compressed-away conversation becomes knowledge instead of
      // being dropped. Fire-and-forget (logged), capped, only after a
      // SUCCESSFUL summary — the fallback path below has no LLM available.
      if (ingestionPipeline != null) {
        final capped = summaryContent.length >
                AppConstants.episodeSummarizationIngestMaxChars
            ? summaryContent.substring(
                0, AppConstants.episodeSummarizationIngestMaxChars)
            : summaryContent;
        _ingestCompressedHistoryAsync(capped, response.content, sessionKey);
      }
    } catch (_) {
      // If summarization fails, just set a basic summary from truncated messages
      final firstUserContent = messagesToSummarize
          .firstWhere((m) => m.role == 'user',
              orElse: () =>
                  const Message(role: 'user', content: 'various topics'))
          .content;
      session.summary =
          'Previous conversation (${messagesToSummarize.length} messages) about: '
          '${firstUserContent.substring(0, min(100, firstUserContent.length))}...';
    }
  }
}
