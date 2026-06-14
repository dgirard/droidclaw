import '../../config/log_entry.dart';
import '../../providers/embedding_provider.dart';
import '../../services/app_logger.dart';
import '../../../shared/constants.dart';
import '../algorithms/embedding_codec.dart';
import '../database/knowledge_graph_db.dart';
import 'ingestion_pipeline.dart';

/// Progress of a versioned re-embed backfill toward one target space.
class BackfillProgress {
  /// Active embedded entities still outside the target space.
  final int remaining;

  /// Active entities with any embedding (the backfill universe).
  final int total;

  const BackfillProgress({required this.remaining, required this.total});

  /// Entities already in the target space.
  int get done => total - remaining;

  /// True when every embedded entity lives in the target space — the
  /// cutover criterion: queries must not flip to the target space before
  /// this holds (enforced independently by the query guard in
  /// KnowledgeService.resolveQuerySpace).
  bool get isComplete => remaining == 0;

  @override
  String toString() => 'BackfillProgress($done/$total, remaining=$remaining)';
}

/// Generic versioned re-embed job (U3): "re-embed every active entity whose
/// vector is not in the target space" — reusable for any future embedding
/// model change (cloud→local cutover, model revision bumps, dimension
/// changes).
///
/// Properties by construction:
/// - **Resumable**: candidates are selected with
///   `WHERE embedding IS NOT NULL AND (model != target OR dim != target)`;
///   a re-embedded row stops matching, so a killed run loses at most the
///   in-flight batch and never re-processes finished rows.
/// - **Side-by-side per row**: the new vector replaces the old one together
///   with its provenance columns in a single UPDATE — a row is always in
///   exactly one space, never in a torn state.
/// - **No space mixing**: this job only writes; the query guard keeps
///   serving queries from the dominant complete space until coverage flips.
/// - **Text fidelity**: the embedded text is rebuilt with
///   [IngestionPipeline.buildEmbeddingText], the exact builder ingestion
///   uses, so backfilled vectors cannot drift in shape from ingested ones.
class EmbeddingBackfillService {
  final KnowledgeGraphDB db;

  /// The provider that defines and produces the TARGET space.
  final EmbeddingProvider provider;

  /// Model name passed to the provider's embed() calls.
  final String embeddingModel;

  final int batchSize;

  bool _cancelRequested = false;
  bool _running = false;

  /// Whether a slice/run is currently executing.
  bool get isRunning => _running;

  EmbeddingBackfillService({
    required this.db,
    required this.provider,
    required this.embeddingModel,
    this.batchSize = AppConstants.knowledgeBackfillBatchSize,
  });

  /// Target space identity: (providerId, outputDimensions).
  ({String model, int dim}) get targetSpace =>
      (model: provider.providerId, dim: provider.outputDimensions);

  /// Current progress toward the target space (one COUNT query each).
  Future<BackfillProgress> progress() async {
    final target = targetSpace;
    final remaining = await db.countEntitiesNeedingReembed(
      targetModel: target.model,
      targetDim: target.dim,
    );
    final spaces = await db.getEmbeddingSpaceCounts();
    final total = spaces.fold<int>(0, (a, s) => a + s.count);
    return BackfillProgress(remaining: remaining, total: total);
  }

  /// Request cancellation: the current batch finishes, no further batch
  /// starts. The job stays resumable — call [runSlice] again to continue.
  void cancel() => _cancelRequested = true;

  /// Run up to [maxBatches] batches and return the progress afterwards.
  ///
  /// One slice is the unit of scheduled work (charger+idle window in the
  /// service isolate) and of UI progress reporting. Embed failures abort the
  /// slice (logged, rethrown) — already-written rows stay done. A previous
  /// cancellation is cleared: each call starts fresh.
  Future<BackfillProgress> runSlice({
    int maxBatches = AppConstants.knowledgeBackfillSliceMaxBatches,
  }) async {
    _cancelRequested = false;
    return _runSliceInner(maxBatches: maxBatches);
  }

  Future<BackfillProgress> _runSliceInner({required int maxBatches}) async {
    if (_running) return progress();
    _running = true;
    final target = targetSpace;

    try {
      for (var batch = 0; batch < maxBatches; batch++) {
        if (_cancelRequested) break;

        final rows = await db.getEntitiesNeedingReembed(
          targetModel: target.model,
          targetDim: target.dim,
          batchSize: batchSize,
        );
        if (rows.isEmpty) break;

        final texts = [
          for (final r in rows)
            IngestionPipeline.buildEmbeddingText(
              name: r.name,
              entityType: r.entityType,
              summary: r.summary,
            ),
        ];

        final result = await provider.embed(
          texts: texts,
          model: embeddingModel,
          dimensions: target.dim,
          taskType: 'RETRIEVAL_DOCUMENT',
        );

        for (var i = 0; i < rows.length; i++) {
          if (i >= result.embeddings.length) break;
          final vector = result.embeddings[i];
          await db.updateEntityEmbedding(
            rows[i].id,
            EmbeddingCodec.encode(vector),
            model: target.model,
            dim: vector.length,
          );
        }
      }

      final p = await progress();
      AppLogger.instance.info(
        LogSource.agent,
        'KG embedding backfill slice toward ${target.model}/${target.dim}d: '
        '${p.done}/${p.total} done'
        '${p.isComplete ? ' — COMPLETE' : ''}'
        '${_cancelRequested ? ' (cancelled)' : ''}',
      );
      return p;
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.agent,
        'KG embedding backfill slice failed (resumable, no rows lost): $e',
      );
      rethrow;
    } finally {
      _running = false;
    }
  }

  /// Run slices until complete or cancelled. Returns final progress.
  /// A previous cancellation is cleared: each call starts fresh.
  Future<BackfillProgress> runToCompletion({
    void Function(BackfillProgress progress)? onProgress,
  }) async {
    _cancelRequested = false;
    var p = await progress();
    while (!p.isComplete && !_cancelRequested) {
      p = await _runSliceInner(maxBatches: 1);
      onProgress?.call(p);
    }
    return p;
  }
}
