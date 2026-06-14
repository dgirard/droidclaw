// Tests for the dual-isolate persistence behavior of the SQLite-backed
// SessionManager (U6): cross-isolate visibility through two independent
// connections on the same WAL file, path resolution, and the
// read-after-cross-isolate-write scenario that on Hive could only be caught
// in the field.
//
// Conscious retirements from the Hive era (R14):
// - "not visible before reload()": a committed cross-isolate write is now
//   visible to a plain get() IMMEDIATELY (WAL) — the very bug class the
//   migration removes. reload() only refreshes the metadata index.
// - reentrant reload() future identity: reload() is a synchronous metadata
//   refresh with no close→reopen window, so there is no in-flight cycle to
//   join. The port keeps the no-throw/consistency assertions.
// - the rehydration merge during reload: a sync row-existence check makes
//   fabrication-over-persisted impossible by construction; the race test
//   below still pins the user-visible invariant (never an empty session,
//   never overwritten history).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/database/sessions_db_path.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/session_db_test_harness.dart';

void main() {
  group('Cross-isolate visibility (read-after-cross-isolate-write)', () {
    late SessionDbTestHarness store;

    setUp(() async => store = await SessionDbTestHarness.create());
    tearDown(() => store.dispose());

    test(
        'a session written through a second manager on the same database '
        'file is visible to the first — get() immediately, list screens '
        'after the reload() index refresh', () async {
      // "Main isolate" manager: opens its connections, writes its own
      // session.
      final main = await store.manager();
      final chat = main.getOrCreate('chat');
      chat.addMessage(const Message(role: 'user', content: 'hello'));
      await main.save(chat);

      // "Service isolate" manager: an INDEPENDENT manager with its own
      // connections on the same file — exactly the production topology
      // (two FlutterEngines, two WAL connections).
      final service = await store.manager();
      final cron = service.getOrCreate('cron_daily');
      cron.addMessage(
          const Message(role: 'assistant', content: 'cron output'));
      await service.save(cron); // committed — the persist-then-notify step

      // The committed row is readable WITHOUT any reload protocol (the
      // Hive-era "invisible until reload" failure mode is gone)...
      final visible = main.get('cron_daily');
      expect(visible, isNotNull,
          reason: 'cross-isolate write must be visible to a plain get()');
      expect(visible!.messages.single.content, 'cron output');

      // ...and the metadata index picks it up after the reload() refresh
      // ('cron_completed' arrives → main isolate reload()s).
      await main.reload();
      expect(main.getAllSessionMetadata().map((m) => m.key),
          contains('cron_daily'));
      // And the main isolate's own session survived the reload.
      expect(main.get('chat')!.messages.single.content, 'hello');
    });

    test('reload() drops sessions deleted by the other isolate', () async {
      final main = await store.manager();
      final s = main.getOrCreate('doomed');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await main.save(s);

      final service = await store.manager();
      await service.deleteSession('doomed');

      await main.reload();
      expect(main.get('doomed'), isNull);
    });

    test('a closed manager (degraded/wiped state) never throws: '
        'save/flush/delete fall back to cache-only', () async {
      // DataWiper closes the connections before deleting the files; any
      // straggler turn must degrade to cache-only instead of throwing
      // mid-turn (the guard contract carried over from the Hive era).
      final mgr = await store.manager();
      final s = mgr.getOrCreate('survivor');
      s.addMessage(const Message(role: 'user', content: 'keep me'));
      await mgr.save(s);

      await mgr.close(); // the manager's connections are now closed

      s.addMessage(const Message(role: 'assistant', content: 'mid-turn'));
      await mgr.save(s); // must not throw
      await mgr.flush(); // must not throw
      await mgr.deleteSession('other'); // must not throw
      await mgr.reload(); // must not throw
      // Cache-only reads still serve the session.
      expect(mgr.get('survivor')!.messages, hasLength(2));
    });

    test('a corrupted row is skipped on init and reload without losing '
        'the healthy ones', () async {
      // Write one healthy session through a manager, then inject a garbage
      // payload straight into the database, as a crashed/foreign writer
      // would leave it.
      final seeder = await store.manager();
      final good = seeder.getOrCreate('good');
      good.addMessage(const Message(role: 'user', content: 'fine'));
      await seeder.save(good);
      await seeder.close();

      final raw = sqlite.sqlite3
          .open('${store.dir.path}/${AppConstants.sessionsDbFilename}');
      raw.execute(
        'INSERT INTO sessions (session_key, payload, created, updated, '
        'message_count, conversation_message_count) '
        "VALUES ('bad', 'not json {{{', 0, 0, 1, 1)",
      );
      raw.dispose();

      final mgr = await store.manager();
      expect(mgr.get('good'), isNotNull);
      expect(mgr.get('bad'), isNull);

      await mgr.reload();
      expect(mgr.get('good'), isNotNull);
      expect(mgr.get('bad'), isNull);
    });
  });

  group('reload() against concurrent access', () {
    late SessionDbTestHarness store;

    setUp(() async => store = await SessionDbTestHarness.create());
    tearDown(() => store.dispose());

    test(
        'concurrent reload()+getOrCreate on an existing key never yields an '
        'empty session and never overwrites persisted history', () async {
      // Persist a session through a throwaway manager so the manager under
      // test starts cold (metadata index only — the session is NOT in its
      // cache).
      final writer = await store.manager();
      final orig = writer.getOrCreate('cron_daily');
      orig.addMessage(
          const Message(role: 'assistant', content: 'cron output'));
      await writer.save(orig);
      await writer.close();

      final mgr = await store.manager();

      // Start a reload and race getOrCreate against it — exactly how
      // _reloadAfterCronCompletion races an incoming chat/Telegram message
      // in the main isolate.
      final reloading = mgr.reload();
      final session = mgr.getOrCreate('cron_daily');
      session.addMessage(
          const Message(role: 'user', content: 'mid-reload message'));
      await mgr.save(session);
      await reloading;

      // The caller-held instance is the decoded persisted session (the sync
      // row check makes an empty fabricated session impossible) ...
      expect(session.messages.first.content, 'cron output');
      expect(session.messages.last.content, 'mid-reload message');
      // ... and the manager serves that SAME instance afterwards.
      expect(identical(mgr.get('cron_daily'), session), isTrue);

      // The persisted record was never overwritten by an empty session: a
      // cold re-read sees the full merged history.
      final verify = await store.manager();
      final persisted = verify.get('cron_daily');
      expect(persisted, isNotNull);
      expect(
        persisted!.messages.map((m) => m.content),
        containsAllInOrder(['cron output', 'mid-reload message']),
      );
    });

    test('reentrant/back-to-back reload() does not throw and keeps state '
        'consistent', () async {
      final mgr = await store.manager();
      final s = mgr.getOrCreate('k');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);

      final f1 = mgr.reload();
      final f2 = mgr.reload();
      await f1;
      await f2;
      await mgr.reload();
      expect(mgr.get('k'), isNotNull);
      expect(mgr.get('k')!.messages.single.content, 'x');
    });
  });

  group('SessionManager + SessionsDbPath (service-isolate init path)', () {
    late Directory appDir;
    late SessionManager mgr;

    setUp(() async {
      appDir = await Directory.systemTemp.createTemp('sessions_path_test_');
    });

    tearDown(() async {
      await mgr.close();
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
      }
    });

    test('init(workspacePath:) opens sessions.db in the workspace PARENT — '
        'the app documents directory the main isolate resolves', () async {
      final workspace = Directory('${appDir.path}/droidclaw_workspace');
      await workspace.create();

      mgr = SessionManager();
      await mgr.init(workspacePath: workspace.path);
      final s = mgr.getOrCreate('s');
      s.addMessage(const Message(role: 'user', content: 'hi'));
      await mgr.save(s);

      // The database file must land in the resolved parent dir, NOT inside
      // the workspace (the double-nesting that desynced the isolates in the
      // Hive era).
      expect(SessionsDbPath.dirFromWorkspace(workspace.path), appDir.path);
      expect(SessionsDbPath.fileFromWorkspace(workspace.path),
          '${appDir.path}/${AppConstants.sessionsDbFilename}');
      expect(
          File('${appDir.path}/${AppConstants.sessionsDbFilename}')
              .existsSync(),
          isTrue);
      expect(
          File('${workspace.path}/${AppConstants.sessionsDbFilename}')
              .existsSync(),
          isFalse);
    });
  });
}
