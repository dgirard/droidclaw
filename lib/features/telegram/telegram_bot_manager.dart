import 'dart:async';
import 'dart:collection';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/agent/agent_loop.dart';
import '../../l10n/l10n.dart';
import '../../shared/constants.dart';
import 'rate_limiter.dart';

/// Runs in the main isolate. Bridges TaskHandler messages to AgentLoop.
///
/// - Receives incoming Telegram messages forwarded from TaskHandler
/// - Maintains per-chat message queues (sequential within a chat)
/// - Processes up to [AppConstants.telegramMaxConcurrentChats] chats concurrently
/// - Sends agent responses back to TaskHandler for Telegram delivery
class TelegramBotManager {
  final AgentLoop agentLoop;
  final String locale;
  final RateLimiter _rateLimiter = RateLimiter();
  final Map<int, Queue<_IncomingMessage>> _chatQueues = {};
  final Set<int> _processing = {};

  /// Allowlist of permitted Telegram user IDs. Matching is by stable numeric
  /// ID, never username (usernames are user-changeable and spoofable).
  Set<int> _allowedUsers = {};

  /// Callback invoked when a message is received or response sent.
  /// Used by the provider to update stats.
  void Function(TelegramBotEvent)? onEvent;

  TelegramBotManager({required this.agentLoop, this.locale = 'en'});

  /// Update the allowlist of permitted Telegram user IDs.
  void setAllowedUsers(Set<int> users) {
    _allowedUsers = users;
  }

  /// Whether [userId] may use the bot. Fail-closed: an empty allowlist denies
  /// everyone (an open bot exposes contacts/calendar/location/file tools), and
  /// a null/absent user ID is never allowed. Matching is by numeric ID only.
  static bool isAllowed(Set<int> allowed, int? userId) {
    if (allowed.isEmpty || userId == null) return false;
    return allowed.contains(userId);
  }

  /// Handle an incoming message from the TaskHandler isolate.
  ///
  /// Called by the TelegramProvider when it receives data from the
  /// foreground service via FlutterForegroundTask.addTaskDataCallback.
  Future<void> handleIncomingMessage({
    required int chatId,
    required String text,
    int? userId,
    String? username,
    required int updateId,
  }) async {
    // Allowlist check — fail-closed (see [isAllowed]).
    if (!isAllowed(_allowedUsers, userId)) {
      await _rateLimiter.waitForSlot(chatId);
      FlutterForegroundTask.sendDataToTask({
        'action': 'send',
        'chat_id': chatId,
        'text': tr(locale).telegramBotPrivate,
      });
      onEvent?.call(TelegramBotEvent.accessDenied(chatId, username));
      return;
    }

    // Add to per-chat queue
    _chatQueues.putIfAbsent(chatId, () => Queue());
    _chatQueues[chatId]!.add(_IncomingMessage(
      chatId: chatId,
      text: text,
      username: username,
      updateId: updateId,
    ));

    onEvent?.call(TelegramBotEvent.messageReceived(chatId, username));

    // Start processing if not already active for this chat
    // and concurrent limit not reached
    if (!_processing.contains(chatId) &&
        _processing.length < AppConstants.telegramMaxConcurrentChats) {
      _processQueue(chatId);
    }
  }

  Future<void> _processQueue(int chatId) async {
    _processing.add(chatId);

    while (_chatQueues[chatId]?.isNotEmpty ?? false) {
      final message = _chatQueues[chatId]!.removeFirst();

      try {
        String? finalResponse;
        final sessionKey =
            '${AppConstants.telegramSessionPrefix}$chatId';

        await for (final event
            in agentLoop.processMessage(message.text, sessionKey)) {
          switch (event) {
            case ResponseEvent():
              finalResponse = event.content;
            case ErrorEvent():
              finalResponse = tr(locale).telegramErrorGeneric;
            case ThinkingEvent():
            case SummarizingEvent():
            case ToolCallEvent():
            case ToolResultEvent():
              // These events are internal — no Telegram output needed
              break;
          }
        }

        if (finalResponse != null) {
          await _rateLimiter.waitForSlot(chatId);
          FlutterForegroundTask.sendDataToTask({
            'action': 'send',
            'chat_id': chatId,
            'text': finalResponse,
          });
          onEvent?.call(TelegramBotEvent.responseSent(chatId));
        }
      } catch (e) {
        FlutterForegroundTask.sendDataToTask({
          'action': 'send',
          'chat_id': chatId,
          'text': tr(locale).telegramErrorProcessing,
        });
        onEvent?.call(TelegramBotEvent.error(chatId, e.toString()));
      }
    }

    _processing.remove(chatId);

    // Check if any queued chats can now be processed
    for (final queuedChatId in _chatQueues.keys) {
      if (!_processing.contains(queuedChatId) &&
          (_chatQueues[queuedChatId]?.isNotEmpty ?? false) &&
          _processing.length < AppConstants.telegramMaxConcurrentChats) {
        _processQueue(queuedChatId);
      }
    }
  }

  /// Clean up resources.
  void dispose() {
    _chatQueues.clear();
    _processing.clear();
    _rateLimiter.clearAll();
  }
}

/// Internal message holder for the per-chat queue.
class _IncomingMessage {
  final int chatId;
  final String text;
  final String? username;
  final int updateId;

  const _IncomingMessage({
    required this.chatId,
    required this.text,
    this.username,
    required this.updateId,
  });
}

/// Events emitted by the bot manager for stats/UI tracking.
sealed class TelegramBotEvent {
  const TelegramBotEvent();

  factory TelegramBotEvent.messageReceived(int chatId, String? username) =
      MessageReceivedEvent;
  factory TelegramBotEvent.responseSent(int chatId) = ResponseSentEvent;
  factory TelegramBotEvent.accessDenied(int chatId, String? username) =
      AccessDeniedEvent;
  factory TelegramBotEvent.error(int chatId, String message) =
      BotErrorEvent;
}

class MessageReceivedEvent extends TelegramBotEvent {
  final int chatId;
  final String? username;
  const MessageReceivedEvent(this.chatId, this.username);
}

class ResponseSentEvent extends TelegramBotEvent {
  final int chatId;
  const ResponseSentEvent(this.chatId);
}

class AccessDeniedEvent extends TelegramBotEvent {
  final int chatId;
  final String? username;
  const AccessDeniedEvent(this.chatId, this.username);
}

class BotErrorEvent extends TelegramBotEvent {
  final int chatId;
  final String message;
  const BotErrorEvent(this.chatId, this.message);
}
