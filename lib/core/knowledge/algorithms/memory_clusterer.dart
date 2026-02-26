import 'dart:math';
import 'dart:typed_data';

/// DBSCAN clustering on cosine distance of embeddings.
///
/// Used for RAPTOR-style hierarchical summarization:
/// clusters warm/cool entities into groups that can be
/// summarized into summary_nodes.
class MemoryClusterer {
  /// Maximum distance for two points to be neighbors.
  final double epsilon;

  /// Minimum points to form a cluster.
  final int minPoints;

  const MemoryClusterer({
    this.epsilon = 0.3,
    this.minPoints = 3,
  });

  /// Run DBSCAN clustering.
  ///
  /// [items]: list of (id, embedding) pairs.
  /// Returns a map of cluster label → list of entity IDs.
  /// Noise points (unclustered) are not included.
  Map<int, List<int>> cluster(List<({int id, Float32List embedding})> items) {
    if (items.length < minPoints) return {};

    final n = items.length;
    final labels = List<int>.filled(n, -1); // -1 = unvisited
    const noise = -2;
    var clusterLabel = 0;

    for (var i = 0; i < n; i++) {
      if (labels[i] != -1) continue;

      final neighbors = _rangeQuery(items, i);
      if (neighbors.length < minPoints) {
        labels[i] = noise;
        continue;
      }

      labels[i] = clusterLabel;
      final seeds = List<int>.from(neighbors);
      seeds.remove(i);

      var j = 0;
      while (j < seeds.length) {
        final q = seeds[j];
        if (labels[q] == noise) {
          labels[q] = clusterLabel;
        }
        if (labels[q] != -1) {
          j++;
          continue;
        }

        labels[q] = clusterLabel;
        final qNeighbors = _rangeQuery(items, q);
        if (qNeighbors.length >= minPoints) {
          for (final nn in qNeighbors) {
            if (!seeds.contains(nn)) seeds.add(nn);
          }
        }
        j++;
      }

      clusterLabel++;
    }

    // Group by cluster label, excluding noise
    final clusters = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      if (labels[i] >= 0) {
        clusters.putIfAbsent(labels[i], () => []).add(items[i].id);
      }
    }
    return clusters;
  }

  /// Find all indices within epsilon distance of items[index].
  List<int> _rangeQuery(
    List<({int id, Float32List embedding})> items,
    int index,
  ) {
    final neighbors = <int>[];
    final a = items[index].embedding;
    for (var i = 0; i < items.length; i++) {
      if (cosineDistance(a, items[i].embedding) <= epsilon) {
        neighbors.add(i);
      }
    }
    return neighbors;
  }

  /// Cosine distance = 1 - cosine_similarity.
  static double cosineDistance(Float32List a, Float32List b) {
    return 1.0 - cosineSimilarity(a, b);
  }

  /// Cosine similarity between two vectors.
  static double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0.0;
    return dot / denom;
  }
}
