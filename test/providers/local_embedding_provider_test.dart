import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:droidclaw/core/providers/embedding_provider_factory.dart';
import 'package:droidclaw/core/providers/gemini_embedding_provider.dart';
import 'package:droidclaw/core/providers/local_embedding_provider.dart';
import 'package:droidclaw/shared/constants.dart';

/// Fake ONNX session seam: returns a fixed (or input-derived) raw vector
/// without touching flutter_onnxruntime or the 309 MB model.
class FakeEmbeddingSession implements EmbeddingSession {
  final List<double> Function(List<int> inputIds) vectorFor;
  final List<List<int>> receivedIds = [];
  bool closed = false;

  FakeEmbeddingSession(this.vectorFor);

  @override
  Future<List<double>> run(List<int> inputIds) async {
    receivedIds.add(List.of(inputIds));
    return vectorFor(inputIds);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  late Directory tempDir;

  /// Model dir with the three expected (dummy) files present, so the
  /// existence check passes and the injected fake runtime is reached.
  String modelDirWithFiles() {
    final dir = Directory(p.join(tempDir.path, 'model'))..createSync();
    for (final name in [
      AppConstants.embeddingGemmaModelFilename,
      AppConstants.embeddingGemmaModelDataFilename,
      AppConstants.embeddingGemmaTokenizerFilename,
    ]) {
      File(p.join(dir.path, name)).writeAsStringSync('dummy');
    }
    return dir.path;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('local_embed_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('model absent', () {
    test('embed throws a typed, state-aware error pointing to settings',
        () async {
      final provider = LocalEmbeddingProvider(
        modelDir: p.join(tempDir.path, 'nope'),
        runtimeLoader: (_, _) async => fail('loader must not be called'),
      );

      await expectLater(
        provider.embed(texts: ['hello'], model: ''),
        throwsA(isA<LocalModelUnavailableException>()
            .having((e) => e.message, 'message', contains('Settings'))
            .having((e) => e.message, 'message', contains('not downloaded'))),
      );
    });

    test('a partially present model dir is also unavailable', () async {
      final dir = Directory(p.join(tempDir.path, 'partial'))..createSync();
      File(p.join(dir.path, AppConstants.embeddingGemmaModelFilename))
          .writeAsStringSync('dummy');
      final provider = LocalEmbeddingProvider(
        modelDir: dir.path,
        runtimeLoader: (_, _) async => fail('loader must not be called'),
      );

      await expectLater(
        provider.embed(texts: ['hello'], model: ''),
        throwsA(isA<LocalModelUnavailableException>()),
      );
    });

    test('failed init is cleared so a later call can retry', () async {
      var calls = 0;
      final session = FakeEmbeddingSession((_) => [1.0, 0.0]);
      final dir = modelDirWithFiles();
      final provider = LocalEmbeddingProvider(
        modelDir: dir,
        dimensions: 2,
        runtimeLoader: (_, _) async {
          calls++;
          if (calls == 1) throw StateError('transient load failure');
          return LocalEmbeddingRuntime(
            tokenize: (t) => [1, 2, 3],
            session: session,
          );
        },
      );

      await expectLater(
          provider.embed(texts: ['a'], model: ''), throwsStateError);
      final result = await provider.embed(texts: ['a'], model: '');
      expect(result.embeddings.single, [1.0, 0.0]);
      expect(calls, 2);
    });
  });

  group('MRL truncation + L2 renormalization', () {
    test('truncates the raw vector then renormalizes (3-4-5 triangle)',
        () async {
      // Raw 8-dim vector whose first two components are (3, 4): after
      // truncation to 2 dims the norm is 5 → (0.6, 0.8).
      final session = FakeEmbeddingSession(
          (_) => [3.0, 4.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0]);
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        dimensions: 2,
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) => [1],
          session: session,
        ),
      );

      final result = await provider.embed(texts: ['x'], model: '');
      final v = result.embeddings.single;
      expect(v, hasLength(2));
      expect(v[0], closeTo(0.6, 1e-9));
      expect(v[1], closeTo(0.8, 1e-9));
    });

    test('result is unit-norm for arbitrary vectors', () async {
      final session = FakeEmbeddingSession(
          (_) => List.generate(768, (i) => sin(i + 1.0)));
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) => [1],
          session: session,
        ),
      );

      final v = (await provider.embed(texts: ['x'], model: ''))
          .embeddings
          .single;
      expect(v, hasLength(AppConstants.localEmbeddingDimensions));
      final norm = sqrt(v.fold<double>(0, (a, x) => a + x * x));
      expect(norm, closeTo(1.0, 1e-9));
    });

    test('per-call dimensions override wins over the configured default',
        () async {
      final session =
          FakeEmbeddingSession((_) => List.filled(768, 1.0));
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) => [1],
          session: session,
        ),
      );

      final v = (await provider.embed(texts: ['x'], model: '', dimensions: 64))
          .embeddings
          .single;
      expect(v, hasLength(64));
    });

    test('zero vector stays zero (no NaN from renormalization)', () {
      final v = LocalEmbeddingProvider.truncateAndNormalize(
          List.filled(8, 0.0), 4);
      expect(v, [0.0, 0.0, 0.0, 0.0]);
    });
  });

  group('EmbeddingGemma prompt prefixes', () {
    test('RETRIEVAL_QUERY → query prefix; document/null → document prefix',
        () async {
      final seen = <String>[];
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        dimensions: 2,
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) {
            seen.add(t);
            return [1];
          },
          session: FakeEmbeddingSession((_) => [1.0, 0.0]),
        ),
      );

      await provider.embed(
          texts: ['where do I live'], model: '', taskType: 'RETRIEVAL_QUERY');
      await provider.embed(
          texts: ['Didier lives in Paris'],
          model: '',
          taskType: 'RETRIEVAL_DOCUMENT');
      await provider.embed(texts: ['no task type'], model: '');

      expect(
          seen[0],
          '${AppConstants.localEmbeddingQueryPrefix}where do I live');
      expect(
          seen[1],
          '${AppConstants.localEmbeddingDocumentPrefix}Didier lives in Paris');
      expect(
          seen[2], '${AppConstants.localEmbeddingDocumentPrefix}no task type');
    });
  });

  group('determinism and init', () {
    test('same text embeds to the identical vector', () async {
      // Vector derived from the token ids → determinism flows end to end.
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        dimensions: 4,
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) => t.codeUnits,
          session: FakeEmbeddingSession((ids) =>
              List.generate(8, (i) => (ids.fold<int>(0, (a, b) => a + b) % (i + 7)).toDouble() + 1)),
        ),
      );

      final a = (await provider.embed(texts: ['bonjour'], model: ''))
          .embeddings
          .single;
      final b = (await provider.embed(texts: ['bonjour'], model: ''))
          .embeddings
          .single;
      expect(a, b);
    });

    test('init is single-flight under concurrent embeds', () async {
      var loads = 0;
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        dimensions: 2,
        runtimeLoader: (_, _) async {
          loads++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return LocalEmbeddingRuntime(
            tokenize: (t) => [1],
            session: FakeEmbeddingSession((_) => [1.0, 0.0]),
          );
        },
      );

      await Future.wait([
        provider.embed(texts: ['a'], model: ''),
        provider.embed(texts: ['b'], model: ''),
        provider.embed(texts: ['c'], model: ''),
      ]);
      expect(loads, 1);
    });

    test('token ids are capped at the model context length', () async {
      final session = FakeEmbeddingSession((_) => [1.0, 0.0]);
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        dimensions: 2,
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) =>
              List.filled(AppConstants.localEmbeddingMaxTokens + 500, 7),
          session: session,
        ),
      );

      await provider.embed(texts: ['long'], model: '');
      expect(session.receivedIds.single,
          hasLength(AppConstants.localEmbeddingMaxTokens));
    });

    test('identity getters and dispose', () async {
      final session = FakeEmbeddingSession((_) => [1.0, 0.0]);
      final provider = LocalEmbeddingProvider(
        modelDir: modelDirWithFiles(),
        dimensions: 2,
        runtimeLoader: (_, _) async => LocalEmbeddingRuntime(
          tokenize: (t) => [1],
          session: session,
        ),
      );

      expect(provider.providerName, 'local');
      expect(provider.providerId, AppConstants.localEmbeddingProviderId);
      expect(provider.outputDimensions, 2);

      await provider.embed(texts: ['x'], model: '');
      await provider.dispose();
      expect(session.closed, isTrue);
    });
  });

  group('factory', () {
    test("'local' without apiKey creates the provider", () {
      final provider = EmbeddingProviderFactory.create(
        providerName: 'local',
        dimensions: AppConstants.localEmbeddingDimensions,
        localModelDir: p.join(tempDir.path, 'model'),
      );
      expect(provider, isA<LocalEmbeddingProvider>());
      expect(provider.outputDimensions,
          AppConstants.localEmbeddingDimensions);
    });

    test("'local' without localModelDir throws", () {
      expect(
        () => EmbeddingProviderFactory.create(providerName: 'local'),
        throwsArgumentError,
      );
    });

    test('cloud providers still require an apiKey', () {
      expect(
        () => EmbeddingProviderFactory.create(providerName: 'gemini'),
        throwsArgumentError,
      );
      expect(
        EmbeddingProviderFactory.create(
          providerName: 'gemini',
          apiKey: 'key',
          dimensions: 4,
        ),
        isA<GeminiEmbeddingProvider>(),
      );
    });

    test("defaultModel for 'local' is the EmbeddingGemma id", () {
      expect(EmbeddingProviderFactory.defaultModel('local'),
          AppConstants.localEmbeddingModelId);
    });
  });
}
