import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants.dart';

/// A single Telegram update from getUpdates.
class TelegramUpdate {
  final int updateId;
  final int chatId;

  /// Stable numeric sender ID (`from.id`). Used for allowlisting — usernames
  /// are user-changeable and spoofable, so they are display-only.
  final int? userId;
  final String? username;
  final String text;
  final DateTime date;

  const TelegramUpdate({
    required this.updateId,
    required this.chatId,
    this.userId,
    this.username,
    required this.text,
    required this.date,
  });

  factory TelegramUpdate.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>?;
    if (message == null) {
      throw FormatException('Update ${json['update_id']} has no message');
    }

    final from = message['from'] as Map<String, dynamic>?;
    final chat = message['chat'] as Map<String, dynamic>;

    return TelegramUpdate(
      updateId: json['update_id'] as int,
      chatId: chat['id'] as int,
      userId: from?['id'] as int?,
      username: from?['username'] as String?,
      text: message['text'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        (message['date'] as int) * 1000,
      ),
    );
  }
}

/// Raw HTTP client for Telegram Bot API.
///
/// Handles getMe, getUpdates (long polling), and sendMessage.
/// No external Telegram package dependency — just dart:http.
class TelegramApi {
  final String token;
  final http.Client _client;

  TelegramApi({required this.token, http.Client? client})
      : _client = client ?? http.Client();

  String get _baseUrl => '${AppConstants.telegramApiBase}$token';

  /// Verify bot token and get bot info.
  Future<Map<String, dynamic>> getMe() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/getMe'))
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] != true) {
      throw TelegramApiException(
        'getMe failed',
        statusCode: response.statusCode,
        description: body['description'] as String?,
      );
    }
    return body['result'] as Map<String, dynamic>;
  }

  /// Long-poll for new updates.
  ///
  /// [offset] — identifier of the first update to return.
  /// [timeout] — long polling timeout in seconds (default 30).
  /// [limit] — max number of updates (1-100, default 100).
  Future<List<TelegramUpdate>> getUpdates({
    int? offset,
    int timeout = AppConstants.telegramPollTimeout,
    int limit = 100,
  }) async {
    final params = <String, String>{
      'timeout': timeout.toString(),
      'limit': limit.toString(),
      'allowed_updates': '["message"]',
    };
    if (offset != null) {
      params['offset'] = offset.toString();
    }

    final uri = Uri.parse('$_baseUrl/getUpdates').replace(
      queryParameters: params,
    );

    final response = await _client.get(uri).timeout(
      Duration(seconds: AppConstants.telegramHttpTimeout),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 429) {
      final retryAfter = body['parameters']?['retry_after'] as int? ?? 5;
      throw TelegramRateLimitException(retryAfter: retryAfter);
    }

    if (body['ok'] != true) {
      throw TelegramApiException(
        'getUpdates failed',
        statusCode: response.statusCode,
        description: body['description'] as String?,
      );
    }

    final result = body['result'] as List<dynamic>;
    final updates = <TelegramUpdate>[];

    for (final item in result) {
      try {
        updates.add(
          TelegramUpdate.fromJson(item as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip non-message updates (edited_message, channel_post, etc.)
      }
    }

    return updates;
  }

  /// Send a text message to a chat.
  ///
  /// Automatically splits messages longer than [AppConstants.telegramMaxMessageLength].
  /// Uses HTML parse mode by default for rich formatting.
  Future<void> sendMessage(
    int chatId,
    String text, {
    String? parseMode = 'HTML',
  }) async {
    final chunks = _splitMessage(text);

    for (final chunk in chunks) {
      final body = <String, dynamic>{
        'chat_id': chatId,
        'text': chunk,
      };
      if (parseMode != null) {
        body['parse_mode'] = parseMode;
      }

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 429) {
        final retryAfter =
            responseBody['parameters']?['retry_after'] as int? ?? 5;
        throw TelegramRateLimitException(retryAfter: retryAfter);
      }

      if (responseBody['ok'] != true) {
        // If HTML parsing fails, retry without parse mode
        if (parseMode != null &&
            (responseBody['description'] as String? ?? '')
                .contains("can't parse")) {
          await sendMessage(chatId, chunk, parseMode: null);
          continue;
        }

        throw TelegramApiException(
          'sendMessage failed',
          statusCode: response.statusCode,
          description: responseBody['description'] as String?,
        );
      }
    }
  }

  /// Split a long message into chunks that fit Telegram's limit.
  List<String> _splitMessage(String text) {
    const maxLen = AppConstants.telegramMaxMessageLength;
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLen) {
        chunks.add(remaining);
        break;
      }

      // Try to split at a newline boundary
      var splitIndex = remaining.lastIndexOf('\n', maxLen);
      if (splitIndex <= 0) {
        // Fall back to space boundary
        splitIndex = remaining.lastIndexOf(' ', maxLen);
      }
      if (splitIndex <= 0) {
        // Hard split at max length
        splitIndex = maxLen;
      }

      chunks.add(remaining.substring(0, splitIndex));
      remaining = remaining.substring(splitIndex).trimLeft();
    }

    return chunks;
  }

  /// Close the underlying HTTP client.
  void close() {
    _client.close();
  }
}

/// General Telegram API error.
class TelegramApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? description;

  const TelegramApiException(
    this.message, {
    this.statusCode,
    this.description,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() {
    final parts = [message];
    if (statusCode != null) parts.add('status=$statusCode');
    if (description != null) parts.add(description!);
    return 'TelegramApiException(${parts.join(', ')})';
  }
}

/// Thrown when Telegram returns 429 Too Many Requests.
class TelegramRateLimitException extends TelegramApiException {
  final int retryAfter;

  const TelegramRateLimitException({required this.retryAfter})
      : super('Rate limited', statusCode: 429);

  @override
  String toString() =>
      'TelegramRateLimitException(retryAfter=${retryAfter}s)';
}
