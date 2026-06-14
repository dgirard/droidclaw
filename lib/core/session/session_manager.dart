import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../shared/constants.dart';
import '../config/log_entry.dart';
import '../services/app_logger.dart';
import 'database/hive_to_sqlite_migrator.dart';
import 'database/sessions_db.dart';
import 'database/sessions_db_path.dart';
import 'database/sync_session_reader.dart';
import 'session.dart';
import 'session_metadata.dart';

/// Manages conversation sessions on SQLite/WAL (`sessions.db`, U6 —
/// successor of the Hive box), with a lazy in-memory cache and a
/// lightweight metadata index.
///
/// Dual-isolate by construction: each FlutterEngine opens its own
/// connections on the same WAL file (the pattern proven in production on
/// the knowledge graph — see [SessionsDb]). A session committed by the
/// other isolate is visible to a fresh [get] immediately; there is no
/// close→reopen reload protocol, no rehydration queue, no per-isolate page
/// cache to desync.
///
/// ## Sync reads over an async database
///
/// [get]/[getOrCreate] are synchronous (pinned API). Drift is async-only,
/// so reads go through [SyncSessionReader] — a second, READ-ONLY
/// `package:sqlite3` connection on the same file. See its docs: this is the
/// load-bearing design decision of U6.
///
/// ## Lazy load (U13, preserved)
///
/// [init]/[reload] read only the metadata COLUMNS (the old `__meta__:`
/// sidecar records became columns, written by the same UPSERT as the
/// payload). Full message histories are decoded on first access of a
/// specific session.
///
/// ## Durability (successor of the tiered Hive flush policy)
///
/// Every [save] is one UPSERT in an implicitly committed transaction; under
/// WAL + `synchronous=NORMAL` the commit is durable against process death
/// (OOM kill, task swipe) the moment it returns. The old tiered fsync
/// cadence is therefore vestigial: `save(flush: false)` commits exactly
/// like `save(flush: true)`. The parameter is kept for API compatibility
/// and [flushCount] keeps counting `flush: true` saves so the flush-POLICY
/// tests still pin which operations are turn-ending. The residual
/// power-loss / kernel-panic window of a NORMAL commit is the same envelope
/// the tiered policy accepted for mid-turn saves — and unlike Hive, WAL
/// can never corrupt the store in that window. Standalone [flush] (app
/// lifecycle pause, provider dispose) additionally runs a PASSIVE WAL
/// checkpoint, moving committed pages into the main db file before Android
/// can kill the process.
///
/// Do NOT add `VACUUM` calls anywhere here — see the ban in [SessionsDb].
class SessionManager {
  /// Name of the LEGACY Hive box. Still public so DataWiper and the
  /// migrator can derive the legacy/backup file paths
  /// (`<dir>/<boxName>.hive[.backup]`).
  static const String boxName = HiveToSqliteMigrator.legacyBoxName;

  /// Lazily decoded full sessions (only the ones actually accessed).
  final Map<String, Session> _cache = {};

  /// Metadata for every persisted session (built at init/reload from the
  /// metadata columns — no payload decode).
  final Map<String, SessionMetadata> _meta = {};

  SessionsDb? _db;
  SyncSessionReader? _reader;

  /// Number of durable turn-ending commits requested (`save(flush: true)`,
  /// deletes, standalone [flush]). Kept from the Hive era so tests can pin
  /// the flush POLICY — which operations are treated as turn-ending — even
  /// though under WAL every commit is equally durable against process kill.
  @visibleForTesting
  int flushCount = 0;

  /// Number of full session JSON decodes performed. Exposed so tests can
  /// pin lazy-load behavior (init must not decode message histories).
  @visibleForTesting
  int sessionDecodeCount = 0;

  /// Initialize the manager: open `sessions.db`, run the one-shot
  /// Hive→SQLite migration if needed, and build the metadata index.
  ///
  /// Both isolates must resolve the SAME directory. Pass [workspacePath]
  /// (the cached workspace path): the directory is derived via
  /// [SessionsDbPath] — its parent, which equals the app documents
  /// directory in the main isolate. [directory] overrides the derivation
  /// for tests.
  Future<void> init({String? workspacePath, String? directory}) async {
    final dir = directory ??
        (workspacePath != null
            ? SessionsDbPath.dirFromWorkspace(workspacePath)
            : null);
    if (dir == null) {
      throw ArgumentError(
          'SessionManager.init needs workspacePath (or a test directory) to '
          'resolve the shared sessions.db location');
    }
    final dbPath = p.join(dir, AppConstants.sessionsDbFilename);
    final db = SessionsDb(dbPath);
    _db = db;

    // One-shot migration (also forces the connection open so the read-only
    // sync reader below can attach). A failed migration is surfaced but not
    // fatal: the manager starts on whatever sessions.db holds, and the Hive
    // files stay untouched on disk for the next attempt.
    try {
      await HiveToSqliteMigrator(db: db, directory: dir).migrate();
    } catch (e) {
      AppLogger.instance.error(
        LogSource.app,
        'Hive→SQLite session migration failed (${e.runtimeType}: $e) — '
        'legacy Hive files left untouched; will retry at next startup',
      );
    }

    _reader = SyncSessionReader.open(dbPath);
    _rebuildIndex();
  }

  /// Lightweight cross-isolate refresh: rebuild the metadata index from the
  /// metadata columns and evict cached instances so the next access
  /// re-reads the latest committed row.
  ///
  /// With WAL there is no close→reopen cycle — a plain [get] already sees
  /// the other isolate's committed writes. reload() only remains so list
  /// screens pick up NEW/DELETED sessions (the in-memory index) after a
  /// cron completion notification. It runs synchronously to completion
  /// (trivially reentrancy-safe: there is no window for a concurrent
  /// [getOrCreate] to observe a half-reloaded state).
  Future<void> reload() async {
    if (_reader == null) return;
    _cache.clear();
    _rebuildIndex();
  }

  /// Rebuild [_meta] from the metadata columns (no payload decode).
  void _rebuildIndex() {
    final reader = _reader;
    if (reader == null) return;
    _meta.clear();
    for (final row in reader.allMetadata()) {
      _meta[row.key] = SessionMetadata(
        key: row.key,
        created: DateTime.fromMillisecondsSinceEpoch(row.created),
        updated: DateTime.fromMillisecondsSinceEpoch(row.updated),
        messageCount: row.messageCount,
        conversationMessageCount: row.conversationMessageCount,
        preview: row.preview,
        summaryPreview: row.summaryPreview,
      );
    }
  }

  Session? _decodeOrNull(String key, String? raw) {
    if (raw == null) return null;
    try {
      sessionDecodeCount++;
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.app,
        'Corrupted session skipped: $key — ${e.runtimeType}',
      );
      return null;
    }
  }

  /// Get or create a session by key (lazily decoding it on first access).
  ///
  /// Invariant: never overwrite persisted history with an empty session.
  /// A sync read is ALWAYS possible (no closed-box window like Hive reload
  /// had), so [get] below authoritatively answers "does a persisted row
  /// exist?" before a fresh session is fabricated — the old rehydration
  /// queue is unnecessary by construction.
  Session getOrCreate(String key) {
    final existing = get(key);
    if (existing != null) return existing;
    final session = Session(key: key);
    _cache[key] = session;
    return session;
  }

  /// Get a session by key, returns null if not found.
  /// First access decodes the full message history from SQLite and caches
  /// it. After [close] (degraded/wiped state) reads are cache-only.
  Session? get(String key) {
    final cached = _cache[key];
    if (cached != null) return cached;
    final reader = _reader;
    if (reader == null) return null;
    final session = _decodeOrNull(key, reader.sessionPayload(key));
    if (session != null) _cache[key] = session;
    return session;
  }

  /// Save a session: one UPSERT writing payload + metadata columns
  /// together, committed (durable to WAL) when the future resolves.
  ///
  /// [flush] is kept for API compatibility with the tiered Hive policy;
  /// both values commit identically under WAL (see the class docs). Keep
  /// passing `flush: false` for mid-turn intermediate saves so the
  /// turn-ending accounting ([flushCount]) stays meaningful.
  Future<void> save(Session session, {bool flush = true}) async {
    _cache[session.key] = session;
    final meta = SessionMetadata.fromSession(session);
    _meta[session.key] = meta;
    final db = _db;
    if (db == null) return; // degraded (closed/wiped): cache-only, no throw
    await db.upsertSession(SessionsCompanion(
      sessionKey: Value(session.key),
      payload: Value(jsonEncode(session.toJson())),
      created: Value(meta.created.millisecondsSinceEpoch),
      updated: Value(meta.updated.millisecondsSinceEpoch),
      messageCount: Value(meta.messageCount),
      conversationMessageCount: Value(meta.conversationMessageCount),
      preview: Value(meta.preview),
      summaryPreview: Value(meta.summaryPreview),
    ));
    if (flush) flushCount++;
  }

  /// Metadata for all sessions, sorted by last updated (newest first).
  /// Sessions created in memory but not yet saved are included.
  List<SessionMetadata> getAllSessionMetadata() {
    final merged = Map<String, SessionMetadata>.of(_meta);
    for (final session in _cache.values) {
      merged[session.key] = SessionMetadata.fromSession(session);
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.updated.compareTo(a.updated));
    return list;
  }

  /// Delete a session (its single row carries both payload and metadata).
  Future<void> deleteSession(String key) async {
    _cache.remove(key);
    _meta.remove(key);
    final db = _db;
    if (db == null) return; // degraded: cache-only, no throw
    await db.deleteSessionRow(key);
    await flush();
  }

  /// Delete every session (cache + SQLite).
  ///
  /// Throws a [StateError] when the database is unavailable (closed/
  /// degraded): the in-memory caches are still cleared, but the on-disk
  /// rows were NOT deleted — a silent success here would let "erase all
  /// data" report a wipe that never reached the disk. DataWiper records the
  /// failure and falls back to deleting the database files directly.
  Future<void> deleteAllSessions() async {
    _cache.clear();
    _meta.clear();
    final db = _db;
    if (db == null) {
      throw StateError(
          'sessions database unavailable (degraded) — on-disk sessions were '
          'not deleted');
    }
    await db.deleteAllSessionRows();
    await flush();
  }

  /// Close both connections (best-effort). Used by DataWiper before
  /// deleting the database files so a live handle cannot resurrect wiped
  /// data. The manager degrades to cache-only afterwards.
  Future<void> close() async {
    final reader = _reader;
    _reader = null;
    reader?.close();
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }

  /// Turn-ending durability point. Commits are already WAL-durable, so this
  /// additionally moves committed pages into the main database file via a
  /// PASSIVE checkpoint (never blocks the other isolate's connection) —
  /// called from the app-pause lifecycle hook and provider dispose.
  Future<void> flush() async {
    final db = _db;
    if (db == null) return;
    flushCount++;
    await db.customStatement('PRAGMA wal_checkpoint(PASSIVE)');
  }

  /// Create a new session with a unique key.
  Session createNew({String? key}) {
    final sessionKey =
        key ?? 'session_${DateTime.now().millisecondsSinceEpoch}';
    final session = Session(key: sessionKey);
    _cache[sessionKey] = session;
    return session;
  }

  /// Get or create the default session.
  Session get defaultSession => getOrCreate(AppConstants.defaultSessionKey);
}
