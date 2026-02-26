import 'dart:math';

/// Spreading activation over a knowledge graph.
///
/// Starting from seed entities with initial activation values,
/// propagates activation along edges with a decay factor.
/// Useful for finding contextually related entities beyond
/// direct keyword matches.
class SpreadingActivation {
  /// Decay factor per hop (0.0–1.0). Higher = slower decay.
  final double decayFactor;

  /// Minimum activation to continue propagation.
  final double firingThreshold;

  /// Maximum BFS iterations (hops from seeds).
  final int maxIterations;

  const SpreadingActivation({
    this.decayFactor = 0.85,
    this.firingThreshold = 0.01,
    this.maxIterations = 4,
  });

  /// Run spreading activation.
  ///
  /// [seeds]: initial entity ID → activation value.
  /// [neighborFn]: given an entity ID, returns its neighbors
  ///   as (entityId, edgeWeight) pairs.
  ///
  /// Returns a map of entity ID → final activation value.
  Map<int, double> activate({
    required Map<int, double> seeds,
    required List<({int entityId, double weight})> Function(int entityId)
        neighborFn,
  }) {
    final activations = Map<int, double>.from(seeds);
    var frontier = Map<int, double>.from(seeds);

    for (var i = 0; i < maxIterations; i++) {
      final nextFrontier = <int, double>{};

      for (final entry in frontier.entries) {
        final entityId = entry.key;
        final currentActivation = entry.value;

        if (currentActivation < firingThreshold) continue;

        final neighbors = neighborFn(entityId);
        for (final n in neighbors) {
          final spread = currentActivation * decayFactor * n.weight;
          if (spread < firingThreshold) continue;

          final existing = activations[n.entityId] ?? 0.0;
          final updated = max(existing, spread);

          if (updated > existing) {
            activations[n.entityId] = updated;
            nextFrontier[n.entityId] =
                max(nextFrontier[n.entityId] ?? 0.0, spread);
          }
        }
      }

      if (nextFrontier.isEmpty) break;
      frontier = nextFrontier;
    }

    return activations;
  }
}
