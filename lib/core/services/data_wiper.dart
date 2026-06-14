import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/local/storage_service.dart';
import '../config/config_storage.dart';
import '../knowledge/services/knowledge_service.dart';
import '../session/session_manager.dart';

/// Wipes every local data store for the user-facing "erase all data" action:
/// secure storage (all API keys + Telegram token), the cleartext secret
/// mirrors, all SharedPreferences (config, cron definitions, Telegram
/// settings, onboarding flag), sessions (sessions.db + the legacy Hive box
/// files and their migration backups), the knowledge graph, the app
/// workspace directory (memory notes, skills, file-tool files), LLM trace
/// files and app logs.
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
    this.sessionsDbPath,
    this.knowledge,
    this.knowledgeDbPath,
    this.workspacePath,
    this.clearLlmTraces,
    this.clearLogs,
  });

  final StorageService storage;
  final ConfigStorage configStorage;
  final SessionManager? sessions;

  /// Path of the sessions database file (`sessions.db`). Always deleted
  /// when provided (with its `-wal`/`-shm`/`-journal` set): with the
  /// database in the degraded state (closed connections),
  /// `deleteAllSessions()` cannot reach the on-disk rows — it throws and
  /// the step is recorded as failed — so "erase all data" must remove the
  /// files directly (after closing the connections), mirroring the
  /// knowledge DB file deletion below. The legacy Hive box file set
  /// (`<dir>/<boxName>.hive`/`.hivec`/`.lock` and their `.backup` variants
  /// left by the U6 migration) is deleted from the same directory.
  final String? sessionsDbPath;

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

    // 3. Sessions (sessions.db): delete rows via the open manager
    // (best-effort — throws when the database is degraded), close both
    // connections, then ALWAYS delete the database file set: deleted rows
    // remain forensically recoverable inside the .db/-wal pages otherwise.
    // The legacy Hive box files (and the .backup set the U6 migration left
    // behind) are wiped from the same directory.
    if (sessions != null) {
      await step('sessions', sessions!.deleteAllSessions);
      await step('sessions_db_close', sessions!.close);
    }
    if (sessionsDbPath != null) {
      await step('sessions_db_file', () => _deleteDbFiles(sessionsDbPath!));
      await step('sessions_hive_files',
          () => _deleteLegacyHiveFiles(sessionsDbPath!));
    }

    // 4. Knowledge graph: clear via the open service (best-effort), close
    // its connection, then ALWAYS delete the file set — deleted rows remain
    // forensically recoverable inside the .db/-wal pages otherwise.
    // Episodes (U4) live in the same database: an explicit step first
    // (deleteAll covers them too, but a partial deleteAll failure must not
    // leave cached tool results behind), then the file deletion below
    // covers the degraded-service case.
    if (knowledge != null) {
      await step('episodes',
          () => knowledge!.db.customStatement('DELETE FROM episodes'));
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

  /// Delete the legacy Hive sessions box file set living next to
  /// [sessionsDbFilePath]. Hive's on-disk naming (`backend_manager.dart`):
  /// `<name>.hive` (data), `<name>.hivec` (compacted), `<name>.lock` —
  /// plus the `.backup` variants the U6 migration renames them to.
  Future<void> _deleteLegacyHiveFiles(String sessionsDbFilePath) async {
    final base =
        p.join(File(sessionsDbFilePath).parent.path, SessionManager.boxName);
    for (final suffix in ['.hive', '.hivec', '.lock']) {
      for (final backup in ['', '.backup']) {
        final file = File('$base$suffix$backup');
        if (await file.exists()) {
          await file.delete();
        }
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
