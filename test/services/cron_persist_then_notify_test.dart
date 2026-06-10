// Pins the persist-then-notify invariant of the cron-session cross-isolate
// handoff (BackgroundTaskHandler._executeCronLocally): the session save
// (write + fsync) must complete BEFORE the 'cron_completed' notification is
// sent to the main isolate, and if the save throws the notification must be
// suppressed entirely — the main isolate must never be told to reload state
// that was never written.
//
// The full BackgroundTaskHandler cannot be instantiated in a unit test (it
// runs on FlutterForegroundTask's service engine), so the invariant is
// tested at the extracted seam [BackgroundTaskHandler.persistSessionThenNotify],
// which is exactly the code the cron path executes.

import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/core/providers/llm_response.dart';
import 'package:droidclaw/core/services/background_task_handler.dart';
import 'package:droidclaw/core/session/session.dart';
import 'package:droidclaw/core/session/session_manager.dart';

/// SessionManager seam double: records save order and can be told to throw,
/// without needing a Hive box (the cache-backed getOrCreate/get suffice).
class _SeamSessionManager extends SessionManager {
  final List<String> events = [];
  bool throwOnSave = false;

  @override
  Future<void> save(Session session, {bool flush = true}) async {
    if (throwOnSave) throw StateError('disk full');
    events.add('save:${session.key}');
  }
}

void main() {
  group('BackgroundTaskHandler.persistSessionThenNotify', () {
    test('save throws ⇒ the cron_completed notification is suppressed and '
        'the error propagates to the caller', () async {
      final sessions = _SeamSessionManager()..throwOnSave = true;
      sessions
          .getOrCreate('cron_x')
          .addMessage(const Message(role: 'assistant', content: 'result'));

      final notifications = <Map<String, dynamic>>[];
      await expectLater(
        BackgroundTaskHandler.persistSessionThenNotify(
          sessions: sessions,
          sessionKey: 'cron_x',
          notification: {'type': 'cron_completed', 'cron_id': 'x'},
          notify: notifications.add,
        ),
        throwsStateError,
      );

      expect(notifications, isEmpty,
          reason: 'the main isolate must never be told to reload state '
              'that was never written');
    });

    test('happy path: the save completes BEFORE the notification fires',
        () async {
      final sessions = _SeamSessionManager();
      sessions
          .getOrCreate('cron_y')
          .addMessage(const Message(role: 'assistant', content: 'result'));

      await BackgroundTaskHandler.persistSessionThenNotify(
        sessions: sessions,
        sessionKey: 'cron_y',
        notification: {'type': 'cron_completed', 'cron_id': 'y'},
        notify: (data) => sessions.events.add('notify:${data['cron_id']}'),
      );

      expect(sessions.events, ['save:cron_y', 'notify:y']);
    });

    test('no session for the key: notification still fires (nothing to '
        'persist)', () async {
      final sessions = _SeamSessionManager();

      final notifications = <Map<String, dynamic>>[];
      await BackgroundTaskHandler.persistSessionThenNotify(
        sessions: sessions,
        sessionKey: 'cron_missing',
        notification: {'type': 'cron_completed', 'cron_id': 'm'},
        notify: notifications.add,
      );

      expect(sessions.events, isEmpty);
      expect(notifications, hasLength(1));
    });
  });
}
