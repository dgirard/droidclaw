import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';
import 'telegram_api.dart';

/// Top-level callback for the foreground service isolate.
/// Must be a top-level function with @pragma to survive tree-shaking.
@pragma('vm:entry-point')
void telegramServiceCallback() {
  FlutterForegroundTask.setTaskHandler(TelegramTaskHandler());
}

/// Runs in the foreground service isolate.
///
/// Responsibilities:
/// - Long-polls Telegram for new messages via getUpdates
/// - Forwards incoming messages to main isolate via sendDataToMain
/// - Receives responses from main isolate and sends them to Telegram
/// - Persists update offset across restarts
/// - Implements exponential backoff on failures
class TelegramTaskHandler extends TaskHandler {
  TelegramApi? _api;
  int _offset = 0;
  int _consecutiveFailures = 0;
  int _messageCount = 0;
  bool _polling = false;

  static const _maxBackoff = Duration(seconds: 60);
  static const _baseBackoff = Duration(seconds: 2);
  static const _disconnectedThreshold = 10;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final prefs = await SharedPreferences.getInstance();

    // Receive bot token from init data or stored prefs
    final token = prefs.getString(AppConstants.telegramBotTokenKey);
    if (token == null || token.isEmpty) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'error',
        'message': 'No bot token configured',
      });
      return;
    }

    _api = TelegramApi(token: token);

    // Restore persisted offset
    _offset = prefs.getInt(AppConstants.telegramBotOffsetKey) ?? 0;

    FlutterForegroundTask.sendDataToMain({
      'type': 'started',
      'timestamp': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_api == null || _polling) return;
    _polling = true;

    try {
      final updates = await _api!.getUpdates(
        offset: _offset > 0 ? _offset : null,
        timeout: AppConstants.telegramPollTimeout,
      );

      // Reset backoff on success
      _consecutiveFailures = 0;

      for (final update in updates) {
        // Skip empty messages
        if (update.text.isEmpty) {
          _offset = update.updateId + 1;
          continue;
        }

        // Forward to main isolate for AgentLoop processing
        FlutterForegroundTask.sendDataToMain({
          'type': 'message',
          'update_id': update.updateId,
          'chat_id': update.chatId,
          'username': update.username,
          'text': update.text,
          'date': update.date.millisecondsSinceEpoch,
        });

        _offset = update.updateId + 1;
        _messageCount++;
      }

      // Persist offset
      if (updates.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(AppConstants.telegramBotOffsetKey, _offset);
      }

      // Update notification
      FlutterForegroundTask.updateService(
        notificationTitle: 'DroidClaw Bot - Active',
        notificationText: 'Messages processed: $_messageCount',
      );
    } on TelegramRateLimitException catch (e) {
      // Respect Telegram's retry-after
      await Future.delayed(Duration(seconds: e.retryAfter));
    } on TelegramApiException catch (e) {
      _consecutiveFailures++;

      if (e.isUnauthorized) {
        // Invalid token — stop polling, notify main isolate
        FlutterForegroundTask.sendDataToMain({
          'type': 'error',
          'message': 'Invalid bot token (401 Unauthorized)',
        });
        FlutterForegroundTask.updateService(
          notificationTitle: 'DroidClaw Bot - Error',
          notificationText: 'Invalid bot token',
        );
        _api = null; // Stop polling
        return;
      }

      await _backoff();
    } catch (e) {
      _consecutiveFailures++;
      await _backoff();
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> onReceiveData(Object data) async {
    if (_api == null) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final action = map['action'] as String?;

    if (action == 'send') {
      final chatId = map['chat_id'] as int;
      final text = map['text'] as String;

      try {
        await _api!.sendMessage(chatId, text);
      } on TelegramRateLimitException catch (e) {
        await Future.delayed(Duration(seconds: e.retryAfter));
        try {
          await _api!.sendMessage(chatId, text);
        } catch (_) {
          // Give up after retry
        }
      } catch (e) {
        FlutterForegroundTask.sendDataToMain({
          'type': 'send_error',
          'chat_id': chatId,
          'message': 'Failed to send message: $e',
        });
      }
    } else if (action == 'update_token') {
      final token = map['token'] as String;
      _api = TelegramApi(token: token);
      _offset = 0;
      _consecutiveFailures = 0;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Persist final offset
    if (_offset > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.telegramBotOffsetKey, _offset);
    }

    _api?.close();
    _api = null;

    FlutterForegroundTask.sendDataToMain({
      'type': 'stopped',
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isTimeout': isTimeout,
    });
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    if (id == 'btn_stop') {
      FlutterForegroundTask.sendDataToMain({
        'type': 'stop_requested',
      });
    }
  }

  @override
  Future<void> onNotificationPressed() async {
    FlutterForegroundTask.sendDataToMain({
      'type': 'open_app',
    });
  }

  @override
  Future<void> onNotificationDismissed() async {
    // No-op: notification is persistent for foreground service
  }

  /// Exponential backoff on failures.
  Future<void> _backoff() async {
    final delay = _baseBackoff * (1 << (_consecutiveFailures - 1).clamp(0, 5));
    final capped = delay > _maxBackoff ? _maxBackoff : delay;

    if (_consecutiveFailures >= _disconnectedThreshold) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'DroidClaw Bot - Disconnected',
        notificationText: 'Retrying...',
      );
    }

    await Future.delayed(capped);
  }
}
