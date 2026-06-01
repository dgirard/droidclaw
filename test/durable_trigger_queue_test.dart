// ignore_for_file: depend_on_referenced_packages

import 'package:test/test.dart';

import 'package:droidclaw/core/session/isolate_persistence/durable_trigger_queue.dart';

void main() {
  group('DurableTriggerQueue.decode', () {
    test('tolerates null, empty, malformed, and non-list input', () {
      expect(DurableTriggerQueue.decode(null), isEmpty);
      expect(DurableTriggerQueue.decode(''), isEmpty);
      expect(DurableTriggerQueue.decode('not json'), isEmpty);
      expect(DurableTriggerQueue.decode('{"a":1}'), isEmpty); // not a list
    });

    test('round-trips through encode', () {
      final list = [
        {'cron_id': 'a', 'prompt': 'x'},
      ];
      expect(
        DurableTriggerQueue.decode(DurableTriggerQueue.encode(list)),
        list,
      );
    });
  });

  group('DurableTriggerQueue.enqueue', () {
    test('dedupes by cron_id — the latest trigger wins', () {
      var q = <Map<String, dynamic>>[];
      q = DurableTriggerQueue.enqueue(q, {'cron_id': 'a', 'prompt': 'first'});
      q = DurableTriggerQueue.enqueue(q, {'cron_id': 'b', 'prompt': 'other'});
      q = DurableTriggerQueue.enqueue(q, {'cron_id': 'a', 'prompt': 'second'});

      expect(q.length, 2);
      expect(q.firstWhere((t) => t['cron_id'] == 'a')['prompt'], 'second');
    });
  });

  group('DurableTriggerQueue.removeByCronId', () {
    test('removes only the matching entry', () {
      final q = [
        {'cron_id': 'a'},
        {'cron_id': 'b'},
      ];
      final after = DurableTriggerQueue.removeByCronId(q, 'a');
      expect(after.map((t) => t['cron_id']), ['b']);
    });
  });
}
