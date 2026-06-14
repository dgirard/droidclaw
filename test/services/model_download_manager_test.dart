import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:droidclaw/core/services/model_download_manager.dart';
import 'package:droidclaw/shared/constants.dart';

/// Fake fetcher writing known fixture bytes — unit tests never touch the
/// background_downloader plugin.
class FakeFetcher implements ModelFileFetcher {
  final Map<String, List<int>> contentByFilename;

  /// Filenames whose fetch throws (simulated network failure).
  final Set<String> failOn;

  /// Optional hook invoked before writing a file (e.g. to request cancel).
  final Future<void> Function(ModelFileSpec file)? beforeWrite;

  final List<String> fetched = [];
  final List<String> cancelled = [];

  FakeFetcher(this.contentByFilename, {Set<String>? failOn, this.beforeWrite})
      : failOn = failOn ?? {};

  @override
  Future<void> fetch(
    ModelFileSpec file,
    String destinationPath, {
    required bool allowMetered,
    void Function(double progress)? onProgress,
  }) async {
    if (beforeWrite != null) await beforeWrite!(file);
    if (failOn.contains(file.filename)) {
      throw ModelDownloadException('simulated network failure');
    }
    fetched.add(file.filename);
    onProgress?.call(0.5);
    await File(destinationPath).writeAsBytes(contentByFilename[file.filename]!);
    onProgress?.call(1.0);
  }

  @override
  Future<void> cancel(ModelFileSpec file) async {
    cancelled.add(file.filename);
  }
}

void main() {
  late Directory tempDir;

  // Tiny fixture bytes standing in for the three real model files.
  final contents = {
    'model.onnx': utf8.encode('fake-onnx-model'),
    'model.onnx_data': utf8.encode('fake-external-weights'),
    'tokenizer.json': utf8.encode('{"fake": "tokenizer"}'),
  };

  String hashOf(String filename) => sha256.convert(contents[filename]!).toString();

  ModelFileSpec fileSpec(String filename, {String? sha}) => ModelFileSpec(
        url: 'https://example.test/$filename',
        filename: filename,
        sha256: sha ?? hashOf(filename),
        bytes: contents[filename]!.length,
      );

  ModelSpec spec({Map<String, String?> shaOverrides = const {}}) => ModelSpec(
        id: 'test-model',
        totalBytes:
            contents.values.fold(0, (a, b) => a + b.length),
        files: [
          for (final name in contents.keys)
            fileSpec(name,
                sha: shaOverrides.containsKey(name)
                    ? shaOverrides[name]
                    : null),
        ],
      );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('model_dl_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  ModelDownloadManager manager(FakeFetcher fetcher) => ModelDownloadManager(
        modelsRootDir: tempDir.path,
        fetcher: fetcher,
      );

  group('happy path', () {
    test('downloads 3 files, verifies pinned hashes, promotes to ready',
        () async {
      final fetcher = FakeFetcher(contents);
      final m = manager(fetcher);
      final states = <ModelState>[];
      final sub = m.statusStream.listen((s) => states.add(s.state));

      final s = spec();
      await m.download(s);
      await Future<void>.delayed(Duration.zero);

      expect(await m.isReady(s), isTrue);
      expect(fetcher.fetched, contents.keys.toList());
      for (final name in contents.keys) {
        expect(File(m.filePath(s, name)).readAsBytesSync(), contents[name]);
      }
      // Staging directory is removed after promotion.
      expect(
          Directory(p.join(tempDir.path, '${s.id}.staging')).existsSync(),
          isFalse);
      // State machine: downloading → verifying → ready.
      expect(states.first, ModelState.downloading);
      expect(states, contains(ModelState.verifying));
      expect(states.last, ModelState.ready);
      expect(
          states.indexOf(ModelState.verifying) <
              states.lastIndexOf(ModelState.ready),
          isTrue);
      await sub.cancel();
      m.dispose();
    });

    test(
        'placeholder hash logs the computed digest but does NOT promote to '
        'ready — terminal state is unverified (S1 security gate)', () async {
      final s = spec(shaOverrides: {
        'model.onnx_data': AppConstants.modelSha256Placeholder,
      });
      final m = manager(FakeFetcher(contents));
      await m.download(s);

      // Integrity gate: a file on the placeholder hash must NOT be promoted.
      expect(await m.isReady(s), isFalse);
      expect(m.statusOf(s)!.state, ModelState.unverified);
      // The download still COMPLETED: files are kept in staging so the dev can
      // read the logged hash and pin it (file-level resume on re-download).
      final staging = p.join(tempDir.path, '${s.id}.staging');
      for (final name in contents.keys) {
        expect(File(p.join(staging, name)).existsSync(), isTrue,
            reason: '$name should remain staged for pinning');
      }
      // No final dir / .ready marker was written.
      expect(File(p.join(m.modelDir(s), '.ready')).existsSync(), isFalse);
      m.dispose();
    });

    test('fully-pinned matching download still promotes to ready', () async {
      // All three files carry their real (non-placeholder) hashes.
      final s = spec();
      final m = manager(FakeFetcher(contents));
      await m.download(s);
      expect(await m.isReady(s), isTrue);
      expect(m.statusOf(s)!.state, ModelState.ready);
      m.dispose();
    });

    test('static isReadySync agrees with isReady', () async {
      final s = spec();
      final m = manager(FakeFetcher(contents));
      expect(
          ModelDownloadManager.isReadySync(
              modelsRootDir: tempDir.path, spec: s),
          isFalse);
      await m.download(s);
      expect(
          ModelDownloadManager.isReadySync(
              modelsRootDir: tempDir.path, spec: s),
          isTrue);
      m.dispose();
    });
  });

  group('hash verification', () {
    test('pinned mismatch rejects the file and fails the download', () async {
      final s = spec(shaOverrides: {
        'tokenizer.json': 'deadbeef' * 8, // pinned, wrong
      });
      final m = manager(FakeFetcher(contents));

      await expectLater(
        m.download(s),
        throwsA(isA<ModelDownloadException>().having(
            (e) => e.message, 'message', contains('SHA-256 mismatch'))),
      );
      expect(await m.isReady(s), isFalse);
      expect(m.statusOf(s)!.state, ModelState.failed);
      // The rejected file was deleted from staging; others remain for resume.
      final staging = p.join(tempDir.path, '${s.id}.staging');
      expect(File(p.join(staging, 'tokenizer.json')).existsSync(), isFalse);
      expect(File(p.join(staging, 'model.onnx')).existsSync(), isTrue);
      m.dispose();
    });

    test('streamed sha256 accepts a known digest', () async {
      final f = File(p.join(tempDir.path, 'blob.bin'));
      f.writeAsBytesSync(List<int>.generate(70000, (i) => i % 251));
      final expected = sha256.convert(f.readAsBytesSync()).toString();
      expect(await ModelDownloadManager.computeFileSha256(f), expected);
    });
  });

  group('failure handling', () {
    test('all 3 files are required: failure on the 2nd → failed, not ready',
        () async {
      final s = spec();
      final m = manager(FakeFetcher(contents, failOn: {'model.onnx_data'}));

      await expectLater(m.download(s), throwsA(isA<ModelDownloadException>()));
      expect(await m.isReady(s), isFalse);
      expect(m.statusOf(s)!.state, ModelState.failed);
      expect(m.statusOf(s)!.error, isNotNull);
      m.dispose();
    });

    test('a later failed download never deletes a ready model', () async {
      final s = spec();
      final m1 = manager(FakeFetcher(contents));
      await m1.download(s);
      expect(await m1.isReady(s), isTrue);
      m1.dispose();

      // Second manager with a fetcher that always fails. download() must
      // leave the ready model fully intact.
      final failing = FakeFetcher(contents, failOn: contents.keys.toSet());
      final m2 = manager(failing);
      await m2.download(s); // early-returns: already ready
      expect(failing.fetched, isEmpty);
      expect(await m2.isReady(s), isTrue);
      for (final name in contents.keys) {
        expect(File(m2.filePath(s, name)).readAsBytesSync(), contents[name]);
      }
      expect(m2.statusOf(s)!.state, ModelState.ready);
      m2.dispose();
    });

    test('missing ready marker means not ready even with all files present',
        () async {
      final s = spec();
      final m = manager(FakeFetcher(contents));
      await m.download(s);
      File(p.join(m.modelDir(s), '.ready')).deleteSync();
      expect(await m.isReady(s), isFalse);
      m.dispose();
    });
  });

  group('resume and cancel', () {
    test('fully staged files are not re-downloaded (file-level resume)',
        () async {
      final s = spec();
      // Pre-stage the first file with the exact expected byte length.
      final staging = Directory(p.join(tempDir.path, '${s.id}.staging'))
        ..createSync(recursive: true);
      File(p.join(staging.path, 'model.onnx'))
          .writeAsBytesSync(contents['model.onnx']!);

      final fetcher = FakeFetcher(contents);
      final m = manager(fetcher);
      await m.download(s);

      expect(fetcher.fetched, ['model.onnx_data', 'tokenizer.json']);
      expect(await m.isReady(s), isTrue);
      m.dispose();
    });

    test('cancel between files stops the download without a failed state',
        () async {
      final s = spec();
      late ModelDownloadManager m;
      final fetcher = FakeFetcher(contents, beforeWrite: (file) async {
        if (file.filename == 'model.onnx_data') {
          await m.cancel(s);
        }
      });
      m = manager(fetcher);

      await m.download(s); // cancellation is not an error
      expect(await m.isReady(s), isFalse);
      expect(m.statusOf(s)!.state, ModelState.absent);
      expect(fetcher.cancelled, isNotEmpty);
      m.dispose();
    });
  });

  group('delete and status', () {
    test('delete removes model and staging dirs and emits absent', () async {
      final s = spec();
      final m = manager(FakeFetcher(contents));
      await m.download(s);
      expect(await m.isReady(s), isTrue);

      await m.delete(s);
      expect(await m.isReady(s), isFalse);
      expect(Directory(m.modelDir(s)).existsSync(), isFalse);
      expect(m.statusOf(s)!.state, ModelState.absent);
      m.dispose();
    });

    test('refreshStatus derives ready/absent from disk', () async {
      final s = spec();
      final m = manager(FakeFetcher(contents));
      expect((await m.refreshStatus(s)).state, ModelState.absent);
      await m.download(s);
      expect((await m.refreshStatus(s)).state, ModelState.ready);
      m.dispose();
    });
  });

  group('embeddingGemma spec', () {
    test('spec wires the three HF files with sizes summing to totalBytes', () {
      const s = ModelSpec.embeddingGemmaInt8;
      expect(s.files, hasLength(3));
      expect(s.files.map((f) => f.filename), [
        AppConstants.embeddingGemmaModelFilename,
        AppConstants.embeddingGemmaModelDataFilename,
        AppConstants.embeddingGemmaTokenizerFilename,
      ]);
      expect(
          s.files.fold<int>(0, (a, f) => a + f.bytes), s.totalBytes);
      for (final f in s.files) {
        expect(f.url, startsWith('https://huggingface.co/onnx-community/'));
      }
    });
  });
}
