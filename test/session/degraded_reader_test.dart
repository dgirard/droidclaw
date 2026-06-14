// R1: a failure to open the read-only SyncSessionReader during init() must
// degrade SessionManager to cache-only mode rather than permanently erroring
// the sessionManagerProvider FutureProvider.
//
// Injection: place a *directory* at the sessions.db path. Both the Drift
// writer (inside the migrator, already try/caught) and the sync reader fail
// to open it. init() must complete without throwing, and the read accessors
// must answer safely from the in-memory cache.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/shared/constants.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sessions_db_degraded_');
    // Make the sessions.db path un-openable: a directory cannot be opened as
    // a SQLite database file.
    await Directory(p.join(dir.path, AppConstants.sessionsDbFilename))
        .create(recursive: true);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('init survives an unopenable reader and degrades to cache-only',
      () async {
    final manager = SessionManager();

    // Must not throw — the whole point of R1.
    await manager.init(directory: dir.path);

    // Read accessors answer safely (cache-only) instead of throwing.
    expect(manager.get('does-not-exist'), isNull);
    expect(manager.getAllSessionMetadata(), isEmpty);

    // A fabricated session lives in the cache and is visible to reads even
    // though the database is degraded.
    final created = manager.getOrCreate('s1');
    expect(created.key, 's1');
    expect(manager.get('s1'), same(created));
    expect(manager.getAllSessionMetadata().map((m) => m.key), contains('s1'));

    await manager.close();
  });
}
