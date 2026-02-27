import 'dart:convert';
import 'dart:math';

import '../../config/llm_trace.dart';
import '../../providers/llm_provider.dart';
import '../../providers/llm_response.dart';
import '../../services/app_logger.dart';
import '../../services/llm_trace_logger.dart';
import '../../config/log_entry.dart';

/// Extracted data from a conversation turn.
class ExtractionResult {
  final List<ExtractedEntity> entities;
  final List<ExtractedRelation> relations;
  final List<ExtractedFact> facts;

  const ExtractionResult({
    this.entities = const [],
    this.relations = const [],
    this.facts = const [],
  });

  bool get isEmpty =>
      entities.isEmpty && relations.isEmpty && facts.isEmpty;
}

class ExtractedEntity {
  final String name;
  final String type;
  final String? summary;

  const ExtractedEntity({
    required this.name,
    this.type = 'CONCEPT',
    this.summary,
  });
}

class ExtractedRelation {
  final String source;
  final String predicate;
  final String target;
  final double confidence;

  const ExtractedRelation({
    required this.source,
    required this.predicate,
    required this.target,
    this.confidence = 0.9,
  });
}

class ExtractedFact {
  final String entity;
  final String key;
  final String value;
  final String type;

  const ExtractedFact({
    required this.entity,
    required this.key,
    required this.value,
    this.type = 'string',
  });
}

/// LLM-based entity/relation/fact extractor.
///
/// Sends a structured extraction prompt to the LLM and parses
/// the JSON response into typed extraction results.
class EntityExtractor {
  final LLMProvider provider;
  final String model;

  /// The language all extracted data must be stored in (e.g. 'en', 'fr').
  /// When null, extraction defaults to English.
  final String? kbLanguage;

  EntityExtractor({
    required this.provider,
    required this.model,
    this.kbLanguage,
  });

  /// Build the extraction system prompt, including a language directive
  /// at the end (recency bias) when a KB language is set.
  String get _systemPrompt {
    final base = '''You are an entity extraction system. Extract entities, relations, and facts from the conversation below.

Return ONLY valid JSON with this exact structure:
{
  "entities": [{"name": "...", "type": "PERSON|PLACE|ORG|EVENT|CONCEPT|DATE", "summary": "..."}],
  "relations": [{"source": "...", "predicate": "...", "target": "...", "confidence": 0.9}],
  "facts": [{"entity": "...", "key": "...", "value": "...", "type": "string|number|date"}]
}

Rules:
- Only extract clearly stated information. Do NOT infer or hallucinate.
- Entity names should be proper nouns or specific concepts mentioned.
- Common predicates: WORKS_AT, KNOWS, LIVES_IN, LOCATED_IN, PART_OF, HAS, IS_A, SCHEDULED_FOR, RELATED_TO.
- Facts capture attributes: appointments, preferences, addresses, phone numbers, dates, etc.
- If nothing meaningful to extract, return {"entities": [], "relations": [], "facts": []}.
- Return raw JSON only, no markdown fences, no explanation.''';

    if (kbLanguage == null) return base;

    final langName = _languageName(kbLanguage!);
    return '$base\n\n'
        'IMPORTANT: All entity names, fact keys, fact values, relation predicates, '
        'and entity summaries MUST be in $langName. If the conversation is in a '
        'different language, translate all extracted data to $langName.';
  }

  static String _languageName(String code) => switch (code) {
        'fr' => 'French',
        'es' => 'Spanish',
        'de' => 'German',
        'it' => 'Italian',
        _ => 'English',
      };

  /// Extract entities, relations, and facts from a conversation turn.
  Future<ExtractionResult> extract({
    required String userMessage,
    required String assistantResponse,
  }) async {
    final conversationText =
        'User: $userMessage\nAssistant: $assistantResponse';

    final extractMessages = [
      Message(role: 'system', content: _systemPrompt),
      Message(role: 'user', content: conversationText),
    ];
    final sw = Stopwatch()..start();
    try {
      final response = await provider.chat(
        messages: extractMessages,
        model: model,
        options: {'max_tokens': 2048, 'temperature': 0.1},
      );
      sw.stop();

      LlmTraceLogger.instance.log(LlmTrace(
        provider: provider.providerName,
        model: model,
        callType: 'extract',
        messageCount: extractMessages.length,
        systemPromptChars: _systemPrompt.length,
        systemPromptPreview:
            _systemPrompt.substring(0, min(500, _systemPrompt.length)),
        messages: extractMessages
            .map((m) => LlmTraceMessage(
                  role: m.role,
                  contentLength: m.content.length,
                  preview:
                      m.content.substring(0, min(200, m.content.length)),
                ))
            .toList(),
        responseContent: response.content,
        responseChars: response.content.length,
        finishReason: response.finishReason,
        promptTokens: response.usage?.promptTokens,
        completionTokens: response.usage?.completionTokens,
        totalTokens: response.usage?.totalTokens,
        latencyMs: sw.elapsedMilliseconds,
      ));

      return _parseResponse(response.content);
    } catch (e) {
      sw.stop();

      LlmTraceLogger.instance.log(LlmTrace(
        provider: provider.providerName,
        model: model,
        callType: 'extract',
        messageCount: extractMessages.length,
        systemPromptChars: _systemPrompt.length,
        systemPromptPreview:
            _systemPrompt.substring(0, min(500, _systemPrompt.length)),
        messages: extractMessages
            .map((m) => LlmTraceMessage(
                  role: m.role,
                  contentLength: m.content.length,
                  preview:
                      m.content.substring(0, min(200, m.content.length)),
                ))
            .toList(),
        error: e.toString(),
        latencyMs: sw.elapsedMilliseconds,
      ));

      AppLogger.instance.warning(
        LogSource.agent,
        'Entity extraction failed: $e',
      );
      return const ExtractionResult();
    }
  }

  /// Parse the LLM JSON response into an ExtractionResult.
  ExtractionResult _parseResponse(String content) {
    try {
      // Strip markdown fences if present
      var json = content.trim();
      if (json.startsWith('```')) {
        json = json.replaceFirst(RegExp(r'^```\w*\n?'), '');
        json = json.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final data = jsonDecode(json) as Map<String, dynamic>;

      final entities = (data['entities'] as List?)
              ?.map((e) => ExtractedEntity(
                    name: e['name'] as String? ?? '',
                    type: e['type'] as String? ?? 'CONCEPT',
                    summary: e['summary'] as String?,
                  ))
              .where((e) => e.name.isNotEmpty)
              .toList() ??
          [];

      final relations = (data['relations'] as List?)
              ?.map((r) => ExtractedRelation(
                    source: r['source'] as String? ?? '',
                    predicate: r['predicate'] as String? ?? 'RELATED_TO',
                    target: r['target'] as String? ?? '',
                    confidence:
                        (r['confidence'] as num?)?.toDouble() ?? 0.9,
                  ))
              .where((r) => r.source.isNotEmpty && r.target.isNotEmpty)
              .toList() ??
          [];

      final facts = (data['facts'] as List?)
              ?.map((f) => ExtractedFact(
                    entity: f['entity'] as String? ?? '',
                    key: f['key'] as String? ?? '',
                    value: f['value'] as String? ?? '',
                    type: f['type'] as String? ?? 'string',
                  ))
              .where(
                  (f) => f.entity.isNotEmpty && f.key.isNotEmpty && f.value.isNotEmpty)
              .toList() ??
          [];

      return ExtractionResult(
        entities: entities,
        relations: relations,
        facts: facts,
      );
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Failed to parse extraction JSON: $e',
      );
      return const ExtractionResult();
    }
  }
}
