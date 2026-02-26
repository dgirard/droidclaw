import 'dart:math';

import '../models/entity.dart';

/// Ebbinghaus-inspired memory decay model.
///
/// Retention R = e^(-t/S) where:
///   t = seconds since last access
///   S = stability = baseStability * (1 + 1.5 * ln(accessCount + 1))
///
/// Temperature classification based on retention score:
///   Hot  >= 0.7
///   Warm >= 0.4
///   Cool >= 0.1
///   Cold <  0.1
class MemoryDecay {
  /// Base stability in seconds (1 day).
  static const double baseStability = 86400.0;

  /// Temperature thresholds.
  static const double hotThreshold = 0.7;
  static const double warmThreshold = 0.4;
  static const double coolThreshold = 0.1;

  /// Calculate the stability factor for an entity.
  static double stability(int accessCount) {
    return baseStability * (1 + 1.5 * log(accessCount + 1));
  }

  /// Calculate the retention score (0.0 to 1.0).
  static double retention({
    required int lastAccessedEpoch,
    required int accessCount,
    int? nowEpoch,
  }) {
    final now = nowEpoch ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final t = (now - lastAccessedEpoch).toDouble();
    if (t <= 0) return 1.0;
    final s = stability(accessCount);
    return exp(-t / s);
  }

  /// Classify retention score into temperature.
  static Temperature classify(double retentionScore) {
    if (retentionScore >= hotThreshold) return Temperature.hot;
    if (retentionScore >= warmThreshold) return Temperature.warm;
    if (retentionScore >= coolThreshold) return Temperature.cool;
    return Temperature.cold;
  }

  /// Compute decay score and new temperature for a single entity.
  static ({double score, Temperature temperature}) compute({
    required int lastAccessedEpoch,
    required int accessCount,
    int? nowEpoch,
  }) {
    final r = retention(
      lastAccessedEpoch: lastAccessedEpoch,
      accessCount: accessCount,
      nowEpoch: nowEpoch,
    );
    return (score: r, temperature: classify(r));
  }

  /// Batch compute temperature updates for all active entities.
  /// Returns only entities whose temperature has changed.
  static List<({int id, String temp, double score})> batchDecay(
    List<({int id, int lastAccessed, int accessCount, String temperature})>
        entities, {
    int? nowEpoch,
  }) {
    final now = nowEpoch ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final updates = <({int id, String temp, double score})>[];

    for (final e in entities) {
      final result = compute(
        lastAccessedEpoch: e.lastAccessed,
        accessCount: e.accessCount,
        nowEpoch: now,
      );
      final newTemp = result.temperature.name;
      if (newTemp != e.temperature) {
        updates.add((id: e.id, temp: newTemp, score: result.score));
      }
    }

    return updates;
  }
}
