import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:hive/hive.dart';

import '../../shared/constants.dart';
import '../services/app_logger.dart';
import '../config/log_entry.dart';
import 'isolate_persistence/cache_reload.dart';
import 'isolate_persistence/hive_path_resolver.dart';
import 'session.dart';
import 'session_metadata.dart';

/// Manages conversation sessions with Hive persistence, a lazy in-memory
/// cache, and a lightweight metadata index.
///
/// Dual-isolate aware: persistence mechanics (path resolution, cache reload,
/// write-then-notify ordering) live in `isolate_persistence/`. Note the
/// cross-isolate compaction constraint documented in [CacheReload] — do not
/// add `compact()` calls here.
///
/// ## Lazy load (U13)
///
/// `init()`/`reload()` build only the [SessionMetadata] index (sidecar
/// records under [AppConstants.sessionMetaKeyPrefix], written on every
/// save). Full message histories are decoded on first access of a specific
/// session ([get]/[getOrCreate]). Legacy records without a metadata sidecar
/// are fully decoded once at init and healed (metadata written back), so
/// subsequent startups stay lazy.
///
/// ## Flush (fsync) policy (U13 — absorbs todos/002 and todos/004)
///
/// Flush layers were introduced against three field incidents of session
/// loss (`docs/solutions/database-issues/session-data-loss-hive-flush-and-
/// destructive-reads.md`). The cadence is tiered, not removed:
///
/// | operation                                          | fsync? |
/// |----------------------------------------------------|--------|
/// | `save()` (default) — final response / turn-ending  | yes    |
/// | `save(flush: false)` — mid-turn tool batch,        | no     |
/// |   post-summarization save (agent_loop.dart)        |        |
/// | `deleteSession` / `deleteAllSessions`              | yes    |
/// | cross-isolate handoff (persist-then-notify,        | yes    |
/// |   cron saves in background_task_handler /          |        |
/// |   background_service_provider — default `save()`)  |        |
/// | app paused/detached (`app.dart` lifecycle) and     | yes    |
/// |   provider dispose (`app_providers.dart`)          | yes    |
/// | metadata heal / index writes                       | no     |
///
/// Why skipping fsync mid-turn is safe: every write is an *awaited*
/// `box.put()` — Hive completes the file-write syscall before the future
/// resolves, so the bytes are in the OS page cache and survive a process
/// SIGKILL (OOM kill, task swipe). What an unflushed write does NOT survive
/// is power loss / kernel panic; for mid-turn tool results that residual
/// window is accepted (the LLM re-requests reproducible tool calls), and the
/// post-summarization save is recoverable by construction (the on-disk state
/// is then a superset; summarization simply re-runs). Everything the user
/// would actually lose — final responses, deletes, cron handoffs — still
/// fsyncs, and the lifecycle layers (now load-bearing, see todos/004) flush
/// any pending intermediate writes when Android backgrounds the app.
class SessionManager {
  static const String _boxName = 'sessions';

  /// Lazily decoded full sessions (only the ones actually accessed).
  final Map<String, Session> _cache = {};

  /// Metadata for every persisted session (built at init/reload).
  final Map<String, SessionMetadata> _meta = {};

  Box<String>? _box;

  /// Number of `box.flush()` (fsync) calls issued. Exposed so tests can pin
  /// the flush POLICY (which operations fsync) — a true SIGKILL-without-
  /// page-cache crash cannot be simulated honestly in-process.
  @visibleForTesting
  int flushCount = 0;

  /// Number of full session JSON decodes performed. Exposed so tests can
  /// pin lazy-load behavior (init must not decode message histories).
  @visibleForTesting
  int sessionDecodeCount = 0;

  /// Initialize the session manager and open the Hive box.
  ///
  /// In the main isolate, `Hive.initFlutter()` (called in `main.dart`) has
  /// already set the Hive home directory — pass nothing. In the service
  /// isolate (no Flutter binding), pass [workspacePath]: the Hive home is
  /// derived from it via [HivePathResolver], guaranteeing both isolates open
  /// the SAME box file.
  Future<void> init({String? workspacePath}) async {
    if (workspacePath != null) {
      Hive.init(HivePathResolver.hiveDirFromWorkspace(workspacePath));
    }
    _box = await Hive.openBox<String>(_boxName);

    // Build the metadata index only — no full history decode (lazy load).
    // Legacy/crash-gap records get healed (metadata written back) so the
    // next startup is fully lazy.
    await _rebuildIndex(_box!, writeBackMissingMeta: true);
  }

  /// Reload sessions from Hive to pick up writes from other isolates.
  /// Closes and reopens the Hive box to force a disk re-read.
  Future<void> reload() async {
    final box = _box;
    if (box == null) return;
    _box = await CacheReload.reload(
      box: box,
      rebuild: (reopened) async {
        _cache.clear();
        // Read-only rebuild: no heal writes from the reload path (it runs
        // on cron-completion notifications, when the service isolate may
        // also be writing).
        await _rebuildIndex(reopened, writeBackMissingMeta: false);
      },
    );
  }

  /// Rebuild the [_meta] index from [box]. Sessions with a metadata sidecar
  /// are NOT decoded; legacy/corrupt-sidecar entries fall back to a full
  /// decode (and, when [writeBackMissingMeta], get the sidecar written back
  /// — without fsync: metadata is derivable, losing it is harmless).
  /// Corrupted session records are skipped entry-by-entry, never aborting
  /// the whole rebuild.
  Future<void> _rebuildIndex(
    Box<String> box, {
    required bool writeBackMissingMeta,
  }) async {
    _meta.clear();
    final metaRaw = <String, String>{};
    final sessionKeys = <String>[];
    for (final key in box.keys) {
      final k = key as String;
      if (k.startsWith(AppConstants.sessionMetaKeyPrefix)) {
        final raw = box.get(k);
        if (raw != null) {
          metaRaw[k.substring(AppConstants.sessionMetaKeyPrefix.length)] = raw;
        }
      } else {
        sessionKeys.add(k);
      }
    }

    for (final key in sessionKeys) {
      final rawMeta = metaRaw.remove(key);
      if (rawMeta != null) {
        try {
          _meta[key] = SessionMetadata.fromJson(
              jsonDecode(rawMeta) as Map<String, dynamic>);
          continue;
        } catch (_) {
          // Corrupt sidecar — rebuild it from the session record below.
        }
      }
      final session = _decodeOrNull(key, box.get(key));
      if (session == null) continue; // corrupt session — logged and skipped
      final meta = SessionMetadata.fromSession(session);
      _meta[key] = meta;
      if (writeBackMissingMeta) {
        await box.put(AppConstants.sessionMetaKeyPrefix + key,
            jsonEncode(meta.toJson()));
      }
    }

    // Leftover sidecars whose session record is gone (e.g. crash between
    // the two deletes of deleteSession): never list them as ghosts; prune
    // them when we are allowed to write.
    if (writeBackMissingMeta) {
      for (final orphan in metaRaw.keys) {
        await box.delete(AppConstants.sessionMetaKeyPrefix + orphan);
      }
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
  Session getOrCreate(String key) {
    return get(key) ?? (_cache[key] = Session(key: key));
  }

  /// Get a session by key, returns null if not found.
  /// First access decodes the full message history from Hive and caches it.
  Session? get(String key) {
    final cached = _cache[key];
    if (cached != null) return cached;
    final box = _box;
    // isOpen guard: during reload()'s close→reopen window (and only then)
    // the handle is briefly closed — fall back to cache-only, like the
    // pre-lazy behavior.
    if (box == null || !box.isOpen) return null;
    final session = _decodeOrNull(key, box.get(key));
    if (session != null) _cache[key] = session;
    return session;
  }

  /// Save a session (and its metadata sidecar) to Hive.
  ///
  /// [flush] (default true) fsyncs the box — see the flush policy in the
  /// class docs. Pass `flush: false` ONLY for mid-turn intermediate saves
  /// whose loss is recoverable (tool batches, post-summarization saves).
  Future<void> save(Session session, {bool flush = true}) async {
    _cache[session.key] = session;
    final meta = SessionMetadata.fromSession(session);
    _meta[session.key] = meta;
    await _box?.put(session.key, jsonEncode(session.toJson()));
    await _box?.put(AppConstants.sessionMetaKeyPrefix + session.key,
        jsonEncode(meta.toJson()));
    if (flush) await this.flush();
  }

  /// Metadata for all sessions, sorted by last updated (newest first).
  ///
  /// This replaces the old `getAllSessions()` (which returned fully decoded
  /// [Session]s): list screens only need metadata. Callers that need full
  /// histories (export, KG rebuild) fetch each via [get].
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

  /// Delete a session (and its metadata sidecar) and force sync to disk.
  Future<void> deleteSession(String key) async {
    _cache.remove(key);
    _meta.remove(key);
    // Sidecar first: a crash in between leaves a session without metadata
    // (healed at next init) rather than a ghost list entry.
    await _box?.delete(AppConstants.sessionMetaKeyPrefix + key);
    await _box?.delete(key);
    await flush();
  }

  /// Delete every session (cache + Hive) and force sync to disk.
  Future<void> deleteAllSessions() async {
    _cache.clear();
    _meta.clear();
    await _box?.clear();
    await flush();
  }

  /// Force sync all pending Hive writes to disk.
  Future<void> flush() async {
    final box = _box;
    if (box == null) return;
    flushCount++;
    await box.flush();
  }

  /// Create a new session with a unique key.
  Session createNew({String? key}) {
    final sessionKey = key ?? 'session_${DateTime.now().millisecondsSinceEpoch}';
    final session = Session(key: sessionKey);
    _cache[sessionKey] = session;
    return session;
  }

  /// Get or create the default session.
  Session get defaultSession => getOrCreate(AppConstants.defaultSessionKey);
}
