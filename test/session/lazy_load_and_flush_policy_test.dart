// U13 tests: lazy session loading (metadata index, no eager full-history
// decode) and the tiered flush cadence.
//
// HONESTY NOTE on the durability assertions: a true SIGKILL-without-flush
// crash cannot be simulated faithfully in-process — Hive's close() (used by
// reload() and by the test harness) flushes pending writes itself, so any
// close/reopen "survival" test would pass even for never-fsynced writes.
// These tests therefore pin the flush POLICY (which operations issue
// box.flush) via the instrumented SessionManager.flushCount, alongside the
// existing characterization tests that pin write-visibility through a real
// disk re-read. The safety argument for unflushed mid-turn saves (awaited
// put → completed write syscall → OS page cache survives process kill) is
// documented on SessionManager.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session.dart';
import 'package:droidclaw/core/session/session_manager.dart';
import 'package:droidclaw/core/session/session_metadata.dart';
import 'package:droidclaw/shared/constants.dart';

import '../support/hive_test_harness.dart';

void main() {
  late HiveTestHarness hive;

  setUp(() async => hive = await HiveTestHarness.create());
  tearDown(() => hive.dispose());

  /// Seed N sessions (with metadata sidecars) through a throwaway manager,
  /// then close all handles so the next manager starts cold from disk.
  Future<void> seedSessions(int count) async {
    final seeder = SessionManager();
    await seeder.init();
    for (var i = 0; i < count; i++) {
      final s = seeder.getOrCreate('s$i');
      s.addMessage(Message(role: 'user', content: 'question $i'));
      s.addMessage(Message(role: 'assistant', content: 'answer $i'));
      await seeder.save(s);
    }
    await Hive.close();
  }

  group('Lazy load', () {
    test('init does not decode any full session when metadata exists',
        () async {
      await seedSessions(5);

      final mgr = SessionManager();
      await mgr.init();
      expect(mgr.sessionDecodeCount, 0,
          reason: 'startup must not deserialize full histories');

      // The metadata index is still complete and correctly ordered.
      final meta = mgr.getAllSessionMetadata();
      expect(meta, hasLength(5));
      expect(mgr.sessionDecodeCount, 0,
          reason: 'listing sessions must not decode histories either');
    });

    test('a session is decoded once, on first access only', () async {
      await seedSessions(3);

      final mgr = SessionManager();
      await mgr.init();

      final s = mgr.get('s1');
      expect(s, isNotNull);
      expect(s!.messages.first.content, 'question 1');
      expect(mgr.sessionDecodeCount, 1);

      // Cached: second access does not decode again.
      expect(identical(mgr.get('s1'), s), isTrue);
      expect(mgr.sessionDecodeCount, 1);
    });

    test('legacy box without metadata sidecars: init decodes once, heals, '
        'and the next startup is lazy', () async {
      // Write raw legacy records (no sidecars), as a pre-U13 build would.
      final raw = await Hive.openBox<String>('sessions');
      for (var i = 0; i < 3; i++) {
        final s = Session(key: 'legacy$i');
        s.addMessage(Message(role: 'user', content: 'old $i'));
        await raw.put('legacy$i', jsonEncode(s.toJson()));
      }
      await raw.flush();
      await Hive.close();

      final first = SessionManager();
      await first.init();
      expect(first.sessionDecodeCount, 3,
          reason: 'migration startup decodes legacy records once');
      expect(first.getAllSessionMetadata(), hasLength(3));
      await Hive.close();

      final second = SessionManager();
      await second.init();
      expect(second.sessionDecodeCount, 0,
          reason: 'healed sidecars make the next startup fully lazy');
      expect(second.getAllSessionMetadata(), hasLength(3));
    });

    test('metadata carries what the History screen renders', () async {
      final mgr = SessionManager();
      await mgr.init();
      final s = mgr.getOrCreate('m');
      s.addMessage(const Message(role: 'user', content: 'first\nquestion'));
      s.addMessage(Message(
        role: 'assistant',
        content: '',
        toolCalls: const [ToolCall(id: 't1', name: 'echo', arguments: {})],
      ));
      s.addMessage(const Message(
          role: 'tool', content: 'r', toolCallId: 't1', name: 'echo'));
      s.addMessage(const Message(role: 'assistant', content: 'done'));
      s.summary = 'a summary';
      await mgr.save(s);
      await Hive.close();

      final cold = SessionManager();
      await cold.init();
      final meta = cold.getAllSessionMetadata().single;
      expect(cold.sessionDecodeCount, 0);
      expect(meta.key, 'm');
      expect(meta.messageCount, 4);
      expect(meta.conversationMessageCount, 3); // user + 2 assistant
      expect(meta.preview, 'first question'); // normalized newline
      expect(meta.summaryPreview, 'a summary');
    });

    test('unsaved in-memory sessions still appear in the metadata list',
        () async {
      final mgr = SessionManager();
      await mgr.init();
      final fresh = mgr.createNew(key: 'unsaved');
      fresh.addMessage(const Message(role: 'user', content: 'hello'));

      final meta = mgr.getAllSessionMetadata();
      expect(meta.map((m) => m.key), contains('unsaved'));
      expect(meta.firstWhere((m) => m.key == 'unsaved').preview, 'hello');
    });

    test('a corrupted metadata sidecar falls back to the session record',
        () async {
      await seedSessions(1);
      final raw = await Hive.openBox<String>('sessions');
      await raw.put('${AppConstants.sessionMetaKeyPrefix}s0', 'not json {{{');
      await raw.flush();
      await Hive.close();

      final mgr = SessionManager();
      await mgr.init();
      expect(mgr.sessionDecodeCount, 1, reason: 'fallback full decode');
      final meta = mgr.getAllSessionMetadata().single;
      expect(meta.key, 's0');
      expect(meta.preview, 'question 0');
    });

    test('an orphaned metadata sidecar (session record gone) is never '
        'listed as a ghost', () async {
      final raw = await Hive.openBox<String>('sessions');
      final ghost = SessionMetadata(
        key: 'ghost',
        created: DateTime.now(),
        updated: DateTime.now(),
        messageCount: 1,
        conversationMessageCount: 1,
      );
      await raw.put('${AppConstants.sessionMetaKeyPrefix}ghost',
          jsonEncode(ghost.toJson()));
      await raw.flush();
      await Hive.close();

      final mgr = SessionManager();
      await mgr.init();
      expect(mgr.getAllSessionMetadata(), isEmpty);
      expect(mgr.get('ghost'), isNull);
    });

    test('cross-isolate write: reload() picks up new metadata without '
        'decoding any history', () async {
      final main = SessionManager();
      await main.init();
      final chat = main.getOrCreate('chat');
      chat.addMessage(const Message(role: 'user', content: 'hello'));
      await main.save(chat);

      // Same proxy as isolate_persistence_test: route the second write
      // through the box FILE on disk.
      await Hive.close();
      final service = SessionManager();
      await service.init();
      final cron = service.getOrCreate('cron_daily');
      cron.addMessage(
          const Message(role: 'assistant', content: 'cron output'));
      await service.save(cron);
      await Hive.close();

      main.sessionDecodeCount = 0;
      await main.reload();
      expect(
          main.getAllSessionMetadata().map((m) => m.key), contains('cron_daily'));
      expect(main.sessionDecodeCount, 0,
          reason: 'reload rebuilds the index from sidecars, not histories');

      // Full content is there on demand.
      expect(main.get('cron_daily')!.messages.single.content, 'cron output');
      expect(main.sessionDecodeCount, 1);
    });
  });

  group('Flush policy (fsync cadence)', () {
    test('save() fsyncs by default; save(flush: false) does not', () async {
      final mgr = SessionManager();
      await mgr.init();
      final baseline = mgr.flushCount;

      final s = mgr.getOrCreate('p');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);
      expect(mgr.flushCount, baseline + 1);

      s.addMessage(const Message(role: 'assistant', content: 'y'));
      await mgr.save(s, flush: false);
      expect(mgr.flushCount, baseline + 1,
          reason: 'intermediate saves must not fsync');

      // The unflushed write still reached Hive's file layer: visible after
      // a disk re-read. (Caveat: close() itself flushes — this proves the
      // write happened, not fsync timing; fsync timing is pinned above.)
      await mgr.reload();
      expect(mgr.get('p')!.messages, hasLength(2));
    });

    test('deleteSession and deleteAllSessions fsync', () async {
      final mgr = SessionManager();
      await mgr.init();
      final s = mgr.getOrCreate('d');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);

      final baseline = mgr.flushCount;
      await mgr.deleteSession('d');
      expect(mgr.flushCount, baseline + 1);

      await mgr.deleteAllSessions();
      expect(mgr.flushCount, baseline + 2);
    });

    test('flush() issues exactly one fsync — the app-pause lifecycle hook '
        'in app.dart relies on this contract', () async {
      final mgr = SessionManager();
      await mgr.init();
      final baseline = mgr.flushCount;

      await mgr.flush();
      expect(mgr.flushCount, baseline + 1);
    });

    test('init/reload metadata healing never fsyncs', () async {
      // Legacy box → init writes sidecars back, but without flush: metadata
      // is derivable, losing it only costs one decode at next startup.
      final raw = await Hive.openBox<String>('sessions');
      await raw.put('legacy', jsonEncode(Session(key: 'legacy').toJson()));
      await raw.flush();
      await Hive.close();

      final mgr = SessionManager();
      await mgr.init();
      expect(mgr.flushCount, 0);
      await mgr.reload();
      expect(mgr.flushCount, 0);
    });
  });

  group('truncateHistory all-tool-calls edge case (todos/006)', () {
    test('a history that is ALL tool calls/results still truncates',
        () {
      final s = Session(key: 'tools-only');
      for (var i = 0; i < 10; i++) {
        s.addMessage(Message(
          role: 'assistant',
          content: '',
          toolCalls: [ToolCall(id: 't$i', name: 'echo', arguments: const {})],
        ));
        s.addMessage(Message(
            role: 'tool', content: 'r$i', toolCallId: 't$i', name: 'echo'));
      }

      final removed = s.truncateHistory(4);

      expect(removed, isNotEmpty,
          reason: 'the guard loop must not block truncation forever');
      expect(s.messageCount, 4);
      // The summarization caller stores a summary; the LLM view must remain
      // valid: getMessages() strips leading orphaned tool messages.
      s.summary = 'summary of tool-heavy session';
      final view = s.getMessages();
      expect(view.first.role, 'system');
      for (final m in view.skip(1)) {
        if (m.role == 'tool') {
          final hasParent = view.any((p) =>
              p.role == 'assistant' &&
              (p.toolCalls ?? []).any((tc) => tc.id == m.toolCallId));
          expect(hasParent, isTrue,
              reason: 'no orphaned tool result in the LLM view');
        }
      }
    });

    test('the guard still keeps the last standalone message when one exists',
        () {
      // Pinned behavior (characterization): when a standalone message exists
      // anywhere, the window grows to retain it instead of falling back.
      final s = Session(key: 'guarded');
      s.addMessage(const Message(role: 'user', content: 'question'));
      s.addMessage(Message(
        role: 'assistant',
        content: '',
        toolCalls: const [ToolCall(id: 't1', name: 'echo', arguments: {})],
      ));
      s.addMessage(const Message(
          role: 'tool', content: 'r1', toolCallId: 't1', name: 'echo'));

      s.truncateHistory(1);
      expect(
          s.messages.any((m) =>
              (m.role == 'user' || m.role == 'assistant') &&
              (m.toolCalls == null || m.toolCalls!.isEmpty)),
          isTrue);
    });
  });
}
