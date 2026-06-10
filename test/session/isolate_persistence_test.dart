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
