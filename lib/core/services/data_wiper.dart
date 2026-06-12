import 'dart:io';

import '../../data/local/storage_service.dart';
import '../config/config_storage.dart';
import '../knowledge/services/knowledge_service.dart';
import '../session/session_manager.dart';

/// Wipes every local data store for the user-facing "erase all data" action:
/// secure storage (all API keys + Telegram token), the cleartext secret
/// mirrors, all SharedPreferences (config, cron definitions, Telegram
/// settings, onboarding flag), sessions (Hive), the knowledge graph, the
/// app workspace directory (memory notes, skills, file-tool files), LLM
/// trace files and app logs.
///
/// Every step is best-effort: a failure in one store must not prevent the
/// others from being wiped.
///
/// Deliberately NOT wiped: downloaded model files (`droidclaw_models/`, next
/// to the workspace — see `AppConstants.modelsDirName`). They are cached
/// public assets (e.g. the EmbeddingGemma ONNX export), contain no user data,
/// and cost ~330 MB to re-download. Deleting a model is an explicit action in
/// Settings → Embeddings (ModelDownloadManager.delete).
class DataWiper {
  DataWiper({
    required this.storage,
    required this.configStorage,
    this.sessions,
    this.sessionsBoxPath,
    this.knowledge,
    this.knowledgeDbPath,
    this.workspacePath,
    this.clearLlmTraces,
    this.clearLogs,
  });

  final StorageService storage;
  final ConfigStorage configStorage;
  final SessionManager? sessions;

  /// Base path of the Hive sessions box file set (`<base>.hive`, `<base>.hivec`,
  /// `<base>.lock`), i.e. `<hiveDir>/${SessionManager.boxName}`. Always
  /// deleted when provided: with the box in the degraded state (closed
  /// handle), `deleteAllSessions()` cannot reach the on-disk records — it
  /// throws and the step is recorded as failed — so "erase all data" must
  /// remove the files directly (after closing the box), mirroring the
  /// knowledge DB file deletion below.
  final String? sessionsBoxPath;

  final KnowledgeService? knowledge;

  /// Path of the knowledge graph DB file set (.db, -wal, -shm, -journal).
  /// Always deleted when provided: DELETE-ing rows through a live
  /// [knowledge] service leaves the data recoverable in the .db/-wal pages,
  /// so "erase all data" must also remove the files (after closing the open
  /// connection). The provider cascade invalidation after the wipe rebuilds
  /// the DB from scratch.
  final String? knowledgeDbPath;

  /// Root of the sandboxed app workspace (memory notes, skills artifacts,
  /// file-tool files). Its contents are deleted; the directory itself is
  /// kept so tools keep working after the wipe.
  final String? workspacePath;

  final Future<void> Function()? clearLlmTraces;
  final Future<void> Function()? clearLogs;

  /// Wipe everything. Returns the list of step names that failed (empty on
  /// full success).
  Future<List<String>> wipeAll() async {
    final failures = <String>[];

    Future<void> step(String name, Future<void> Function() run) async {
      try {
        await run();
      } catch (_) {
        failures.add(name);
      }
    }

    // 1. All secure-storage entries (API keys, Telegram token, probe value).
    await step('secure_storage', storage.deleteSecureAll);

    // 2. Cleartext secret mirrors (also covered by clearPrefs below, but
    // explicit so secrets go first even if the full clear fails).
    await step('secret_mirrors', configStorage.wipeCachedSecrets);

    // 3. Sessions (Hive): clear via the open manager (best-effort — throws
    // when the box is degraded), close the box handle, then ALWAYS delete
    // the box file set: a degraded manager cannot reach the on-disk records,
    // and a clear() through a live box leaves the file itself behind.
    if (sessions != null) {
      await step('sessions', sessions!.deleteAllSessions);
      await step('sessions_box_close', sessions!.close);
    }
    if (sessionsBoxPath != null) {
      await step(
          'sessions_box_file', () => _deleteHiveBoxFiles(sessionsBoxPath!));
    }

    // 4. Knowledge graph: clear via the open service (best-effort), close
    // its connection, then ALWAYS delete the file set — deleted rows remain
    // forensically recoverable inside the .db/-wal pages otherwise.
    if (knowledge != null) {
      await step('knowledge', knowledge!.deleteAll);
      await step('knowledge_db_close', knowledge!.db.close);
    }
    if (knowledgeDbPath != null) {
      await step('knowledge_db_file', () => _deleteDbFiles(knowledgeDbPath!));
    }

    // 5. LLM trace files.
    if (clearLlmTraces != null) {
      await step('llm_traces', clearLlmTraces!);
    }

    // 6. All SharedPreferences: config, cron definitions, Telegram settings,
    // onboarding flag, capability flag, remaining caches.
    await step('shared_preferences', storage.clearPrefs);

    // 7. Workspace contents: memory notes (personal facts), skills
    // artifacts, file-tool files. The directory itself is kept.
    if (workspacePath != null) {
      await step('workspace', () => _wipeDirectoryContents(workspacePath!));
    }

    // 8. App logs last, so the wipe itself can still be logged before this.
    if (clearLogs != null) {
      await step('logs', clearLogs!);
    }

    return failures;
  }

  /// Delete everything inside [dirPath] but keep the directory itself, so
  /// tools sandboxed to it don't break after the wipe.
  Future<void> _wipeDirectoryContents(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;
    await for (final entry in dir.list(followLinks: false)) {
      await entry.delete(recursive: true);
    }
  }

  /// Delete the Hive box file set for [basePath] (no extension). Hive's
  /// on-disk naming (`backend_manager.dart`): `<name>.hive` (data),
  /// `<name>.hivec` (compacted), `<name>.lock`.
  Future<void> _deleteHiveBoxFiles(String basePath) async {
    for (final suffix in ['.hive', '.hivec', '.lock']) {
      final file = File('$basePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _deleteDbFiles(String dbPath) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$dbPath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
