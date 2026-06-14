import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../shared/constants.dart';
import '../config/log_entry.dart';
import 'app_logger.dart';

/// One file of a downloadable model asset.
class ModelFileSpec {
  final String url;
  final String filename;

  /// Pinned SHA-256 hex digest, or [AppConstants.modelSha256Placeholder].
  /// Placeholder → verification is log-only (the computed hash is logged
  /// prominently so it can be pinned); a pinned mismatch rejects the file.
  final String sha256;

  /// Expected size in bytes (progress weighting only — not enforced).
  final int bytes;

  const ModelFileSpec({
    required this.url,
    required this.filename,
    required this.sha256,
    required this.bytes,
  });

  bool get hasPinnedHash => sha256 != AppConstants.modelSha256Placeholder;
}

/// A multi-file downloadable model (e.g. an ONNX export + tokenizer).
class ModelSpec {
  final String id;
  final List<ModelFileSpec> files;
  final int totalBytes;

  const ModelSpec({
    required this.id,
    required this.files,
    required this.totalBytes,
  });

  /// EmbeddingGemma 308M int8 ONNX export (U2). The three files MUST live in
  /// the same directory: the .onnx file references its external-weights
  /// sibling by filename.
  static const ModelSpec embeddingGemmaInt8 = ModelSpec(
    id: AppConstants.localEmbeddingModelId,
    totalBytes: AppConstants.embeddingGemmaTotalBytes,
    files: [
      ModelFileSpec(
        url: AppConstants.embeddingGemmaModelUrl,
        filename: AppConstants.embeddingGemmaModelFilename,
        sha256: AppConstants.embeddingGemmaModelSha256,
        bytes: AppConstants.embeddingGemmaModelBytes,
      ),
      ModelFileSpec(
        url: AppConstants.embeddingGemmaModelDataUrl,
        filename: AppConstants.embeddingGemmaModelDataFilename,
        sha256: AppConstants.embeddingGemmaModelDataSha256,
        bytes: AppConstants.embeddingGemmaModelDataBytes,
      ),
      ModelFileSpec(
        url: AppConstants.embeddingGemmaTokenizerUrl,
        filename: AppConstants.embeddingGemmaTokenizerFilename,
        sha256: AppConstants.embeddingGemmaTokenizerSha256,
        bytes: AppConstants.embeddingGemmaTokenizerBytes,
      ),
    ],
  );

  /// sherpa-onnx open-vocabulary KWS model (U7 — wake word). Encoder /
  /// decoder / joiner / tokens MUST share a directory (they refer to each
  /// other by sibling filename). URLs/hashes pinned once the spike picks the
  /// final model; until then verification is log-only (placeholder hashes).
  static const ModelSpec wakeWordKws = ModelSpec(
    id: AppConstants.wakeWordModelId,
    totalBytes: AppConstants.wakeWordTotalBytes,
    files: [
      ModelFileSpec(
        url: '${AppConstants.wakeWordModelRepoBase}/'
            '${AppConstants.wakeWordEncoderFilename}',
        filename: AppConstants.wakeWordEncoderFilename,
        sha256: AppConstants.wakeWordEncoderSha256,
        bytes: AppConstants.wakeWordEncoderBytes,
      ),
      ModelFileSpec(
        url: '${AppConstants.wakeWordModelRepoBase}/'
            '${AppConstants.wakeWordDecoderFilename}',
        filename: AppConstants.wakeWordDecoderFilename,
        sha256: AppConstants.wakeWordDecoderSha256,
        bytes: AppConstants.wakeWordDecoderBytes,
      ),
      ModelFileSpec(
        url: '${AppConstants.wakeWordModelRepoBase}/'
            '${AppConstants.wakeWordJoinerFilename}',
        filename: AppConstants.wakeWordJoinerFilename,
        sha256: AppConstants.wakeWordJoinerSha256,
        bytes: AppConstants.wakeWordJoinerBytes,
      ),
      ModelFileSpec(
        url: '${AppConstants.wakeWordModelRepoBase}/'
            '${AppConstants.wakeWordTokensFilename}',
        filename: AppConstants.wakeWordTokensFilename,
        sha256: AppConstants.wakeWordTokensSha256,
        bytes: AppConstants.wakeWordTokensBytes,
      ),
    ],
  );
}

/// Lifecycle of a model on this device.
enum ModelState { absent, downloading, verifying, ready, failed }

/// Snapshot of a model's state, emitted on [ModelDownloadManager.statusStream].
class ModelStatus {
  final String modelId;
  final ModelState state;

  /// Overall progress 0..1 (byte-weighted across files); meaningful while
  /// [state] is [ModelState.downloading].
  final double progress;

  final String? error;

  const ModelStatus({
    required this.modelId,
    required this.state,
    this.progress = 0,
    this.error,
  });
}

/// Fetches one model file to a destination path. Seam so unit tests never
/// touch the background_downloader plugin.
abstract class ModelFileFetcher {
  Future<void> fetch(
    ModelFileSpec file,
    String destinationPath, {
    required bool allowMetered,
    void Function(double progress)? onProgress,
  });

  /// Best-effort cancel of an in-flight fetch for [file].
  Future<void> cancel(ModelFileSpec file);
}

/// Production fetcher backed by background_downloader (WorkManager-backed,
/// resumes via HTTP ranges on the HF CDN).
class BackgroundDownloaderFetcher implements ModelFileFetcher {
  final FileDownloader _downloader;

  BackgroundDownloaderFetcher({FileDownloader? downloader})
      : _downloader = downloader ?? FileDownloader();

  static String _taskId(ModelFileSpec file) => 'model:${file.filename}';

  @override
  Future<void> fetch(
    ModelFileSpec file,
    String destinationPath, {
    required bool allowMetered,
    void Function(double progress)? onProgress,
  }) async {
    final task = DownloadTask(
      taskId: _taskId(file),
      url: file.url,
      baseDirectory: BaseDirectory.root,
      directory: p.dirname(destinationPath),
      filename: p.basename(destinationPath),
      requiresWiFi: !allowMetered,
      allowPause: true,
      updates: Updates.statusAndProgress,
      retries: AppConstants.httpMaxRetries,
    );
    final result = await _downloader.download(
      task,
      onProgress: (v) {
        // background_downloader uses negative sentinel values for
        // non-progress updates; only forward real fractions.
        if (v >= 0 && onProgress != null) onProgress(v.clamp(0.0, 1.0));
      },
    );
    if (result.status != TaskStatus.complete) {
      throw ModelDownloadException(
          'Download of ${file.filename} ended with status '
          '${result.status.name}'
          '${result.exception != null ? ': ${result.exception}' : ''}');
    }
  }

  @override
  Future<void> cancel(ModelFileSpec file) async {
    await _downloader.cancelTaskWithId(_taskId(file));
  }
}

/// Thrown when a model download or verification fails.
class ModelDownloadException implements Exception {
  final String message;
  const ModelDownloadException(this.message);

  @override
  String toString() => 'ModelDownloadException: $message';
}

/// Generic large-asset download manager for on-device models.
///
/// Layout: `<modelsRootDir>/<spec.id>/` holds the verified files plus a
/// `.ready` marker; `<modelsRootDir>/<spec.id>.staging/` is the in-progress
/// area. Files are downloaded and SHA-256-verified in staging, then moved
/// into the final directory in one pass — so a transient failure NEVER
/// deletes or degrades a model that is already `ready` (ProofEditor-404
/// lesson: ambiguous failures must not destroy working state).
///
/// SHA-256 policy: a pinned hash mismatch rejects the file (deleted from
/// staging, state `failed`). A placeholder hash
/// ([AppConstants.modelSha256Placeholder]) runs in log-only warn mode and
/// logs the computed hash prominently so it can be pinned in constants after
/// the first verified download.
class ModelDownloadManager {
  /// Absolute root for all models, derived from the app documents directory
  /// (the workspace's parent — see [AppConstants.modelsDirName] for why it
  /// must NOT live inside the workspace).
  final String modelsRootDir;

  final ModelFileFetcher _fetcher;

  final _statusController = StreamController<ModelStatus>.broadcast();
  final Map<String, ModelStatus> _statuses = {};
  final Set<String> _cancelRequested = {};

  static const String _readyMarker = '.ready';
  static const String _stagingSuffix = '.staging';

  ModelDownloadManager({
    required this.modelsRootDir,
    ModelFileFetcher? fetcher,
  }) : _fetcher = fetcher ?? BackgroundDownloaderFetcher();

  /// Models root derived from a workspace path (usable from both isolates —
  /// the service isolate derives it the same way without path_provider).
  static String rootFromWorkspace(String workspacePath) =>
      p.join(p.dirname(workspacePath), AppConstants.modelsDirName);

  /// Final directory of a model's files.
  String modelDir(ModelSpec spec) => p.join(modelsRootDir, spec.id);

  /// Absolute path of one file of a (ready) model.
  String filePath(ModelSpec spec, String filename) =>
      p.join(modelDir(spec), filename);

  String _stagingDir(ModelSpec spec) =>
      p.join(modelsRootDir, '${spec.id}$_stagingSuffix');

  /// Status updates for all models managed by this instance.
  Stream<ModelStatus> get statusStream => _statusController.stream;

  /// Current in-memory status (falls back to a disk check via [refreshStatus]
  /// when the manager has not touched this model yet).
  ModelStatus? statusOf(ModelSpec spec) => _statuses[spec.id];

  /// True when every file of [spec] is present and the ready marker is set.
  Future<bool> isReady(ModelSpec spec) async {
    final dir = modelDir(spec);
    if (!File(p.join(dir, _readyMarker)).existsSync()) return false;
    for (final f in spec.files) {
      if (!File(p.join(dir, f.filename)).existsSync()) return false;
    }
    return true;
  }

  /// Static ready check usable without a manager instance (service isolate).
  static bool isReadySync({
    required String modelsRootDir,
    required ModelSpec spec,
  }) {
    final dir = p.join(modelsRootDir, spec.id);
    if (!File(p.join(dir, _readyMarker)).existsSync()) return false;
    for (final f in spec.files) {
      if (!File(p.join(dir, f.filename)).existsSync()) return false;
    }
    return true;
  }

  /// Re-derive the status from disk (for UI startup).
  Future<ModelStatus> refreshStatus(ModelSpec spec) async {
    final current = _statuses[spec.id];
    if (current != null &&
        (current.state == ModelState.downloading ||
            current.state == ModelState.verifying)) {
      return current;
    }
    final ready = await isReady(spec);
    final status = ModelStatus(
      modelId: spec.id,
      state: ready ? ModelState.ready : ModelState.absent,
      progress: ready ? 1 : 0,
    );
    _emit(status);
    return status;
  }

  /// Download (or resume) all files of [spec], verify them, and promote to
  /// `ready`. Wi-Fi required by default; [allowMetered] overrides.
  ///
  /// Throws [ModelDownloadException] on failure (state is set to `failed`
  /// first). A model already `ready` is left untouched on any failure.
  Future<void> download(ModelSpec spec, {bool allowMetered = false}) async {
    if (await isReady(spec)) {
      _emit(ModelStatus(
          modelId: spec.id, state: ModelState.ready, progress: 1));
      return;
    }
    _cancelRequested.remove(spec.id);

    final staging = Directory(_stagingDir(spec));
    await staging.create(recursive: true);

    final completedBytes = <String, int>{};
    final inFlight = <String, double>{};
    void emitProgress() {
      var done = completedBytes.values.fold<int>(0, (a, b) => a + b);
      for (final entry in inFlight.entries) {
        final f = spec.files.firstWhere((x) => x.filename == entry.key);
        done += (f.bytes * entry.value).round();
      }
      _emit(ModelStatus(
        modelId: spec.id,
        state: ModelState.downloading,
        progress: spec.totalBytes > 0
            ? (done / spec.totalBytes).clamp(0.0, 1.0)
            : 0,
      ));
    }

    try {
      _emit(ModelStatus(modelId: spec.id, state: ModelState.downloading));

      // 1. Fetch each file still missing from staging (file-level resume:
      // a previously completed staged file is not re-downloaded; byte-level
      // resume within a file is handled by background_downloader).
      for (final file in spec.files) {
        _checkCancelled(spec);
        final dest = File(p.join(staging.path, file.filename));
        if (dest.existsSync() && dest.lengthSync() == file.bytes) {
          completedBytes[file.filename] = file.bytes;
          emitProgress();
          continue;
        }
        await _fetcher.fetch(
          file,
          dest.path,
          allowMetered: allowMetered,
          onProgress: (v) {
            inFlight[file.filename] = v;
            emitProgress();
          },
        );
        inFlight.remove(file.filename);
        completedBytes[file.filename] = file.bytes;
        emitProgress();
        _checkCancelled(spec);
      }

      // 2. Verify all files (streamed SHA-256).
      _emit(ModelStatus(
          modelId: spec.id, state: ModelState.verifying, progress: 1));
      for (final file in spec.files) {
        final staged = File(p.join(staging.path, file.filename));
        if (!staged.existsSync()) {
          throw ModelDownloadException(
              '${file.filename} missing after download');
        }
        final computed = await computeFileSha256(staged);
        if (file.hasPinnedHash) {
          if (computed != file.sha256.toLowerCase()) {
            // Pinned mismatch: reject the corrupt/tampered file.
            await staged.delete();
            throw ModelDownloadException(
                'SHA-256 mismatch for ${file.filename}: '
                'expected ${file.sha256}, got $computed');
          }
        } else {
          // Placeholder hash: warn-only mode. Log the computed hash
          // prominently so it can be pinned in AppConstants.
          AppLogger.instance.warning(
              LogSource.app,
              'PIN-ME sha256(${spec.id}/${file.filename}) = $computed '
              '(currently unpinned — copy into AppConstants to enforce)');
        }
      }

      // 3. Promote: move verified files into the final dir, set the marker.
      final finalDir = Directory(modelDir(spec));
      await finalDir.create(recursive: true);
      for (final file in spec.files) {
        final staged = File(p.join(staging.path, file.filename));
        await staged.rename(p.join(finalDir.path, file.filename));
      }
      await File(p.join(finalDir.path, _readyMarker))
          .writeAsString(DateTime.now().toIso8601String());
      await staging.delete(recursive: true);

      AppLogger.instance
          .info(LogSource.app, 'Model ${spec.id} downloaded and ready');
      _emit(
          ModelStatus(modelId: spec.id, state: ModelState.ready, progress: 1));
    } catch (e) {
      // Never delete a ready model on later failures — staging is kept as-is
      // (partial files allow resume); only the status reflects the failure.
      final cancelled = e is _DownloadCancelled;
      AppLogger.instance.warning(LogSource.app,
          'Model ${spec.id} download ${cancelled ? 'cancelled' : 'failed'}: $e');
      if (await isReady(spec)) {
        _emit(ModelStatus(
            modelId: spec.id, state: ModelState.ready, progress: 1));
      } else {
        _emit(ModelStatus(
          modelId: spec.id,
          state: cancelled ? ModelState.absent : ModelState.failed,
          error: cancelled ? null : '$e',
        ));
      }
      if (cancelled) return;
      if (e is ModelDownloadException) rethrow;
      throw ModelDownloadException('$e');
    }
  }

  /// Request cancellation of an in-flight download (checked between files;
  /// the current file's transfer is cancelled best-effort).
  Future<void> cancel(ModelSpec spec) async {
    _cancelRequested.add(spec.id);
    for (final file in spec.files) {
      await _fetcher.cancel(file);
    }
  }

  /// Delete a model (explicit user action from settings — DataWiper does NOT
  /// delete models; they are cached assets, not user data).
  Future<void> delete(ModelSpec spec) async {
    for (final dirPath in [modelDir(spec), _stagingDir(spec)]) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
    _emit(ModelStatus(modelId: spec.id, state: ModelState.absent));
  }

  /// Streamed SHA-256 of a file (never loads it fully into memory).
  static Future<String> computeFileSha256(File file) async {
    final out = _DigestSink();
    final input = sha256.startChunkedConversion(out);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return out.digest.toString();
  }

  void _checkCancelled(ModelSpec spec) {
    if (_cancelRequested.remove(spec.id)) {
      throw const _DownloadCancelled();
    }
  }

  void _emit(ModelStatus status) {
    _statuses[status.modelId] = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void dispose() {
    _statusController.close();
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();

  @override
  String toString() => 'cancelled';
}

class _DigestSink implements Sink<Digest> {
  late final Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
