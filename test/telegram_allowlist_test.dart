import 'package:flutter_test/flutter_test.dart';

import 'package:droidclaw/features/telegram/telegram_api.dart';
import 'package:droidclaw/features/telegram/telegram_bot_manager.dart';

void main() {
  group('TelegramBotManager.isAllowed (fail-closed)', () {
    test('empty allowlist denies everyone', () {
      expect(TelegramBotManager.isAllowed(const {}, 123), isFalse);
      expect(TelegramBotManager.isAllowed(const {}, null), isFalse);
    });

    test('null user id is never allowed, even with a non-empty allowlist', () {
      expect(TelegramBotManager.isAllowed(const {123}, null), isFalse);
    });

    test('matches by numeric id', () {
      expect(TelegramBotManager.isAllowed(const {123, 456}, 456), isTrue);
      expect(TelegramBotManager.isAllowed(const {123, 456}, 789), isFalse);
    });
  });

  group('TelegramUpdate.fromJson', () {
    test('extracts the numeric user id from from.id', () {
      final u = TelegramUpdate.fromJson({
        'update_id': 1,
        'message': {
          'from': {'id': 555, 'username': 'alice'},
          'chat': {'id': 999},
          'text': 'hi',
          'date': 1700000000,
        },
      });
      expect(u.userId, 555);
      expect(u.username, 'alice');
      expect(u.chatId, 999);
    });

    test('userId is null when from is absent', () {
      final u = TelegramUpdate.fromJson({
        'update_id': 2,
        'message': {
          'chat': {'id': 1},
          'text': 'x',
          'date': 1700000000,
        },
      });
      expect(u.userId, isNull);
    });
  });
}
