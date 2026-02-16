/// Per-chat rate limiter for Telegram message sending.
///
/// Ensures at most one message per second per chat to respect
/// Telegram Bot API rate limits.
class RateLimiter {
  final Map<int, DateTime> _lastSent = {};
  static const _perChatInterval = Duration(seconds: 1);

  /// Wait until a send slot is available for [chatId].
  ///
  /// If a message was sent to this chat less than 1 second ago,
  /// delays until the interval has passed.
  Future<void> waitForSlot(int chatId) async {
    final last = _lastSent[chatId];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _perChatInterval) {
        await Future.delayed(_perChatInterval - elapsed);
      }
    }
    _lastSent[chatId] = DateTime.now();
  }

  /// Clear rate limit tracking for a specific chat.
  void clearChat(int chatId) {
    _lastSent.remove(chatId);
  }

  /// Clear all rate limit tracking.
  void clearAll() {
    _lastSent.clear();
  }
}
