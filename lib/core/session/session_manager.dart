import 'dart:convert';

import 'package:hive/hive.dart';

import '../../shared/constants.dart';
import 'session.dart';

/// Manages conversation sessions with Hive persistence and in-memory cache.
class SessionManager {
  static const String _boxName = 'sessions';
  final Map<String, Session> _cache = {};
  Box<String>? _box;

  /// Initialize the session manager and open Hive box.
  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);

    // Load all sessions into cache
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _cache[key as String] = Session.fromJson(json);
        } catch (_) {
          // Skip corrupted entries
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
        } catch (_) {}
      }
    }
  }

  /// Get or create a session by key.
  Session getOrCreate(String key) {
    return _cache.putIfAbsent(key, () => Session(key: key));
  }

  /// Get a session by key, returns null if not found.
  Session? get(String key) => _cache[key];

  /// Save a session to Hive.
  Future<void> save(Session session) async {
    _cache[session.key] = session;
    await _box?.put(session.key, jsonEncode(session.toJson()));
  }

  /// Get all sessions, sorted by last updated.
  List<Session> getAllSessions() {
    final sessions = _cache.values.toList();
    sessions.sort((a, b) => b.updated.compareTo(a.updated));
    return sessions;
  }

  /// Delete a session.
  Future<void> deleteSession(String key) async {
    _cache.remove(key);
    await _box?.delete(key);
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
