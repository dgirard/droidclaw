import 'dart:math';

/// Multi-signal score fusion for knowledge graph queries.
///
/// Combines four signals:
///   - BM25 (FTS5 text search rank)
///   - Vector similarity (cosine, from embeddings)
///   - Spreading activation (graph traversal)
///   - Memory decay (Ebbinghaus retention)
///
/// Full mode weights: 0.30 BM25 + 0.30 vector + 0.25 activation + 0.15 decay
/// Degraded mode (no embeddings): 0.55 BM25 + 0.30 activation + 0.15 decay
///
/// Embedding-space note (U3): all four signals are min-max normalized over
/// the candidate set before fusion, so the weights themselves are agnostic
/// to the cosine distribution of the embedding space in use. What IS
/// distribution-sensitive is the candidate-pool admission threshold
/// upstream ([AppConstants.knowledgeVectorSimilarityThreshold]) — see the
/// recalibration note there for the 256-dim local space.
class HybridScorer {
  // Full mode weights (with vector similarity)
  static const double _wBm25Full = 0.30;
  static const double _wVectorFull = 0.30;
  static const double _wActivationFull = 0.25;
  static const double _wDecayFull = 0.15;

  // Degraded mode weights (no vector similarity)
  static const double _wBm25Degraded = 0.55;
  static const double _wActivationDegraded = 0.30;
  static const double _wDecayDegraded = 0.15;

  /// Fuse scores for a set of candidate entities.
  ///
  /// [candidates]: entity IDs to score.
  /// [bm25Scores]: entity ID → raw BM25 rank (lower = better in FTS5).
  /// [vectorScores]: entity ID → cosine similarity (0–1). Null if no embedder.
  /// [activationScores]: entity ID → spreading activation value.
  /// [decayScores]: entity ID → retention score (0–1).
  ///
  /// Returns scored entities sorted descending by fused score.
  static List<ScoredEntity> fuse({
    required Set<int> candidates,
    required Map<int, double> bm25Scores,
    Map<int, double>? vectorScores,
    required Map<int, double> activationScores,
    required Map<int, double> decayScores,
  }) {
    final hasVector = vectorScores != null && vectorScores.isNotEmpty;

    // Normalize BM25 scores (invert: BM25 returns negative, more negative = better)
    final normBm25 = _normalizeInverted(bm25Scores, candidates);
    final normVector =
        hasVector ? _normalize(vectorScores, candidates) : <int, double>{};
    final normActivation = _normalize(activationScores, candidates);
    final normDecay = _normalize(decayScores, candidates);

    final results = <ScoredEntity>[];
    for (final id in candidates) {
      final bm25 = normBm25[id] ?? 0.0;
      final vector = normVector[id] ?? 0.0;
      final activation = normActivation[id] ?? 0.0;
      final decay = normDecay[id] ?? 0.0;

      final double score;
      if (hasVector) {
        score = _wBm25Full * bm25 +
            _wVectorFull * vector +
            _wActivationFull * activation +
            _wDecayFull * decay;
      } else {
        score = _wBm25Degraded * bm25 +
            _wActivationDegraded * activation +
            _wDecayDegraded * decay;
      }

      results.add(ScoredEntity(
        entityId: id,
        score: score,
        bm25Score: bm25,
        vectorScore: vector,
        activationScore: activation,
        decayScore: decay,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Min-max normalize values to 0–1. Higher input = higher output.
  static Map<int, double> _normalize(
      Map<int, double> raw, Set<int> candidates) {
    if (raw.isEmpty) return {};
    var minVal = double.infinity;
    var maxVal = double.negativeInfinity;
    for (final id in candidates) {
      final v = raw[id];
      if (v == null) continue;
      minVal = min(minVal, v);
      maxVal = max(maxVal, v);
    }
    final range = maxVal - minVal;
    if (range == 0) {
      return {for (final id in candidates) if (raw.containsKey(id)) id: 1.0};
    }
    return {
      for (final id in candidates)
        if (raw.containsKey(id)) id: (raw[id]! - minVal) / range,
    };
  }

  /// Normalize inverted BM25 scores (more negative = better → higher output).
  static Map<int, double> _normalizeInverted(
      Map<int, double> raw, Set<int> candidates) {
    if (raw.isEmpty) return {};
    var minVal = double.infinity;
    var maxVal = double.negativeInfinity;
    for (final id in candidates) {
      final v = raw[id];
      if (v == null) continue;
      minVal = min(minVal, v);
      maxVal = max(maxVal, v);
    }
    final range = maxVal - minVal;
    if (range == 0) {
      return {for (final id in candidates) if (raw.containsKey(id)) id: 1.0};
    }
    // Invert: most negative (best rank) gets highest score
    return {
      for (final id in candidates)
        if (raw.containsKey(id)) id: (maxVal - raw[id]!) / range,
    };
  }
}

/// A scored entity from the hybrid query pipeline.
class ScoredEntity {
  final int entityId;
  final double score;
  final double bm25Score;
  final double vectorScore;
  final double activationScore;
  final double decayScore;

  const ScoredEntity({
    required this.entityId,
    required this.score,
    this.bm25Score = 0.0,
    this.vectorScore = 0.0,
    this.activationScore = 0.0,
    this.decayScore = 0.0,
  });
}
