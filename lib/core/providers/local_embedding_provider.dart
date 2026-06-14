import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path/path.dart' as p;

import '../../shared/constants.dart';
import '../config/log_entry.dart';
import '../services/app_logger.dart';
import 'embedding_provider.dart';

/// Thrown when the local embedding model is not available on disk.
/// State-aware: the message tells the user where to fix it.
class LocalModelUnavailableException implements Exception {
  final String message;
  const LocalModelUnavailableException(this.message);

  @override
  String toString() => 'LocalModelUnavailableException: $message';
}

/// Minimal seam over an ONNX inference session so unit tests can inject a
/// fake returning known vectors (the real flutter_onnxruntime session needs
/// a platform channel and the 309 MB model).
abstract class EmbeddingSession {
  /// Run the encoder on one tokenized input (batch of 1). Returns the raw
  /// full-dimension (un-truncated, un-normalized) sentence vector.
  Future<List<double>> run(List<int> inputIds);

  Future<void> close();
}

/// Loaded tokenizer + session pair.
class LocalEmbeddingRuntime {
  /// Text → token ids (special tokens included, as `AutoTokenizer` does).
  final List<int> Function(String text) tokenize;
  final EmbeddingSession session;

  const LocalEmbeddingRuntime({required this.tokenize, required this.session});
}

/// Loads a [LocalEmbeddingRuntime] from model + tokenizer file paths.
/// Test seam: the default loads ONNX Runtime and the SentencePiece tokenizer.
typedef RuntimeLoader = Future<LocalEmbeddingRuntime> Function(
    String modelPath, String tokenizerPath);

/// On-device embedding provider: EmbeddingGemma 308M (int8 ONNX export)
/// behind the standard [EmbeddingProvider] seam.
///
/// - Lazy, single-flight session init from the downloaded model directory
///   (`createSession` with the external-weights `.onnx_data` sibling resolved
///   by filename in the same directory).
/// - EmbeddingGemma prompt prefixes applied by task type (query vs document).
/// - Output → MRL truncation to [outputDimensions] → L2 renormalization.
class LocalEmbeddingProvider implements EmbeddingProvider {
  /// Directory holding model_quantized.onnx, model_quantized.onnx_data and
  /// tokenizer.json (a `ready` [ModelDownloadManager] model dir).
  final String modelDir;

  final int _dimensions;
  final RuntimeLoader _runtimeLoader;

  Future<LocalEmbeddingRuntime>? _runtimeFuture;
  bool _disposed = false;

  LocalEmbeddingProvider({
    required this.modelDir,
    int dimensions = AppConstants.localEmbeddingDimensions,
    RuntimeLoader? runtimeLoader,
  })  : _dimensions = dimensions,
        _runtimeLoader = runtimeLoader ?? _defaultRuntimeLoader;

  @override
  String get providerName => 'local';

  @override
  String get providerId => AppConstants.localEmbeddingProviderId;

  @override
  int get outputDimensions => _dimensions;

  @override
  Future<EmbeddingResult> embed({
    required List<String> texts,
    required String model, // ignored — the local model is fixed by [modelDir]
    int? dimensions,
    String? taskType,
  }) async {
    final runtime = await _runtime();
    final dims = dimensions ?? _dimensions;
    final embeddings = <List<double>>[];
    for (final text in texts) {
      final ids = runtime.tokenize(applyPromptPrefix(text, taskType));
      final bounded = ids.length > AppConstants.localEmbeddingMaxTokens
          ? ids.sublist(0, AppConstants.localEmbeddingMaxTokens)
          : ids;
      final raw = await runtime.session.run(bounded);
      embeddings.add(truncateAndNormalize(raw, dims));
    }
    return EmbeddingResult(embeddings: embeddings);
  }

  /// EmbeddingGemma requires task-specific prompt prefixes (HF model card).
  /// Gemini-style task types map onto them; anything else embeds as document.
  static String applyPromptPrefix(String text, String? taskType) {
    final prefix = taskType == 'RETRIEVAL_QUERY'
        ? AppConstants.localEmbeddingQueryPrefix
        : AppConstants.localEmbeddingDocumentPrefix;
    return '$prefix$text';
  }

  /// Matryoshka (MRL) truncation to [dims] followed by L2 renormalization.
  static List<double> truncateAndNormalize(List<double> raw, int dims) {
    final n = min(dims, raw.length);
    final truncated = raw.sublist(0, n);
    var sumSquares = 0.0;
    for (final v in truncated) {
      sumSquares += v * v;
    }
    if (sumSquares == 0) return truncated;
    final norm = sqrt(sumSquares);
    return [for (final v in truncated) v / norm];
  }

  /// Single-flight lazy init; a failed init is cleared so the next call can
  /// retry (e.g. after the model finishes downloading).
  Future<LocalEmbeddingRuntime> _runtime() {
    return _runtimeFuture ??= _load().then(
      (runtime) => runtime,
      onError: (Object e, StackTrace st) {
        _runtimeFuture = null;
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  Future<LocalEmbeddingRuntime> _load() async {
    final modelPath =
        p.join(modelDir, AppConstants.embeddingGemmaModelFilename);
    final dataPath =
        p.join(modelDir, AppConstants.embeddingGemmaModelDataFilename);
    final tokenizerPath =
        p.join(modelDir, AppConstants.embeddingGemmaTokenizerFilename);

    for (final path in [modelPath, dataPath, tokenizerPath]) {
      if (!File(path).existsSync()) {
        throw LocalModelUnavailableException(
            'Local embedding model is not downloaded (missing '
            '${p.basename(path)}). Download it in Settings → Embeddings → '
            'Local (on-device).');
      }
    }

    AppLogger.instance.info(
        LogSource.app, 'Loading local embedding model from $modelDir');
    final runtime = await _runtimeLoader(modelPath, tokenizerPath);
    AppLogger.instance.info(LogSource.app, 'Local embedding model ready');
    return runtime;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final future = _runtimeFuture;
    _runtimeFuture = null;
    if (future != null) {
      try {
        final runtime = await future;
        await runtime.session.close();
      } catch (_) {
        // Init failed — nothing to release.
      }
    }
  }
}

/// Production loader: SentencePiece tokenizer (pure Dart, HF tokenizer.json)
/// + flutter_onnxruntime session created from the model file path so the
/// external-weights sibling is auto-resolved.
Future<LocalEmbeddingRuntime> _defaultRuntimeLoader(
    String modelPath, String tokenizerPath) async {
  final tokenizer = await HuggingFaceTokenizerLoader.fromJsonFile(
    tokenizerPath,
  );
  final session = await OnnxRuntime().createSession(modelPath);
  return LocalEmbeddingRuntime(
    tokenize: (text) => tokenizer.encode(text).ids.toList(),
    session: _OnnxEmbeddingSession(session),
  );
}

class _OnnxEmbeddingSession implements EmbeddingSession {
  final OrtSession _session;

  _OnnxEmbeddingSession(this._session);

  @override
  Future<List<double>> run(List<int> inputIds) async {
    final len = inputIds.length;
    final inputs = <String, OrtValue>{};
    try {
      for (final name in _session.inputNames) {
        inputs[name] = switch (name) {
          'input_ids' =>
            await OrtValue.fromList(Int64List.fromList(inputIds), [1, len]),
          'attention_mask' => await OrtValue.fromList(
              Int64List.fromList(List.filled(len, 1)), [1, len]),
          'position_ids' => await OrtValue.fromList(
              Int64List.fromList([for (var i = 0; i < len; i++) i]), [1, len]),
          'token_type_ids' => await OrtValue.fromList(
              Int64List.fromList(List.filled(len, 0)), [1, len]),
          _ => throw StateError(
              'Unsupported model input "$name" — not an EmbeddingGemma '
              'encoder export?'),
        };
      }

      final outputs = await _session.run(inputs);
      try {
        // The onnx-community export pools inside the graph and exposes
        // `sentence_embedding` [1, 768]. Fall back to mean pooling over
        // `last_hidden_state` [1, len, 768] for other exports.
        final pooled = outputs['sentence_embedding'];
        if (pooled != null) {
          return _toDoubles(await pooled.asFlattenedList());
        }
        final hidden = outputs['last_hidden_state'] ?? outputs.values.first;
        final flat = _toDoubles(await hidden.asFlattenedList());
        final hiddenDim = flat.length ~/ len;
        final mean = List<double>.filled(hiddenDim, 0);
        for (var t = 0; t < len; t++) {
          for (var d = 0; d < hiddenDim; d++) {
            mean[d] += flat[t * hiddenDim + d];
          }
        }
        for (var d = 0; d < hiddenDim; d++) {
          mean[d] /= len;
        }
        return mean;
      } finally {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    } finally {
      for (final value in inputs.values) {
        await value.dispose();
      }
    }
  }

  static List<double> _toDoubles(List<dynamic> values) =>
      [for (final v in values) (v as num).toDouble()];

  @override
  Future<void> close() => _session.close();
}
