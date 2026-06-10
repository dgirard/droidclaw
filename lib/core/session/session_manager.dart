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
  /// Hive box name. Public so DataWiper can derive the on-disk box file path
  /// (`<hiveDir>/<boxName>.hive`) for the file-level wipe fallback.
  static const String boxName = 'sessions';

  /// Lazily decoded full sessions (only the ones actually accessed).
  final Map<String, Session> _cache = {};

  /// Metadata for every persisted session (built at init/reload).
  final Map<String, SessionMetadata> _meta = {};

  /// Sessions fabricated by [getOrCreate] while their persisted record was
  /// unreadable (reload()'s close→reopen window, or the degraded box state).
  /// [_rehydrateFabricated] merges the on-disk history back into these same
  /// instances once the box is readable again — BEFORE any awaited [save]
  /// proceeds — so an empty fabricated session can never overwrite persisted
  /// history.
  final Map<String, Session> _awaitingRehydration = {};

  /// The in-flight [reload], if any. Mutating operations await it before
  /// touching the box; a reentrant [reload] returns it instead of starting
  /// a second close→reopen cycle on the same handle.
  Future<void>? _reloading;

  Box<String>? _box;

  /// The box, but only when it is actually open. Null during reload()'s
  /// close→reopen window and in the degraded state after a failed reload
  /// recovery — callers fall back to cache-only instead of throwing a
  /// HiveError mid-turn.
  Box<String>? get _openBox {
    final box = _box;
    return (box != null && box.isOpen) ? box : null;
  }

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
    _box = await Hive.openBox<String>(boxName);

    // Build the metadata index only — no full history decode (lazy load).
    // Legacy/crash-gap records get healed (metadata written back) so the
    // next startup is fully lazy.
    await _rebuildIndex(_box!, writeBackMissingMeta: true);
  }

  /// Reload sessions from Hive to pick up writes from other isolates.
  /// Closes and reopens the Hive box to force a disk re-read.
  ///
  /// Failure recovery: if the close→reopen→rebuild sequence throws, attempt
  /// a plain reopen so [_box] points to an OPEN box again — a stale
  /// cache/index beats throwing a HiveError on every subsequent save. If
  /// even that fails, the manager degrades to cache-only: the [_openBox]
  /// guards keep [get]/[save]/[flush] from throwing mid-turn.
  ///
  /// Reentrancy/concurrency: a reload already in flight is returned as-is
  /// (never two concurrent close→reopen cycles), and every mutating
  /// operation ([save], [deleteSession], [deleteAllSessions], [flush])
  /// awaits the in-flight reload before touching the box.
  Future<void> reload() {
    final inflight = _reloading;
    if (inflight != null) return inflight;
    final run = _doReload().whenComplete(() => _reloading = null);
    _reloading = run;
    return run;
  }

  Future<void> _doReload() async {
    final box = _box;
    if (box == null) return;
    try {
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
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.app,
        'Session box reload failed (${e.runtimeType}) — '
        'attempting plain reopen',
      );
      try {
        // Hive returns the already-open instance if the reopen inside
        // CacheReload succeeded but the rebuild failed afterwards.
        _box = await Hive.openBox<String>(boxName);
      } catch (e2) {
        AppLogger.instance.error(
          LogSource.app,
          'Session box recovery reopen failed (${e2.runtimeType}) — '
          'persistence degraded to in-memory cache until restart',
        );
        // _box may point at a closed handle; _openBox keeps operations
        // cache-only instead of throwing.
      }
    } finally {
      // Runs before reload()'s future resolves: every operation that awaited
      // the in-flight reload observes the rehydrated state.
      _rehydrateFabricated();
    }
  }

  /// Merge persisted histories back into sessions fabricated while the box
  /// was unreadable (see [getOrCreate]). The merged messages are PREPENDED
  /// into the same [Session] instance the caller holds, so nothing added
  /// mid-reload is lost and a subsequent [save] writes the full history.
  void _rehydrateFabricated() {
    if (_awaitingRehydration.isEmpty) return;
    final box = _openBox;
    if (box == null) return; // still degraded — retry on the next reload
    for (final key in _awaitingRehydration.keys.toList()) {
      final fabricated = _awaitingRehydration.remove(key)!;
      final persisted = _decodeOrNull(key, box.get(key));
      if (persisted == null) {
        // Record gone (deleted by the other isolate) or corrupt — nothing
        // recoverable to merge. Keep the in-memory session as-is.
        AppLogger.instance.warning(
          LogSource.app,
          'Session $key could not be rehydrated after reload (record '
          'missing or unreadable) — keeping the in-memory session',
        );
      } else {
        fabricated.absorbPersistedHistory(persisted);
      }
      // Re-link the caller-held instance into the rebuilt cache (reload
      // cleared it); a plain get(key) would otherwise decode a SECOND,
      // diverging instance from disk.
      _cache[key] = fabricated;
      _meta[key] = SessionMetadata.fromSession(fabricated);
    }
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
  ///
  /// Invariant: never overwrite persisted history with an empty session.
  /// When [_meta] proves a persisted record exists but the box is unreadable
  /// right now (reload()'s close→reopen window, or the degraded recovery
  /// state), the freshly created session is queued for rehydration: once the
  /// box reopens, [_rehydrateFabricated] merges the on-disk messages back
  /// into this same instance — before any [save] (which awaits the in-flight
  /// reload) can write it out.
  Session getOrCreate(String key) {
    final existing = get(key);
    if (existing != null) return existing;
    final session = Session(key: key);
    _cache[key] = session;
    if (_meta.containsKey(key) && _openBox == null) {
      _awaitingRehydration[key] = session;
    }
    return session;
  }

  /// Get a session by key, returns null if not found.
  /// First access decodes the full message history from Hive and caches it.
  Session? get(String key) {
    final cached = _cache[key];
    if (cached != null) return cached;
    // _openBox guard: during reload()'s close→reopen window (and after a
    // failed reload recovery) the handle is closed — fall back to
    // cache-only, like the pre-lazy behavior.
    final box = _openBox;
    if (box == null) return null;
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
    await _awaitReload();
    _cache[session.key] = session;
    final meta = SessionMetadata.fromSession(session);
    _meta[session.key] = meta;
    await _openBox?.put(session.key, jsonEncode(session.toJson()));
    await _openBox?.put(AppConstants.sessionMetaKeyPrefix + session.key,
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
    await _awaitReload();
    _cache.remove(key);
    _meta.remove(key);
    _awaitingRehydration.remove(key);
    // Sidecar first: a crash in between leaves a session without metadata
    // (healed at next init) rather than a ghost list entry.
    await _openBox?.delete(AppConstants.sessionMetaKeyPrefix + key);
    await _openBox?.delete(key);
    await flush();
  }

  /// Delete every session (cache + Hive) and force sync to disk.
  ///
  /// Throws a [StateError] when the box is unavailable (degraded state):
  /// the in-memory caches are still cleared, but the on-disk records were
  /// NOT deleted — a silent success here would let "erase all data" report
  /// a wipe that never reached the disk. DataWiper records the failure and
  /// falls back to deleting the box files directly.
  Future<void> deleteAllSessions() async {
    await _awaitReload();
    _cache.clear();
    _meta.clear();
    _awaitingRehydration.clear();
    final box = _openBox;
    if (box == null) {
      throw StateError(
          'sessions box unavailable (degraded) — on-disk sessions were not '
          'deleted');
    }
    await box.clear();
    await flush();
  }

  /// Close the underlying Hive box (best-effort). Used by DataWiper before
  /// deleting the box files so a live handle cannot resurrect wiped data.
  /// A degraded/already-closed box is a no-op.
  Future<void> close() async {
    await _awaitReload();
    final box = _box;
    _box = null;
    if (box != null && box.isOpen) {
      await box.close();
    }
  }

  /// Await the in-flight [reload], if any, so a mutating operation never
  /// interleaves with the close→reopen window (where a write would land on
  /// a closed handle, or clobber state the rebuild is about to replace).
  Future<void> _awaitReload() async {
    final pending = _reloading;
    if (pending != null) await pending;
  }

  /// Force sync all pending Hive writes to disk.
  Future<void> flush() async {
    await _awaitReload();
    final box = _openBox;
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
