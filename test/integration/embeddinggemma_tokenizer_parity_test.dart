@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tokenizer parity: the pure-Dart SentencePiece tokenizer must produce the
/// exact token ids of the Python `AutoTokenizer` for EmbeddingGemma —
/// otherwise local embeddings live in a silently different space.
///
/// Tagged `integration` (excluded from the default gate) because it needs:
/// 1. The real `tokenizer.json` (20 MB, not committed). Point to it via the
///    `EMBEDDINGGEMMA_TOKENIZER_JSON` env var, or download the model in the
///    app and pull it from the device.
/// 2. Generated fixture ids (see `_comment` in the fixtures file for the
///    one-line Python generator).
///
/// Run with:
///   EMBEDDINGGEMMA_TOKENIZER_JSON=/path/to/tokenizer.json \
///     flutter test --tags integration test/integration/embeddinggemma_tokenizer_parity_test.dart
void main() {
  const fixturesPath = 'test/fixtures/embeddinggemma_tokenizer_fixtures.json';

  test('pure-Dart tokenizer matches AutoTokenizer ids on fr/en/accents/emoji',
      () async {
    final fixtures = jsonDecode(File(fixturesPath).readAsStringSync())
        as Map<String, dynamic>;
    final cases = (fixtures['cases'] as List).cast<Map<String, dynamic>>();

    final hasIds =
        cases.every((c) => (c['ids'] as List).isNotEmpty);
    if (!hasIds) {
      markTestSkipped(
          'Fixture ids are placeholders — generate them with the Python '
          'one-liner in $fixturesPath (_comment) and re-run.');
      return;
    }

    final tokenizerPath =
        Platform.environment['EMBEDDINGGEMMA_TOKENIZER_JSON'];
    if (tokenizerPath == null || !File(tokenizerPath).existsSync()) {
      markTestSkipped(
          'Set EMBEDDINGGEMMA_TOKENIZER_JSON to the real tokenizer.json '
          '(downloaded by the app, or from the HF repo) and re-run.');
      return;
    }

    final tokenizer =
        await HuggingFaceTokenizerLoader.fromJsonFile(tokenizerPath);

    for (final c in cases) {
      final text = c['text'] as String;
      final expected = (c['ids'] as List).cast<int>();
      final actual = tokenizer.encode(text).ids.toList();
      expect(actual, expected, reason: 'token-id divergence for: "$text"');
    }
  });
}
