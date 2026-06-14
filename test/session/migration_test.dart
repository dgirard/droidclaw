// U6: one-shot, idempotent, race-safe Hive → SQLite session migration.
// Pins the migration state machine of the plan: all-or-nothing copy under
// an exclusive-by-first-write transaction, marker re-read inside the
// transaction (loser skips), verification (counts + spot-check) BEFORE the
// marker, backup-rename only after commit, and the DataWiper contract over
// the new file set.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:droidclaw/core/config/config_storage.dart';
import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/services/data_wiper.dart';
import 'package:droidclaw/core/session/database/hive_to_sqlite_migrator.dart';
import 'package:droidclaw/core/session/database/sessions_db.dart';
import 'package:droidclaw/core/session/session.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/core/session/session_metadata.dart';
import 'package:droidclaw/data/local/storage_service.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness hive;
  final openDbs = <SessionsDb>[];
  final openManagers = <SessionManager>[];

  setUp(() async => hive = await HiveTestHarness.create());

  tearDown(() async {
    for (final m in openManagers) {
      try {
        await m.close();
      } catch (_) {}
    }
    openManagers.clear();
    for (final db in openDbs) {
      try {
        await db.close();
      } catch (_) {}
    }
    openDbs.clear();
    await hive.dispose();
  });

  String dbPath() => '${hive.dir.path}/${AppConstants.sessionsDbFilename}';

  SessionsDb openDb() {
    final db = SessionsDb(dbPath());
    openDbs.add(db);
    return db;
  }

  Future<SessionManager> openManager() async {
    final m = SessionManager();
    await m.init(directory: hive.dir.path);
    openManagers.add(m);
    return m;
  }

  /// Seed a legacy Hive box exactly as a pre-U6 build leaves it: session
  /// records, `__meta__:` metadata sidecars, and (optionally) one corrupt
  /// record. Closes every Hive handle so the bytes live only on disk.
  Future<List<Session>> seedHiveBox(int count, {bool corrupt = false}) async {
    final box =
        await Hive.openBox<String>(SessionManager.boxName, path: hive.dir.path);
    final seeded = <Session>[];
    for (var i = 0; i < count; i++) {
      final s = Session(key: 'legacy$i');
      s.addMessage(Message(role: 'user', content: 'question $i'));
      s.addMessage(Message(role: 'assistant', content: 'answer $i'));
      if (i == 0) s.summary = 'old summary';
      await box.put(s.key, jsonEncode(s.toJson()));
      await box.put('${AppConstants.sessionMetaKeyPrefix}${s.key}',
          jsonEncode(SessionMetadata.fromSession(s).toJson()));
      seeded.add(s);
    }
    if (corrupt) {
      await box.put('broken', 'not json {{{');
    }
    await box.flush();
    await Hive.close();
    return seeded;
  }

  group('happy path', () {
    test('seeded Hive box → init() migrates: identical counts/contents, '
        'sidecars and corrupt records skipped, Hive files renamed .backup',
        () async {
      final seeded = await seedHiveBox(3, corrupt: true);
      final hiveFile = File('${hive.dir.path}/sessions.hive');
      expect(hiveFile.existsSync(), isTrue);

      final mgr = await openManager();

      // Counts: 3 sessions (corrupt record skipped, sidecars not counted).
      final meta = mgr.getAllSessionMetadata();
      expect(meta, hasLength(3));
      expect(mgr.sessionDecodeCount, 0,
          reason: 'post-migration startup stays lazy');

      // Contents: full fidelity, decoded on demand.
      for (final original in seeded) {
        final migrated = mgr.get(original.key);
        expect(migrated, isNotNull);
        expect(migrated!.messages.length, original.messages.length);
        expect(migrated.messages.last.content,
            original.messages.last.content);
        expect(migrated.summary, original.summary);
      }
      expect(mgr.get('broken'), isNull);

      // Hive files renamed, marker set.
      expect(hiveFile.existsSync(), isFalse);
      expect(File('${hive.dir.path}/sessions.hive.backup').existsSync(),
          isTrue);
      final db = openDb();
      expect(await db.readAppState(AppConstants.sessionsMigrationMarkerKey),
          AppConstants.sessionsMigrationDone);
    });

    test('fresh install (no Hive box): marker set immediately, no Hive box '
        'created', () async {
      final mgr = await openManager();
      expect(mgr.getAllSessionMetadata(), isEmpty);

      final db = openDb();
      expect(await db.readAppState(AppConstants.sessionsMigrationMarkerKey),
          AppConstants.sessionsMigrationDone);
      expect(File('${hive.dir.path}/sessions.hive').existsSync(), isFalse);
    });

    test('second init() after a completed migration is a no-op (idempotent): '
        'no duplicates, sessions saved post-migration survive', () async {
      await seedHiveBox(2);
      final first = await openManager();
      final extra = first.getOrCreate('post_migration');
      extra.addMessage(const Message(role: 'user', content: 'new world'));
      await first.save(extra);
      await first.close();

      final second = await openManager();
      expect(second.getAllSessionMetadata(), hasLength(3));
      expect(second.get('legacy0'), isNotNull);
      expect(second.get('post_migration')!.messages.single.content,
          'new world');
    });
  });

  group('failure and interruption', () {
    test('kill mid-migration (throw inside the transaction) → rollback, '
        'marker absent; the re-run migrates cleanly with no loss/dupes',
        () async {
      await seedHiveBox(3);
      final db = openDb();

      final interrupted = HiveToSqliteMigrator(
        db: db,
        directory: hive.dir.path,
        beforeVerifyHook: (_) async =>
            throw StateError('simulated kill mid-migration'),
      );
      await expectLater(interrupted.migrate(), throwsStateError);

      // Rolled back: no marker, no rows, Hive untouched.
      expect(await db.readAppState(AppConstants.sessionsMigrationMarkerKey),
          isNull);
      expect(await db.countSessions(), 0);
      expect(File('${hive.dir.path}/sessions.hive').existsSync(), isTrue);

      // Re-run (next startup): clean migration.
      final retry = HiveToSqliteMigrator(db: db, directory: hive.dir.path);
      expect(await retry.migrate(), isTrue);
      expect(await db.countSessions(), 3);
      expect(await db.readAppState(AppConstants.sessionsMigrationMarkerKey),
          AppConstants.sessionsMigrationDone);
      expect(File('${hive.dir.path}/sessions.hive.backup').existsSync(),
          isTrue);
    });

    test('kill between commit and rename → marker==done fast path heals the '
        'orphaned .hive file by renaming it to .backup', () async {
      // Simulate a process kill in the commit→rename window: the marker was
      // committed as `done` but the live .hive file was never renamed.
      await seedHiveBox(2);
      final hiveFile = File('${hive.dir.path}/sessions.hive');
      expect(hiveFile.existsSync(), isTrue);
      final backupFile =
          File('${hive.dir.path}/sessions.hive.backup');
      expect(backupFile.existsSync(), isFalse);

      final db = openDb();
      await db.writeAppState(AppConstants.sessionsMigrationMarkerKey,
          AppConstants.sessionsMigrationDone);

      // Fast path (marker==done): no copy, but the rename heal must run.
      final migrator = HiveToSqliteMigrator(db: db, directory: hive.dir.path);
      expect(await migrator.migrate(), isFalse,
          reason: 'marker already done — no copy performed');

      expect(hiveFile.existsSync(), isFalse,
          reason: 'the orphaned .hive file was renamed');
      expect(backupFile.existsSync(), isTrue,
          reason: 'the heal renamed it to .backup');
    });

    test('failed verification (corrupted row injected pre-verify) → marker '
        'not set, Hive remains the truth (no rename), error surfaced',
        () async {
      await seedHiveBox(3);
      final db = openDb();

      final sabotaged = HiveToSqliteMigrator(
        db: db,
        directory: hive.dir.path,
        beforeVerifyHook: (db) async {
          // Corrupt one migrated payload inside the transaction, before
          // the spot-check runs.
          await db.customStatement(
              "UPDATE sessions SET payload = 'garbage' WHERE "
              "session_key = 'legacy0'");
        },
      );
      await expectLater(sabotaged.migrate(),
          throwsA(isA<SessionMigrationVerificationException>()));

      expect(await db.readAppState(AppConstants.sessionsMigrationMarkerKey),
          isNull);
      expect(await db.countSessions(), 0, reason: 'all-or-nothing rollback');
      expect(File('${hive.dir.path}/sessions.hive').existsSync(), isTrue,
          reason: 'Hive stays the truth when verification fails');
      expect(File('${hive.dir.path}/sessions.hive.backup').existsSync(),
          isFalse);
    });

    test('SessionManager.init() survives a failing migration (error logged, '
        'Hive files untouched for the next attempt)', () async {
      await seedHiveBox(2);
      final hiveFile = File('${hive.dir.path}/sessions.hive');

      // Force a verification failure through the real init() path: a stray
      // pre-existing row makes the post-copy row count exceed the Hive
      // session count.
      final saboteur = openDb();
      await saboteur.customStatement(
          "INSERT INTO sessions (session_key, payload, created, updated, "
          "message_count, conversation_message_count) "
          "VALUES ('stray', '{}', 0, 0, 0, 0)");
      await saboteur.close();
      openDbs.remove(saboteur);

      final mgr = await openManager(); // must not throw
      // Rollback left only the stray row — no half-migrated sessions.
      expect(mgr.getAllSessionMetadata().map((m) => m.key), ['stray']);
      expect(mgr.get('legacy0'), isNull);
      // The Hive file was not renamed nor deleted: still the truth.
      expect(hiveFile.existsSync(), isTrue);
      expect(File('${hive.dir.path}/sessions.hive.backup').existsSync(),
          isFalse);
      final db = openDb();
      expect(await db.readAppState(AppConstants.sessionsMigrationMarkerKey),
          isNull, reason: 'failed migration must not set the marker');
    });
  });

  group('race between isolates', () {
    test('two concurrent migrators on the same file: exactly one copies, '
        'the loser sees done; no duplicates', () async {
      await seedHiveBox(4);
      final db1 = openDb();
      final db2 = openDb();
      // Settle both schemas sequentially (the schema-creation race is not
      // what this test pins — in production the two engines never open in
      // the same millisecond).
      await db1.customSelect('SELECT 1').get();
      await db2.customSelect('SELECT 1').get();

      final m1 = HiveToSqliteMigrator(db: db1, directory: hive.dir.path);
      final m2 = HiveToSqliteMigrator(db: db2, directory: hive.dir.path);

      final results = await Future.wait([m1.migrate(), m2.migrate()]);

      expect(results.where((didCopy) => didCopy), hasLength(1),
          reason: 'exactly one migrator performs the copy');
      expect(await db1.countSessions(), 4);
      expect(await db2.readAppState(AppConstants.sessionsMigrationMarkerKey),
          AppConstants.sessionsMigrationDone);
      expect(File('${hive.dir.path}/sessions.hive.backup').existsSync(),
          isTrue);
    });

    test('cross-isolate write visibility after migration: a session written '
        'through a second manager is readable by the first without reload',
        () async {
      await seedHiveBox(1);
      final first = await openManager();
      final second = await openManager();

      final s = second.getOrCreate('from_service');
      s.addMessage(const Message(role: 'assistant', content: 'cron result'));
      await second.save(s);

      expect(first.get('from_service')!.messages.single.content,
          'cron result');
    });
  });

  group('DataWiper over the migrated store', () {
    test('deletes the sessions.db file set AND the Hive backups', () async {
      await seedHiveBox(2);
      final mgr = await openManager(); // migrates, renames to .backup

      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final storage = StorageService(prefs: sp);
      final wiper = DataWiper(
        storage: storage,
        configStorage: ConfigStorage(storage),
        sessions: mgr,
        sessionsDbPath: dbPath(),
      );

      final failures = await wiper.wipeAll();

      expect(failures.where((f) => f.startsWith('sessions')), isEmpty);
      expect(mgr.getAllSessionMetadata(), isEmpty);
      expect(File(dbPath()).existsSync(), isFalse);
      expect(File('${dbPath()}-wal').existsSync(), isFalse);
      expect(File('${dbPath()}-shm').existsSync(), isFalse);
      expect(File('${hive.dir.path}/sessions.hive').existsSync(), isFalse);
      expect(File('${hive.dir.path}/sessions.hive.backup').existsSync(),
          isFalse,
          reason: 'erase-all-data must not leave conversations recoverable '
              'in the Hive backups');
    });
  });
}
