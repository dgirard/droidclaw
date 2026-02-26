import 'dart:math';

/// Multi-signal score fusion for knowledge graph queries.
///
/// Combines three signals:
///   - BM25 (FTS5 text search rank)
///   - Spreading activation (graph traversal)
///   - Memory decay (Ebbinghaus retention)
///
/// Weights: 0.55 BM25 + 0.30 activation + 0.15 decay
class HybridScorer {
  static const double _wBm25 = 0.55;
  static const double _wActivation = 0.30;
  static const double _wDecay = 0.15;

  /// Fuse scores for a set of candidate entities.
  ///
  /// [candidates]: entity IDs to score.
  /// [bm25Scores]: entity ID → raw BM25 rank (lower = better in FTS5).
  /// [activationScores]: entity ID → spreading activation value.
  /// [decayScores]: entity ID → retention score (0–1).
  ///
  /// Returns scored entities sorted descending by fused score.
  static List<ScoredEntity> fuse({
    required Set<int> candidates,
    required Map<int, double> bm25Scores,
    required Map<int, double> activationScores,
    required Map<int, double> decayScores,
  }) {
    // Normalize BM25 scores (invert: BM25 returns negative, more negative = better)
    final normBm25 = _normalizeInverted(bm25Scores, candidates);
    final normActivation = _normalize(activationScores, candidates);
    final normDecay = _normalize(decayScores, candidates);

    final results = <ScoredEntity>[];
    for (final id in candidates) {
      final bm25 = normBm25[id] ?? 0.0;
      final activation = normActivation[id] ?? 0.0;
      final decay = normDecay[id] ?? 0.0;

      final score = _wBm25 * bm25 +
          _wActivation * activation +
          _wDecay * decay;

      results.add(ScoredEntity(
        entityId: id,
        score: score,
        bm25Score: bm25,
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
  final double activationScore;
  final double decayScore;

  const ScoredEntity({
    required this.entityId,
    required this.score,
    this.bm25Score = 0.0,
    this.activationScore = 0.0,
    this.decayScore = 0.0,
  });
}
