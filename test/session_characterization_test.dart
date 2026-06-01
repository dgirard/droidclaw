// Characterization tests: pin the CURRENT behavior of the session-persistence
// layer before U10 consolidates the dual-isolate glue. Each test encodes a
// fix from a past field incident (see docs/solutions/*); they must keep
// passing unchanged after the consolidation to prove it preserved behavior.

import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/session/session.dart';
import 'package:droidclaw/core/session/session_manager.dart';

import 'support/hive_test_harness.dart';

void main() {
  group('SessionManager persistence (Hive flush durability)', () {
    late HiveTestHarness hive;

    setUp(() async => hive = await HiveTestHarness.create());
    tearDown(() => hive.dispose());

    test('a saved session survives a reload (flush-on-save)', () async {
      final mgr = SessionManager();
      await mgr.init();

      final s = mgr.getOrCreate('s1');
      s.addMessage(const Message(role: 'user', content: 'hello'));
      await mgr.save(s);

      // reload() closes and reopens the box, forcing a disk re-read — the
      // message must survive, which it only does because save() flushes.
      await mgr.reload();

      final reloaded = mgr.get('s1');
      expect(reloaded, isNotNull);
      expect(reloaded!.messages.single.content, 'hello');
    });

    test('getOrCreate returns the same cached instance for a key', () async {
      final mgr = SessionManager();
      await mgr.init();
      expect(identical(mgr.getOrCreate('k'), mgr.getOrCreate('k')), isTrue);
    });

    test('deleted sessions do not reappear after reload', () async {
      final mgr = SessionManager();
      await mgr.init();
      final s = mgr.getOrCreate('gone');
      s.addMessage(const Message(role: 'user', content: 'x'));
      await mgr.save(s);
      await mgr.deleteSession('gone');

      await mgr.reload();
      expect(mgr.get('gone'), isNull);
    });
  });

  group('Session read/truncate invariants', () {
    test('getMessages() does not mutate the canonical message list', () {
      final s = Session(key: 'x');
      // A leading orphaned tool result is stripped from the returned view...
      s.addMessage(const Message(
          role: 'tool', content: 'orphan', toolCallId: 't1', name: 'echo'));
      s.addMessage(const Message(role: 'user', content: 'hi'));

      final view = s.getMessages();

      expect(view.first.role, isNot('tool')); // stripped from the copy
      expect(s.messageCount, 2); // canonical list untouched
    });

    test('truncateHistory never strips away the last standalone message',
        () {
      final s = Session(key: 'y');
      s.addMessage(const Message(role: 'user', content: 'question'));
      s.addMessage(Message(
        role: 'assistant',
        content: '',
        toolCalls: const [
          ToolCall(id: 't1', name: 'echo', arguments: {}),
        ],
      ));
      s.addMessage(const Message(
          role: 'tool', content: 'r1', toolCallId: 't1', name: 'echo'));
      s.addMessage(const Message(
          role: 'tool', content: 'r2', toolCallId: 't2', name: 'echo'));

      // keepLast=1 would retain only a tool result; the guard must grow the
      // window until a standalone user/assistant message is retained.
      s.truncateHistory(1);

      final hasStandalone = s.messages.any((m) =>
          (m.role == 'user' || m.role == 'assistant') &&
          (m.toolCalls == null || m.toolCalls!.isEmpty));
      expect(hasStandalone, isTrue);
    });

    test('truncateHistory returns removed messages when it can truncate', () {
      final s = Session(key: 'z');
      for (var i = 0; i < 10; i++) {
        s.addMessage(Message(role: 'user', content: 'm$i'));
      }
      final removed = s.truncateHistory(4);
      expect(removed, isNotEmpty);
      expect(s.messageCount, lessThan(10));
    });
  });
}
