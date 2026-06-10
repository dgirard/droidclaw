import 'dart:convert';

import 'package:hive/hive.dart';

import '../../shared/constants.dart';
import '../services/app_logger.dart';
import '../config/log_entry.dart';
import 'isolate_persistence/cache_reload.dart';
import 'isolate_persistence/hive_path_resolver.dart';
import 'session.dart';

/// Manages conversation sessions with Hive persistence and in-memory cache.
///
/// Dual-isolate aware: persistence mechanics (path resolution, cache reload,
/// write-then-notify ordering) live in `isolate_persistence/`. Note the
/// cross-isolate compaction constraint documented in [CacheReload] — do not
/// add `compact()` calls here.
class SessionManager {
  static const String _boxName = 'sessions';
  final Map<String, Session> _cache = {};
  Box<String>? _box;

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

    // Load all sessions into cache
    CacheReload.populate<Session>(
      box: _box!,
      cache: _cache,
      decode: _decodeSession,
      onCorrupt: (key, e) => AppLogger.instance.warning(
        LogSource.app,
        'Corrupted session skipped: $key — ${e.runtimeType}',
      ),
    );
  }

  /// Reload sessions from Hive to pick up writes from other isolates.
  /// Closes and reopens the Hive box to force a disk re-read.
  Future<void> reload() async {
    final box = _box;
    if (box == null) return;
    _box = await CacheReload.reload<Session>(
      box: box,
      cache: _cache,
      decode: _decodeSession,
      onCorrupt: (key, e) => AppLogger.instance.warning(
        LogSource.app,
        'Corrupted session skipped on reload: $key — ${e.runtimeType}',
      ),
    );
  }

  static Session _decodeSession(String raw) =>
      Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Get or create a session by key.
  Session getOrCreate(String key) {
    return _cache.putIfAbsent(key, () => Session(key: key));
  }

  /// Get a session by key, returns null if not found.
  Session? get(String key) => _cache[key];

  /// Save a session to Hive and force sync to disk.
  Future<void> save(Session session) async {
    _cache[session.key] = session;
    await _box?.put(session.key, jsonEncode(session.toJson()));
    await _box?.flush();
  }

  /// Get all sessions, sorted by last updated.
  List<Session> getAllSessions() {
    final sessions = _cache.values.toList();
    sessions.sort((a, b) => b.updated.compareTo(a.updated));
    return sessions;
  }

  /// Delete a session and force sync to disk.
  Future<void> deleteSession(String key) async {
    _cache.remove(key);
    await _box?.delete(key);
    await _box?.flush();
  }

  /// Delete every session (cache + Hive) and force sync to disk.
  Future<void> deleteAllSessions() async {
    _cache.clear();
    await _box?.clear();
    await _box?.flush();
  }

  /// Force sync all pending Hive writes to disk.
  Future<void> flush() async {
    await _box?.flush();
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
