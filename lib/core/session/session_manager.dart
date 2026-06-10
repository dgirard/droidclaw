import 'dart:convert';

import 'package:hive/hive.dart';

import '../../shared/constants.dart';
import '../services/app_logger.dart';
import '../config/log_entry.dart';
import 'session.dart';

/// Manages conversation sessions with Hive persistence and in-memory cache.
class SessionManager {
  static const String _boxName = 'sessions';
  final Map<String, Session> _cache = {};
  Box<String>? _box;

  /// Initialize the session manager and open Hive box.
  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);

    // Compact on startup to reclaim space from deleted entries.
    // Wrapped in try-catch: compact() is unsafe if another isolate runs it
    // concurrently (Hive advisory locks are per-process, not per-isolate).
    try {
      await _box!.compact();
    } catch (e) {
      AppLogger.instance.warning(
        LogSource.app,
        'Hive compact failed: ${e.runtimeType}',
      );
    }

    // Load all sessions into cache
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _cache[key as String] = Session.fromJson(json);
        } catch (e) {
          AppLogger.instance.warning(
            LogSource.app,
            'Corrupted session skipped: $key — ${e.runtimeType}',
          );
        }
      }
    }
  }

  /// Reload sessions from Hive to pick up writes from other isolates.
  /// Closes and reopens the Hive box to force a disk re-read.
  Future<void> reload() async {
    final boxName = _box?.name;
    if (boxName == null) return;
    await _box!.close();
    _box = await Hive.openBox<String>(boxName);
    _cache.clear();
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _cache[key as String] = Session.fromJson(json);
        } catch (e) {
          AppLogger.instance.warning(
            LogSource.app,
            'Corrupted session skipped on reload: $key — ${e.runtimeType}',
          );
        }
      }
    }
  }

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
