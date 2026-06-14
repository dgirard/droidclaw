import 'package:droidclaw/core/providers/embedding_provider.dart';

/// Deterministic embedder: fixed vector per known input string, zero vector
/// otherwise (cosine similarity with the zero vector is 0 → never a match).
///
/// [providerId] and [dimensions] are configurable so U3 tests can model two
/// distinct embedding spaces (e.g. 'space-a'/4d vs 'space-b'/3d) with
/// separate fakes.
class FakeEmbeddingProvider implements EmbeddingProvider {
  final Map<String, List<double>> vectors;

  /// When true, every [embed] call throws — simulates a query-time embedding
  /// failure (API down, bad key) for the degraded-retrieval path.
  final bool throwOnEmbed;

  final String _providerId;
  final int _dimensions;

  /// Number of [embed] calls, for asserting the vector path ran (or not).
  int embedCallCount = 0;

  /// Every text ever passed to [embed], for asserting backfill batches
  /// process each entity exactly once (kill-resume tests).
  final List<String> embeddedTexts = [];

  FakeEmbeddingProvider(
    this.vectors, {
    this.throwOnEmbed = false,
    String providerId = 'fake',
    int dimensions = 4,
  })  : _providerId = providerId,
        _dimensions = dimensions;

  @override
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model,
    int? dimensions,
    String? taskType,
  }) async {
    embedCallCount++;
    if (throwOnEmbed) {
      throw StateError('embed failed (fake)');
    }
    embeddedTexts.addAll(texts);
    return EmbeddingResult(embeddings: [
      for (final t in texts)
        vectors[t] ?? List<double>.filled(_dimensions, 0.0),
    ]);
  }

  @override
  String get providerName => _providerId;

  @override
  String get providerId => _providerId;

  @override
  int get outputDimensions => _dimensions;

  @override
  Future<void> dispose() async {}
}
