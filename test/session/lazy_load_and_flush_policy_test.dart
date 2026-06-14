// U13 behaviors ported to SQLite (U6): lazy session loading (metadata
// columns, no eager payload decode) and the turn-ending save cadence.
//
// REINTERPRETATION NOTE on the durability assertions: under WAL +
// synchronous=NORMAL every committed save is equally durable against
// process kill — the Hive-era fsync tiering is vestigial. The `flush`
// parameter and `flushCount` are KEPT so these tests keep pinning the
// POLICY (which operations are turn-ending: default saves, deletes, the
// lifecycle flush) — the cadence contract call sites still rely on.
//
// Conscious retirements from the Hive era (R14):
// - "legacy box without metadata sidecars: init decodes once and heals":
//   sidecars became table columns written by the same UPSERT as the
//   payload; rows without metadata cannot exist (the migrator computes the
//   columns for every copied session — pinned in migration_test.dart).
// - "a corrupted metadata sidecar falls back to the session record" and
//   "an orphaned metadata sidecar is never listed as a ghost": both states
//   are impossible by construction with a single row carrying payload and
//   metadata atomically.
// - the close()-flushes caveat: the unflushed-write visibility assertion
//   now does a genuinely cold read through a second manager.

import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session.dart';

import '../support/session_db_test_harness.dart';

void main() {
  late SessionDbTestHarness store;

  setUp(() async => store = await SessionDbTestHarness.create());
  tearDown(() => store.dispose());

  /// Seed N sessions through a throwaway manager, then close it so the next
  /// manager starts cold from the database file.
  Future<void> seedSessions(int count) async {
    final seeder = await store.manager();
    for (var i = 0; i < count; i++) {
      final s = seeder.getOrCreate('s$i');
      s.addMessage(Message(role: 'user', content: 'question $i'));
      s.addMessage(Message(role: 'assistant', content: 'answer $i'));
      await seeder.save(s);
    }
    await seeder.close();
  }

  group('Lazy load', () {
    test('init does not decode any full session payload', () async {
      await seedSessions(5);

      final mgr = await store.manager();
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

      final mgr = await store.manager();

      final s = mgr.get('s1');
      expect(s, isNotNull);
      expect(s!.messages.first.content, 'question 1');
      expect(mgr.sessionDecodeCount, 1);

      // Cached: second access does not decode again.
      expect(identical(mgr.get('s1'), s), isTrue);
      expect(mgr.sessionDecodeCount, 1);
    });

    test('metadata carries what the History screen renders', () async {
      final seeder = await store.manager();
      final s = seeder.getOrCreate('m');
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
      await seeder.save(s);
      await seeder.close();

      final cold = await store.manager();
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
      final mgr = await store.manager();
      final fresh = mgr.createNew(key: 'unsaved');
      fresh.addMessage(const Message(role: 'user', content: 'hello'));

      final meta = mgr.getAllSessionMetadata();
      expect(meta.map((m) => m.key), contains('unsaved'));
      expect(meta.firstWhere((m) => m.key == 'unsaved').preview, 'hello');
    });

    test('cross-isolate write: reload() picks up new metadata without '
        'decoding any history', () async {
      final main = await store.manager();
      final chat = main.getOrCreate('chat');
      chat.addMessage(const Message(role: 'user', content: 'hello'));
      await main.save(chat);

      // Independent second manager = the service isolate's own connections
      // on the same WAL file (the production topology).
      final service = await store.manager();
      final cron = service.getOrCreate('cron_daily');
      cron.addMessage(
          const Message(role: 'assistant', content: 'cron output'));
      await service.save(cron);

      main.sessionDecodeCount = 0;
      await main.reload();
      expect(main.getAllSessionMetadata().map((m) => m.key),
          contains('cron_daily'));
      expect(main.sessionDecodeCount, 0,
          reason: 'reload rebuilds the index from metadata columns, not '
              'histories');

      // Full content is there on demand.
      expect(main.get('cron_daily')!.messages.single.content, 'cron output');
      expect(main.sessionDecodeCount, 1);
    });
  });

  group('Turn-ending save cadence (formerly the fsync flush policy)', () {
    test('save() counts as turn-ending by default; save(flush: false) does '
        'not — but BOTH are committed (durable)', () async {
      final mgr = await store.manager();
      final baseline = mgr.flushCount;

      final s = mgr.getOrCreate('p');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);
      expect(mgr.flushCount, baseline + 1);

      s.addMessage(const Message(role: 'assistant', content: 'y'));
      await mgr.save(s, flush: false);
      expect(mgr.flushCount, baseline + 1,
          reason: 'intermediate saves are not turn-ending');

      // The mid-turn save is nonetheless committed: a genuinely COLD second
      // manager (own connections, no shared cache) reads both messages.
      // This is the durability assertion that replaces the Hive-era
      // "reload survival with close()-flushes caveat".
      final cold = await store.manager();
      expect(cold.get('p')!.messages, hasLength(2));
    });

    test('deleteSession and deleteAllSessions are turn-ending', () async {
      final mgr = await store.manager();
      final s = mgr.getOrCreate('d');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);

      final baseline = mgr.flushCount;
      await mgr.deleteSession('d');
      expect(mgr.flushCount, baseline + 1);

      await mgr.deleteAllSessions();
      expect(mgr.flushCount, baseline + 2);
    });

    test('flush() issues exactly one checkpoint — the app-pause lifecycle '
        'hook in app.dart relies on this contract', () async {
      final mgr = await store.manager();
      final baseline = mgr.flushCount;

      await mgr.flush();
      expect(mgr.flushCount, baseline + 1);
    });

    test('init/reload never count as turn-ending durability points',
        () async {
      await seedSessions(1);
      final mgr = await store.manager();
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
