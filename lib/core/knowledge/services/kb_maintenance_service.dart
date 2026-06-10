import '../../providers/llm_provider.dart';
import '../../../shared/constants.dart';
import '../database/knowledge_graph_db.dart';
import '../models/dedup_models.dart';
import 'dedup/candidate_generator.dart';
import 'dedup/cleanup_service.dart';
import 'dedup/llm_verifier.dart';
import 'knowledge_service.dart';

export '../models/dedup_models.dart';

/// Orchestrator for KB maintenance: duplicate detection, entity merging,
/// and LLM-based cleanup.
///
/// Slimmed in U17 to delegate to focused collaborators:
/// - [CandidateGenerator] — token-blocking + deterministic scoring
/// - [DedupLlmVerifier] — LLM semantic verification of candidate pairs
/// - [KbCleanupService] — snapshot chunking, cleanup proposal/execution
///
/// The public API is unchanged (dream_tool.dart and the dedup tests call
/// it); the model classes moved to `../models/dedup_models.dart` and are
/// re-exported above.
class KbMaintenanceService {
  final KnowledgeGraphDB _db;
  final CandidateGenerator _candidates;
  final DedupLlmVerifier _verifier;
  final KbCleanupService _cleanup;

  /// The language for LLM prompts (e.g. 'en', 'fr'). Null = English.
  final String? kbLanguage;

  KbMaintenanceService({
    required KnowledgeGraphDB db,
    required KnowledgeService knowledgeService,
    required LLMProvider llmProvider,
    required String model,
    this.kbLanguage,
  })  : _db = db,
        _candidates = CandidateGenerator(
          db: db,
          knowledgeService: knowledgeService,
        ),
        _verifier = DedupLlmVerifier(
          llmProvider: llmProvider,
          model: model,
        ),
        _cleanup = KbCleanupService(
          db: db,
          llmProvider: llmProvider,
          model: model,
          kbLanguage: kbLanguage,
        );

  // ─── Duplicate entities ────────────────────────────────────────────

  /// Find duplicate candidates using token blocking + deterministic scoring.
  ///
  /// If [fullScan] is false and [lastDreamAt] is provided, only compares
  /// entities created after [lastDreamAt] against all active entities.
  /// Returns scored pairs sorted by composite score descending, capped at [maxPairs].
  Future<List<DuplicateCandidate>> findCandidates({
    int maxPairs = AppConstants.dedupMaxPairsDefault,
    bool fullScan = false,
    int? lastDreamAt,
  }) =>
      _candidates.findCandidates(
        maxPairs: maxPairs,
        fullScan: fullScan,
        lastDreamAt: lastDreamAt,
      );

  /// Verify candidates via LLM semantic analysis.
  ///
  /// Sends only names, aliases, and fact key summaries (no raw PII values
  /// like phone numbers or addresses). Returns pairs with LLM-adjusted
  /// scores, justifications, and level classification.
  ///
  /// Falls back to deterministic-only scores on LLM failure.
  Future<List<ScoredPair>> verifyWithLLM(
    List<DuplicateCandidate> candidates,
  ) =>
      _verifier.verifyWithLLM(candidates);

  /// Execute merge of [secondaryId] into [primaryId].
  ///
  /// Delegates to [KnowledgeGraphDB.mergeEntities] which handles the
  /// full 12-step merge within a single SQLite transaction.
  Future<MergeResult> merge(int primaryId, int secondaryId) async {
    return await _db.mergeEntities(primaryId, secondaryId);
  }

  // ─── Duplicate facts ───────────────────────────────────────────────

  /// Find duplicate facts within the same entity.
  ///
  /// Detects semantically equivalent fact values on the same entity
  /// (e.g., "vélo" and "bicyclette" as possessions of the same person).
  /// Uses LLM to identify semantic duplicates that string similarity misses.
  Future<({List<DuplicateFactCandidate> candidates, List<EntityFactBundle> bundles})> findDuplicateFacts({
    int maxEntities = AppConstants.dedupFactScanMaxEntities,
  }) =>
      _candidates.findDuplicateFacts(maxEntities: maxEntities);

  /// Verify duplicate fact candidates via LLM.
  ///
  /// Two-phase approach:
  /// 1. Send entity fact bundles to LLM for cross-key semantic detection
  ///    (catches vélo/bicyclette that string similarity cannot detect).
  /// 2. Verify deterministic candidates (same-key duplicates).
  Future<List<ScoredFactPair>> verifyFactsWithLLM(
    List<DuplicateFactCandidate> candidates, {
    List<EntityFactBundle> factBundles = const [],
  }) =>
      _verifier.verifyFactsWithLLM(candidates, factBundles: factBundles);

  /// Remove a duplicate fact by soft-deleting it (set expired_at).
  Future<void> expireFact(int factId) => _cleanup.expireFact(factId);

  // ─── Cleanup: LLM-based full KB analysis ──────────────────────────

  /// Build compact markdown snapshots of the KB for LLM analysis, chunked
  /// by entity id range so each cleanup prompt stays within context bounds
  /// at several-thousand-entity scale (U15). See
  /// [KbCleanupService.buildKBSnapshotChunks].
  Future<List<String>> buildKBSnapshotChunks({int? maxChunkChars}) =>
      _cleanup.buildKBSnapshotChunks(maxChunkChars: maxChunkChars);

  /// Send one KB snapshot chunk to LLM and get proposed cleanup operations.
  ///
  /// Callers iterate the chunks from [buildKBSnapshotChunks] (one LLM call
  /// per chunk) and aggregate the returned operations.
  Future<List<CleanupOperation>> proposeCleanup(String snapshot) =>
      _cleanup.proposeCleanup(snapshot);

  /// Parse LLM cleanup response JSON into operation objects.
  ///
  /// Static for testability. Reads `confidence` (or fallback `score`) from
  /// each operation, clamped to 0-100. Missing confidence defaults to null.
  static List<CleanupOperation> parseCleanupResponse(String content) =>
      KbCleanupService.parseCleanupResponse(content);

  /// Execute cleanup operations with validation and PERSON protection.
  ///
  /// Execution order: merges → delete_relations → deletes.
  Future<CleanupResult> executeCleanupOps(List<CleanupOperation> ops) =>
      _cleanup.executeCleanupOps(ops);

  /// Load entity names for a set of cleanup operations (for display).
  Future<Map<int, String>> loadEntityNames(List<CleanupOperation> ops) =>
      _cleanup.loadEntityNames(ops);

  /// Load relation descriptions (source → target) for display.
  Future<Map<int, String>> loadRelationDescs(List<int> relationIds) =>
      _cleanup.loadRelationDescs(relationIds);

  // ─── Static helpers kept for the dedup test suite ──────────────────

  /// Build a markdown table from candidate pairs for LLM verification.
  ///
  /// Exposed as static for testing. More compact than JSON, fewer tokens.
  static String buildVerificationTable(List<DuplicateCandidate> batch) =>
      DedupLlmVerifier.buildVerificationTable(batch);

  /// Parse LLM JSON response into scored pairs.
  ///
  /// Exposed as static for testing. Handles markdown fences, missing pairs,
  /// and invalid IDs gracefully.
  static List<ScoredPair> parseLlmResponse(
    String content,
    List<DuplicateCandidate> batch,
    Set<int> validIds,
  ) =>
      DedupLlmVerifier.parseLlmResponse(content, batch, validIds);
}
