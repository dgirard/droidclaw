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

  KbMaintenanceService({
    required KnowledgeGraphDB db,
    required KnowledgeService knowledgeService,
    required LLMProvider llmProvider,
    required String model,
    // The language for LLM cleanup prompts (e.g. 'en', 'fr'). Null = English.
    String? kbLanguage,
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

  /// Find duplicate candidates — see [CandidateGenerator.findCandidates].
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

  /// Verify candidates via LLM — see [DedupLlmVerifier.verifyWithLLM].
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

  /// Find same-entity duplicate facts — see
  /// [CandidateGenerator.findDuplicateFacts].
  Future<({List<DuplicateFactCandidate> candidates, List<EntityFactBundle> bundles})> findDuplicateFacts({
    int maxEntities = AppConstants.dedupFactScanMaxEntities,
  }) =>
      _candidates.findDuplicateFacts(maxEntities: maxEntities);

  /// Verify duplicate fact candidates via LLM — see
  /// [DedupLlmVerifier.verifyFactsWithLLM].
  Future<List<ScoredFactPair>> verifyFactsWithLLM(
    List<DuplicateFactCandidate> candidates, {
    List<EntityFactBundle> factBundles = const [],
  }) =>
      _verifier.verifyFactsWithLLM(candidates, factBundles: factBundles);

  /// Remove a duplicate fact by soft-deleting it (set expired_at).
  Future<void> expireFact(int factId) => _cleanup.expireFact(factId);

  // ─── Cleanup: LLM-based full KB analysis ──────────────────────────

  /// Build chunked KB snapshots for LLM analysis — see
  /// [KbCleanupService.buildKBSnapshotChunks].
  Future<List<String>> buildKBSnapshotChunks({int? maxChunkChars}) =>
      _cleanup.buildKBSnapshotChunks(maxChunkChars: maxChunkChars);

  /// Propose cleanup operations for one snapshot chunk — see
  /// [KbCleanupService.proposeCleanup].
  Future<List<CleanupOperation>> proposeCleanup(String snapshot) =>
      _cleanup.proposeCleanup(snapshot);

  /// Execute cleanup operations — see [KbCleanupService.executeCleanupOps].
  Future<CleanupResult> executeCleanupOps(List<CleanupOperation> ops) =>
      _cleanup.executeCleanupOps(ops);

  /// Load entity names for a set of cleanup operations (for display).
  Future<Map<int, String>> loadEntityNames(List<CleanupOperation> ops) =>
      _cleanup.loadEntityNames(ops);

  /// Load relation descriptions (source → target) for display.
  Future<Map<int, String>> loadRelationDescs(List<int> relationIds) =>
      _cleanup.loadRelationDescs(relationIds);
}
