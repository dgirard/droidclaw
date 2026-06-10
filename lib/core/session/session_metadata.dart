import '../../shared/constants.dart';
import 'session.dart';

/// Lightweight, list-screen-sized view of a [Session].
///
/// Stored as a sidecar record in the `sessions` Hive box under
/// `AppConstants.sessionMetaKeyPrefix + sessionKey`, written on every
/// [Session] save. It lets `SessionManager` build the History/cron lists at
/// startup WITHOUT decoding every session's full message history — full
/// decode happens lazily on first access of a specific session.
///
/// Metadata is always derivable from the session record, so losing or
/// corrupting a metadata record is harmless: `SessionManager` falls back to
/// a one-time full decode and rewrites it.
class SessionMetadata {
  final String key;
  final DateTime created;
  final DateTime updated;

  /// Total number of messages (all roles).
  final int messageCount;

  /// Number of user + assistant messages (what the History screen shows).
  final int conversationMessageCount;

  /// First user message, normalized and truncated — the session title.
  final String? preview;

  /// Session summary, normalized and truncated — title fallback.
  final String? summaryPreview;

  const SessionMetadata({
    required this.key,
    required this.created,
    required this.updated,
    required this.messageCount,
    required this.conversationMessageCount,
    this.preview,
    this.summaryPreview,
  });

  factory SessionMetadata.fromSession(Session session) {
    String? preview;
    var conversationCount = 0;
    for (final m in session.messages) {
      if (m.role == 'user' || m.role == 'assistant') {
        conversationCount++;
        if (preview == null && m.role == 'user') {
          preview = _normalize(m.content);
        }
      }
    }
    return SessionMetadata(
      key: session.key,
      created: session.created,
      updated: session.updated,
      messageCount: session.messageCount,
      conversationMessageCount: conversationCount,
      preview: preview,
      summaryPreview: _normalize(session.summary),
    );
  }

  static String? _normalize(String? text) {
    if (text == null) return null;
    final t = text.replaceAll('\n', ' ').trim();
    if (t.isEmpty) return null;
    return t.length <= AppConstants.sessionPreviewMaxChars
        ? t
        : t.substring(0, AppConstants.sessionPreviewMaxChars);
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'created': created.toIso8601String(),
        'updated': updated.toIso8601String(),
        'messageCount': messageCount,
        'conversationMessageCount': conversationMessageCount,
        'preview': preview,
        'summaryPreview': summaryPreview,
      };

  factory SessionMetadata.fromJson(Map<String, dynamic> json) =>
      SessionMetadata(
        key: json['key'] as String,
        created: DateTime.parse(json['created'] as String),
        updated: DateTime.parse(json['updated'] as String),
        messageCount: json['messageCount'] as int,
        conversationMessageCount: json['conversationMessageCount'] as int,
        preview: json['preview'] as String?,
        summaryPreview: json['summaryPreview'] as String?,
      );
}
