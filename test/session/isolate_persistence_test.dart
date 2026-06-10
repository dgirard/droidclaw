// Tests for the dual-isolate persistence subsystem
// (lib/core/session/isolate_persistence/): the cache-reload visibility
// protocol, Hive path resolution, and — most importantly — the cross-isolate
// read-after-write scenario that until now could only be caught in the field.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/isolate_persistence/hive_path_resolver.dart';
import 'package:droidclaw/core/session/session.dart';
import 'package:droidclaw/core/session/session_manager.dart';

import '../support/hive_test_harness.dart';

void main() {
  group('Cross-isolate visibility (read-after-cross-isolate-write)', () {
    late HiveTestHarness hive;

    setUp(() async => hive = await HiveTestHarness.create());
    tearDown(() => hive.dispose());

    test(
        'a session written through a second manager on the same resolved '
        'path becomes visible after reload()', () async {
      // "Main isolate" manager: opens the box, writes its own session.
      final main = SessionManager();
      await main.init();
      final chat = main.getOrCreate('chat');
      chat.addMessage(const Message(role: 'user', content: 'hello'));
      await main.save(chat);

      // Simulate the service isolate. Hive is a per-process singleton, so a
      // truly independent second Hive context cannot run in one test process.
      // Established proxy: close every open handle (each isolate owns its own
      // handles in production), then write through a SECOND independent
      // SessionManager against the SAME path and close again. The cron
      // session can then only travel through the box FILE on disk — exactly
      // the cross-isolate channel.
      await Hive.close();
      final service = SessionManager();
      await service.init();
      final cron = service.getOrCreate('cron_daily');
      cron.addMessage(
          const Message(role: 'assistant', content: 'cron output'));
      await service.save(cron); // save() flushes — the persist-then-notify step
      await Hive.close(); // bytes now exist ONLY on disk

      // Before reload, the main manager's cache must not magically know
      // about the cron session (it was written by "another isolate").
      expect(main.get('cron_daily'), isNull);

      // 'cron_completed' arrives → main isolate reload()s.
      await main.reload();

      final visible = main.get('cron_daily');
      expect(visible, isNotNull,
          reason: 'cross-isolate write not visible after reload()');
      expect(visible!.messages.single.content, 'cron output');
      // And the main isolate's own session survived the reload.
      expect(main.get('chat')!.messages.single.content, 'hello');
    });

    test('reload() drops sessions deleted by the other isolate', () async {
      final main = SessionManager();
      await main.init();
      final s = main.getOrCreate('doomed');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await main.save(s);

      await Hive.close();
      final service = SessionManager();
      await service.init();
      await service.deleteSession('doomed');
      await Hive.close();

      await main.reload();
      expect(main.get('doomed'), isNull);
    });

    test('a closed box (degraded reload-recovery state) never throws: '
        'save/flush/delete fall back to cache-only', () async {
      // A failed CacheReload.reload can leave _box pointing at a closed
      // handle (an openBox failure itself cannot be injected through the
      // Hive singleton, so the degraded END STATE is simulated by closing
      // the handle out from under the manager). The guards must turn every
      // persistence call into a cache-only no-op instead of a HiveError
      // mid-turn.
      final mgr = SessionManager();
      await mgr.init();
      final s = mgr.getOrCreate('survivor');
      s.addMessage(const Message(role: 'user', content: 'keep me'));
      await mgr.save(s);

      await Hive.close(); // the manager's handle is now closed

      s.addMessage(const Message(role: 'assistant', content: 'mid-turn'));
      await mgr.save(s); // must not throw
      await mgr.flush(); // must not throw
      await mgr.deleteSession('other'); // must not throw
      // Cache-only reads still serve the session.
      expect(mgr.get('survivor')!.messages, hasLength(2));
    });

    test('a corrupted record is skipped on init and reload without losing '
        'the healthy ones', () async {
      // Write one healthy session and one garbage record straight into the
      // box file, as a crashed/foreign writer would leave it.
      final raw = await Hive.openBox<String>('sessions');
      await raw.put('good', jsonEncode(Session(key: 'good').toJson()));
      await raw.put('bad', 'not json {{{');
      await raw.flush();
      await Hive.close();

      final mgr = SessionManager();
      await mgr.init();
      expect(mgr.get('good'), isNotNull);
      expect(mgr.get('bad'), isNull);

      await mgr.reload();
      expect(mgr.get('good'), isNotNull);
      expect(mgr.get('bad'), isNull);
    });
  });

  group('reload() serialization against concurrent access', () {
    late HiveTestHarness hive;

    setUp(() async => hive = await HiveTestHarness.create());
    tearDown(() => hive.dispose());

    test(
        'concurrent reload()+getOrCreate on an existing key never yields an '
        'empty session and never overwrites persisted history', () async {
      // Persist a session through a throwaway manager, then drop all handles
      // so the manager under test starts cold (metadata index only — the
      // session is NOT in its cache).
      final writer = SessionManager();
      await writer.init();
      final orig = writer.getOrCreate('cron_daily');
      orig.addMessage(
          const Message(role: 'assistant', content: 'cron output'));
      await writer.save(orig);
      await Hive.close();

      final mgr = SessionManager();
      await mgr.init();

      // Start a reload (close→reopen window) and race getOrCreate against
      // it — exactly how _reloadAfterCronCompletion races an incoming
      // chat/Telegram message in the main isolate.
      final reloading = mgr.reload();
      final session = mgr.getOrCreate('cron_daily');
      session.addMessage(
          const Message(role: 'user', content: 'mid-reload message'));
      await mgr.save(session); // save() awaits the in-flight reload
      await reloading;

      // The caller-held instance absorbed the persisted history (it must
      // not be an empty fabricated session) ...
      expect(session.messages.first.content, 'cron output');
      expect(session.messages.last.content, 'mid-reload message');
      // ... and the manager serves that SAME instance afterwards.
      expect(identical(mgr.get('cron_daily'), session), isTrue);

      // The persisted record was never overwritten by an empty session: a
      // cold re-read from disk sees the full merged history.
      await Hive.close();
      final verify = SessionManager();
      await verify.init();
      final persisted = verify.get('cron_daily');
      expect(persisted, isNotNull);
      expect(
        persisted!.messages.map((m) => m.content),
        containsAllInOrder(['cron output', 'mid-reload message']),
      );
    });

    test('reentrant reload() returns the in-flight future and does not '
        'throw', () async {
      final mgr = SessionManager();
      await mgr.init();
      final s = mgr.getOrCreate('k');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);

      final f1 = mgr.reload();
      final f2 = mgr.reload();
      expect(identical(f1, f2), isTrue,
          reason: 'reentrant reload must join the in-flight cycle, not '
              'start a second close→reopen on the same handle');
      await f1;
      await f2;

      // After completion a NEW reload starts a fresh cycle.
      final f3 = mgr.reload();
      expect(identical(f3, f1), isFalse);
      await f3;
      expect(mgr.get('k'), isNotNull);
    });
  });

  group('SessionManager + HivePathResolver (service-isolate init path)', () {
    late Directory appDir;

    setUp(() async {
      appDir = await Directory.systemTemp.createTemp('hive_path_test_');
    });

    tearDown(() async {
      await Hive.close();
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
      }
    });

    test('init(workspacePath:) opens the box in the workspace PARENT — the '
        'directory Hive.initFlutter() uses in the main isolate', () async {
      final workspace = Directory('${appDir.path}/droidclaw_workspace');
      await workspace.create();

      final mgr = SessionManager();
      await mgr.init(workspacePath: workspace.path);
      final s = mgr.getOrCreate('s');
      s.addMessage(const Message(role: 'user', content: 'hi'));
      await mgr.save(s);

      // The box file must land in the resolved parent dir, NOT inside the
      // workspace (the double-nesting that desynced the isolates).
      expect(HivePathResolver.hiveDirFromWorkspace(workspace.path),
          appDir.path);
      expect(File('${appDir.path}/sessions.hive').existsSync(), isTrue);
      expect(File('${workspace.path}/sessions.hive').existsSync(), isFalse);
    });
  });
}
