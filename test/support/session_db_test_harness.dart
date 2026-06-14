import 'dart:io';

import 'package:droidclaw/core/session/session_manager.dart';

/// Provides a fresh temp directory for `sessions.db` so tests can exercise
/// the real SQLite-backed [SessionManager] without a device (successor of
/// [HiveTestHarness] for the session store; the Hive harness remains for
/// seeding migration sources).
///
/// Managers created through [manager] are tracked and closed on [dispose] —
/// an unclosed SessionsDb leaks its background database isolate.
///
/// ```dart
/// late SessionDbTestHarness store;
/// setUp(() async => store = await SessionDbTestHarness.create());
/// tearDown(() => store.dispose());
/// ```
class SessionDbTestHarness {
  final Directory dir;
  final List<SessionManager> _managers = [];

  SessionDbTestHarness._(this.dir);

  static Future<SessionDbTestHarness> create() async {
    final dir = await Directory.systemTemp.createTemp('sessions_db_test_');
    return SessionDbTestHarness._(dir);
  }

  /// A new, initialized [SessionManager] on this harness's directory.
  /// Multiple managers on the same harness model the two FlutterEngines:
  /// each holds its own independent connections on the same WAL file.
  Future<SessionManager> manager() async {
    final m = SessionManager();
    await m.init(directory: dir.path);
    _managers.add(m);
    return m;
  }

  /// Track an externally created manager so [dispose] closes it.
  void track(SessionManager m) => _managers.add(m);

  Future<void> dispose() async {
    for (final m in _managers) {
      try {
        await m.close();
      } catch (_) {
        // already closed by the test — fine
      }
    }
    _managers.clear();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
