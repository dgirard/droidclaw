/// Model classes for KB deduplication and cleanup (U17).
///
/// Extracted verbatim from `kb_maintenance_service.dart`; that file
/// re-exports them so existing imports keep working.
library;

/// A candidate pair of potentially duplicate entities.
class DuplicateCandidate {
  final int idA;
  final int idB;
  final String nameA;
  final String nameB;
  final double nameScore;
  final double relationScore;
  final double factScore;
  final double compositeScore;
  final List<String> aliasesA;
  final List<String> aliasesB;
  final List<String> factSummariesA;
  final List<String> factSummariesB;

  const DuplicateCandidate({
    required this.idA,
    required this.idB,
    required this.nameA,
    required this.nameB,
    required this.nameScore,
    required this.relationScore,
    required this.factScore,
    required this.compositeScore,
    this.aliasesA = const [],
    this.aliasesB = const [],
    this.factSummariesA = const [],
    this.factSummariesB = const [],
  });
}

/// A scored and verified duplicate pair (after optional LLM verification).
class ScoredPair {
  final int primaryId;
  final int secondaryId;
  final String primaryName;
  final String secondaryName;
  final double score;
  final String justification;
  final int level; // 1, 2, or 3

  const ScoredPair({
    required this.primaryId,
    required this.secondaryId,
    required this.primaryName,
    required this.secondaryName,
    required this.score,
    required this.justification,
    required this.level,
  });
}

/// A candidate pair of duplicate facts within the same entity.
class DuplicateFactCandidate {
  final int entityId;
  final String entityName;
  final int factIdA;
  final int factIdB;
  final String factKey;
  final String valueA;
  final String valueB;
  final double similarity;
  final String source; // 'string', 'date', 'cross-key'

  const DuplicateFactCandidate({
    required this.entityId,
    required this.entityName,
    required this.factIdA,
    required this.factIdB,
    required this.factKey,
    required this.valueA,
    required this.valueB,
    required this.similarity,
    required this.source,
  });
}

/// A scored duplicate fact pair with LLM verdict.
class ScoredFactPair {
  final int entityId;
  final String entityName;
  final int factIdKeep;
  final int factIdRemove;
  final String factKey;
  final String valueKeep;
  final String valueRemove;
  final double score;
  final String justification;

  const ScoredFactPair({
    required this.entityId,
    required this.entityName,
    required this.factIdKeep,
    required this.factIdRemove,
    required this.factKey,
    required this.valueKeep,
    required this.valueRemove,
    required this.score,
    required this.justification,
  });
}

/// Bundle of facts for a single entity, for LLM cross-key dedup.
class EntityFactBundle {
  final int entityId;
  final String entityName;
  final List<Map<String, dynamic>> facts;

  const EntityFactBundle({
    required this.entityId,
    required this.entityName,
    required this.facts,
  });
}

// ─── Cleanup operation types ─────────────────────────────────────────

/// Sealed class for KB cleanup operations proposed by LLM.
sealed class CleanupOperation {
  final String reason;
  final int? confidence;
  const CleanupOperation({required this.reason, this.confidence});
}

/// Delete a garbage/ephemeral entity.
class CleanupDelete extends CleanupOperation {
  final int entityId;
  const CleanupDelete({required this.entityId, required super.reason, super.confidence});
}

/// Merge duplicate entities.
class CleanupMerge extends CleanupOperation {
  final int primaryId;
  final int secondaryId;
  const CleanupMerge({
    required this.primaryId,
    required this.secondaryId,
    required super.reason,
    super.confidence,
  });
}

/// Delete a duplicate/stale relation.
class CleanupDeleteRelation extends CleanupOperation {
  final int relationId;
  const CleanupDeleteRelation({required this.relationId, required super.reason, super.confidence});
}

/// Result of executing cleanup operations, with detailed execution log.
class CleanupResult {
  final int mergeCount;
  final int deleteCount;
  final int deleteRelationCount;
  final List<String> errors;
  /// Detailed log of each executed operation (human-readable).
  final List<String> executedOps;

  const CleanupResult({
    required this.mergeCount,
    required this.deleteCount,
    required this.deleteRelationCount,
    required this.errors,
    required this.executedOps,
  });

  int get totalExecuted => mergeCount + deleteCount + deleteRelationCount;
}
