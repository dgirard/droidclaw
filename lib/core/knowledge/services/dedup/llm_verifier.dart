import 'dart:math';

import '../../../config/log_entry.dart';
import '../../../providers/llm_provider.dart';
import '../../../providers/llm_response.dart';
import '../../../services/app_logger.dart';
import '../../../../shared/constants.dart';
import '../../models/dedup_models.dart';
import '../llm_json_parser.dart';
import 'truncate.dart';

/// LLM semantic verification of dedup candidates (entities and facts).
///
/// Extracted from [KbMaintenanceService] (U17). Sends only names, aliases,
/// and fact key summaries (no raw PII values like phone numbers or
/// addresses). Falls back to deterministic-only scores on LLM failure.
class DedupLlmVerifier {
  final LLMProvider _llmProvider;
  final String _model;

  DedupLlmVerifier({
    required LLMProvider llmProvider,
    required String model,
  })  : _llmProvider = llmProvider,
        _model = model;

  /// Verify candidates via LLM semantic analysis.
  ///
  /// Returns pairs with LLM-adjusted scores, justifications, and level
  /// classification. Falls back to deterministic-only scores on LLM failure.
  Future<List<ScoredPair>> verifyWithLLM(
    List<DuplicateCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return [];

    // Split into batches of <=dedupVerifyBatchSize pairs, capped at
    // dedupVerifyMaxBatches LLM calls.
    const batchSize = AppConstants.dedupVerifyBatchSize;
    final batches = <List<DuplicateCandidate>>[];
    for (var i = 0;
        i < candidates.length &&
            batches.length < AppConstants.dedupVerifyMaxBatches;
        i += batchSize) {
      batches.add(candidates.sublist(
        i,
        min(i + batchSize, candidates.length),
      ));
    }

    final allPairs = <ScoredPair>[];

    for (final batch in batches) {
      final llmPairs = await _verifyBatch(batch);
      allPairs.addAll(llmPairs);
    }

    // Add remaining candidates (beyond the batch cap) as deterministic-only
    final processedCount = min(batches.length * batchSize, candidates.length);
    for (var i = processedCount; i < candidates.length; i++) {
      allPairs.add(_toDeterministicPair(candidates[i]));
    }

    // Sort by score descending
    allPairs.sort((a, b) => b.score.compareTo(a.score));
    return allPairs;
  }

  /// Verify duplicate fact candidates via LLM.
  ///
  /// Two-phase approach:
  /// 1. Send entity fact bundles to LLM for cross-key semantic detection
  ///    (catches vélo/bicyclette that string similarity cannot detect).
  /// 2. Verify deterministic candidates (same-key duplicates).
  Future<List<ScoredFactPair>> verifyFactsWithLLM(
    List<DuplicateFactCandidate> candidates, {
    List<EntityFactBundle> factBundles = const [],
  }) async {
    final allResults = <ScoredFactPair>[];

    // Phase 1: LLM cross-key detection on entity fact bundles
    if (factBundles.isNotEmpty) {
      final bundles =
          factBundles.take(AppConstants.dedupFactBundleLimit).toList();
      final buf = StringBuffer();
      buf.writeln('For each entity, list ALL facts. Identify pairs of facts '
          'that express the SAME information (semantic duplicates).\n');
      for (final b in bundles) {
        buf.writeln('Entity "${b.entityName}" (ID ${b.entityId}):');
        for (final f in b.facts) {
          buf.writeln('  - fact_id=${f['id']}: ${f['key']} = ${f['value']}');
        }
        buf.writeln();
      }

      final systemPrompt = '''You are a semantic deduplication specialist.
For each entity, identify facts that express the SAME information.

Examples of duplicate facts:
- "vélo = possède un vélo" and "bicyclette = possède une bicyclette" (same object)
- "tel = 06 12 34" and "telephone = 06 12 34" (same fact, different key)
- "born = 1986" and "birthday = March 14, 1986" (compatible dates)

Examples of NON-duplicates:
- "vélo rouge" and "vélo bleu" (different attributes)
- "born = 1985" and "born = 1986" (conflicting values)

For each duplicate pair found, return: entity_id, fact_id_keep (the more informative one), fact_id_remove, score (0-100), justification (max 50 chars).

Return ONLY valid JSON:
{"pairs":[{"entity_id":1,"fact_id_keep":10,"fact_id_remove":11,"score":95,"justification":"Same object, synonym"}]}

If no duplicates found, return: {"pairs":[]}
No markdown fences, no explanation.''';

      allResults.addAll(await _chatJson(
        systemPrompt: systemPrompt,
        userMessage: buf.toString(),
        parse: (content) => _parseCrossKeyResponse(content, bundles),
        failureLabel: 'Dream cross-key fact detection failed',
        onFailure: () => const <ScoredFactPair>[],
      ));
    }

    // Phase 2: Verify deterministic candidates (same-key duplicates)
    if (candidates.isEmpty) return allResults;

    final batch =
        candidates.take(AppConstants.dedupFactVerifyBatchSize).toList();
    final buf = StringBuffer();
    buf.writeln('| # | Entity | Fact Key | Value A | Value B | Det. Score |');
    buf.writeln('|---|--------|----------|---------|---------|------------|');
    for (var i = 0; i < batch.length; i++) {
      final c = batch[i];
      buf.writeln(
        '| ${i + 1} '
        '| ${_sanitize(c.entityName)} '
        '| ${_sanitize(c.factKey)} '
        '| ${_sanitize(c.valueA)} '
        '| ${_sanitize(c.valueB)} '
        '| ${(c.similarity * 100).round()}% |',
      );
    }

    final systemPrompt = '''You are a semantic deduplication specialist.
Analyze pairs of facts on the SAME entity. Determine if they express the same information.

Examples of duplicates:
- "vélo" and "bicyclette" (same object)
- "born 1986" and "born March 14, 1986" (compatible dates)
- "tel: 06 12 34" and "phone: 06 12 34" (same fact, different key)

Examples of NON-duplicates:
- "vélo rouge" and "vélo bleu" (different objects)
- "born 1985" and "born 1986" (conflicting dates)

For each pair, return: index (1-based), score (0-100), keep (A or B — the more informative one), justification (max 50 chars).

Return ONLY valid JSON:
{"pairs":[{"index":1,"score":95,"keep":"B","justification":"Same object, B more precise"}]}

No markdown fences, no explanation.''';

    return _chatJson(
      systemPrompt: systemPrompt,
      userMessage: buf.toString(),
      parse: (content) => _parseFactLlmResponse(content, batch),
      failureLabel: 'Dream fact verification failed',
      onFailure: () => batch.map(_toDeterministicFactPair).toList(),
    );
  }

  /// Build a markdown table from candidate pairs for LLM verification.
  ///
  /// Exposed as static for testing. More compact than JSON, fewer tokens.
  static String buildVerificationTable(List<DuplicateCandidate> batch) {
    final buf = StringBuffer();
    buf.writeln('| # | ID_A | Name A | Aliases A | Facts A | ID_B | Name B | Aliases B | Facts B | Det. Score |');
    buf.writeln('|---|------|--------|-----------|---------|------|--------|-----------|---------|------------|');
    for (var i = 0; i < batch.length; i++) {
      final c = batch[i];
      buf.writeln(
        '| ${i + 1} '
        '| ${c.idA} | ${_sanitize(c.nameA)} '
        '| ${c.aliasesA.map(_sanitize).join(", ")} '
        '| ${c.factSummariesA.map(_sanitize).join("; ")} '
        '| ${c.idB} | ${_sanitize(c.nameB)} '
        '| ${c.aliasesB.map(_sanitize).join(", ")} '
        '| ${c.factSummariesB.map(_sanitize).join("; ")} '
        '| ${(c.compositeScore * 100).round()}% |',
      );
    }
    return buf.toString();
  }

  Future<List<ScoredPair>> _verifyBatch(
    List<DuplicateCandidate> batch,
  ) async {
    final validIds = <int>{};
    for (final c in batch) {
      validIds.add(c.idA);
      validIds.add(c.idB);
    }

    final systemPrompt = '''You are an Entity Resolution and Master Data Management specialist.
Analyze the candidate duplicate pairs in the table below.

SCORING METHOD (0 to 100%):
- Names & Aliases (40%): Spelling similarity, phonetic match, identical concepts (e.g. "URL rori" and "slug rori")
- Shared Relations (40%): Do they target the same people, places, or concepts?
- Facts (20%): Shared phone numbers, dates, or complementary attributes

For each pair, return: id_a, id_b, score (0-100), justification (max 50 chars).

Return ONLY valid JSON:
{"pairs":[{"id_a":1,"id_b":2,"score":85,"justification":"Same person, typo variant"}]}

No markdown fences, no explanation.''';

    return _chatJson(
      systemPrompt: systemPrompt,
      userMessage: buildVerificationTable(batch),
      parse: (content) => parseLlmResponse(content, batch, validIds),
      failureLabel: 'Dream LLM verification failed',
      // Fallback to deterministic scores
      onFailure: () => batch.map(_toDeterministicPair).toList(),
    );
  }

  /// Shared LLM round-trip for the verification prompts: system + user
  /// messages at temperature 0.1, [parse] on the response content, and a
  /// warn + [onFailure] fallback when the call throws.
  Future<T> _chatJson<T>({
    required String systemPrompt,
    required String userMessage,
    required T Function(String content) parse,
    required String failureLabel,
    required T Function() onFailure,
  }) async {
    try {
      final response = await _llmProvider.chat(
        messages: [
          Message(role: 'system', content: systemPrompt),
          Message(role: 'user', content: userMessage),
        ],
        model: _model,
        options: {'temperature': 0.1},
      );
      return parse(response.content);
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        '$failureLabel: ${e.runtimeType}',
      );
      return onFailure();
    }
  }

  /// Parse LLM JSON response into scored pairs.
  ///
  /// Exposed as static for testing. Handles markdown fences, missing pairs,
  /// and invalid IDs gracefully.
  static List<ScoredPair> parseLlmResponse(
    String content,
    List<DuplicateCandidate> batch,
    Set<int> validIds,
  ) {
    try {
      final data = LlmJsonParser.decodeObject(content);
      final pairs = data['pairs'] as List? ?? [];

      // Build lookup from batch
      final batchLookup = <String, DuplicateCandidate>{};
      for (final c in batch) {
        final key = '${c.idA}:${c.idB}';
        batchLookup[key] = c;
      }

      final result = <ScoredPair>[];
      final processedKeys = <String>{};

      for (final p in pairs) {
        final idA = (p['id_a'] as num?)?.toInt();
        final idB = (p['id_b'] as num?)?.toInt();
        if (idA == null || idB == null) continue;

        // Validate IDs against sent set
        if (!validIds.contains(idA) || !validIds.contains(idB)) {
          AppLogger.instance.warning(
            LogSource.agent,
            'Dream: LLM returned unknown IDs $idA/$idB, skipping',
          );
          continue;
        }

        final score = ((p['score'] as num?)?.toDouble() ?? 0) / 100.0;
        final justification =
            truncate((p['justification'] as String?) ?? '', 100);

        // Find matching candidate
        final key1 = '$idA:$idB';
        final key2 = '$idB:$idA';
        final candidate = batchLookup[key1] ?? batchLookup[key2];
        if (candidate == null) continue;

        processedKeys.add('${candidate.idA}:${candidate.idB}');

        result.add(ScoredPair(
          primaryId: candidate.idA,
          secondaryId: candidate.idB,
          primaryName: candidate.nameA,
          secondaryName: candidate.nameB,
          score: score,
          justification: justification,
          level: _classifyLevel(score),
        ));
      }

      // Add any batch entries not returned by LLM as deterministic
      for (final c in batch) {
        final key = '${c.idA}:${c.idB}';
        if (!processedKeys.contains(key)) {
          result.add(_toDeterministicPair(c));
        }
      }

      return result;
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Dream: failed to parse LLM response: ${e.runtimeType}',
      );
      return batch.map(_toDeterministicPair).toList();
    }
  }

  List<ScoredFactPair> _parseFactLlmResponse(
    String content,
    List<DuplicateFactCandidate> batch,
  ) {
    try {
      final data = LlmJsonParser.decodeObject(content);
      final pairs = data['pairs'] as List? ?? [];
      final result = <ScoredFactPair>[];
      final processed = <int>{};

      for (final p in pairs) {
        final index = ((p['index'] as num?)?.toInt() ?? 0) - 1;
        if (index < 0 || index >= batch.length) continue;
        if (processed.contains(index)) continue;
        processed.add(index);

        final c = batch[index];
        final score = ((p['score'] as num?)?.toDouble() ?? 0) / 100.0;
        final keep = (p['keep'] as String?) ?? 'A';
        final justification =
            truncate((p['justification'] as String?) ?? '', 100);

        final keepA = keep.toUpperCase() == 'A';
        result.add(ScoredFactPair(
          entityId: c.entityId,
          entityName: c.entityName,
          factIdKeep: keepA ? c.factIdA : c.factIdB,
          factIdRemove: keepA ? c.factIdB : c.factIdA,
          factKey: c.factKey,
          valueKeep: keepA ? c.valueA : c.valueB,
          valueRemove: keepA ? c.valueB : c.valueA,
          score: score,
          justification: justification,
        ));
      }

      // Add unprocessed as deterministic
      for (var i = 0; i < batch.length; i++) {
        if (processed.contains(i)) continue;
        result.add(_toDeterministicFactPair(batch[i]));
      }

      return result;
    } catch (e) {
      return batch.map(_toDeterministicFactPair).toList();
    }
  }

  List<ScoredFactPair> _parseCrossKeyResponse(
    String content,
    List<EntityFactBundle> bundles,
  ) {
    try {
      final data = LlmJsonParser.decodeObject(content);
      final pairs = data['pairs'] as List? ?? [];

      // Build valid fact ID set and entity name lookup
      final validFactIds = <int>{};
      final entityNameById = <int, String>{};
      final factInfoById = <int, Map<String, dynamic>>{};
      for (final b in bundles) {
        entityNameById[b.entityId] = b.entityName;
        for (final f in b.facts) {
          final fid = f['id'] as int;
          validFactIds.add(fid);
          factInfoById[fid] = {...f, 'entity_id': b.entityId};
        }
      }

      final result = <ScoredFactPair>[];
      for (final p in pairs) {
        final keepId = (p['fact_id_keep'] as num?)?.toInt();
        final removeId = (p['fact_id_remove'] as num?)?.toInt();
        if (keepId == null || removeId == null) continue;
        if (!validFactIds.contains(keepId) || !validFactIds.contains(removeId)) continue;

        final keepInfo = factInfoById[keepId]!;
        final removeInfo = factInfoById[removeId]!;
        final entityId = keepInfo['entity_id'] as int;
        final score = ((p['score'] as num?)?.toDouble() ?? 0) / 100.0;
        final justification =
            truncate((p['justification'] as String?) ?? '', 100);

        result.add(ScoredFactPair(
          entityId: entityId,
          entityName: entityNameById[entityId] ?? '',
          factIdKeep: keepId,
          factIdRemove: removeId,
          factKey: '${keepInfo['key']} / ${removeInfo['key']}',
          valueKeep: '${keepInfo['key']}: ${keepInfo['value']}',
          valueRemove: '${removeInfo['key']}: ${removeInfo['value']}',
          score: score,
          justification: justification,
        ));
      }
      return result;
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'Dream: failed to parse cross-key response: ${e.runtimeType}',
      );
      return [];
    }
  }

  static ScoredPair _toDeterministicPair(DuplicateCandidate c) {
    return ScoredPair(
      primaryId: c.idA,
      secondaryId: c.idB,
      primaryName: c.nameA,
      secondaryName: c.nameB,
      score: c.compositeScore,
      justification: 'Deterministic score only',
      level: _classifyLevel(c.compositeScore),
    );
  }

  static ScoredFactPair _toDeterministicFactPair(DuplicateFactCandidate c) {
    return ScoredFactPair(
      entityId: c.entityId,
      entityName: c.entityName,
      factIdKeep: c.factIdA,
      factIdRemove: c.factIdB,
      factKey: c.factKey,
      valueKeep: c.valueA,
      valueRemove: c.valueB,
      score: c.similarity,
      justification: 'Deterministic score only',
    );
  }

  static int _classifyLevel(double score) {
    if (score > AppConstants.dedupLevel1MinScore) return 1;
    if (score >= AppConstants.dedupLevel2MinScore) return 2;
    return 3;
  }

  static final _controlCharsRe = RegExp(r'[\x00-\x1f\x7f]');

  /// Sanitize entity content for LLM prompt: truncate and strip control chars.
  static String _sanitize(String s) {
    final cleaned = s.replaceAll(_controlCharsRe, '');
    return truncate(cleaned, 100);
  }
}
