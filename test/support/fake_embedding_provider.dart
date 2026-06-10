import 'package:droidclaw/core/providers/embedding_provider.dart';

/// Deterministic embedder: fixed vector per known input string, zero vector
/// otherwise (cosine similarity with the zero vector is 0 → never a match).
class FakeEmbeddingProvider implements EmbeddingProvider {
  final Map<String, List<double>> vectors;

  /// When true, every [embed] call throws — simulates a query-time embedding
  /// failure (API down, bad key) for the degraded-retrieval path.
  final bool throwOnEmbed;

  /// Number of [embed] calls, for asserting the vector path ran (or not).
  int embedCallCount = 0;

  FakeEmbeddingProvider(this.vectors, {this.throwOnEmbed = false});

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
    return EmbeddingResult(embeddings: [
      for (final t in texts) vectors[t] ?? const [0.0, 0.0, 0.0, 0.0],
    ]);
  }

  @override
  String get providerName => 'fake';

  @override
  String get providerId => 'fake';

  @override
  int get outputDimensions => 4;

  @override
  Future<void> dispose() async {}
}
