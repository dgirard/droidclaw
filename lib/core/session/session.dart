import '../providers/llm_response.dart';

/// A conversation session with message history.
class Session {
  final String key;
  final List<Message> _messages;
  String? summary;
  final DateTime created;
  DateTime updated;

  Session({
    required this.key,
    List<Message>? messages,
    this.summary,
    DateTime? created,
    DateTime? updated,
  })  : _messages = messages ?? [],
        created = created ?? DateTime.now(),
        updated = updated ?? DateTime.now();

  /// Get all messages in the session.
  List<Message> get messages => List.unmodifiable(_messages);

  /// Get the message count.
  int get messageCount => _messages.length;

  /// Add a message to the session.
  void addMessage(Message message) {
    _messages.add(message);
    updated = DateTime.now();
  }

  /// Get messages for the LLM context.
  /// If a summary exists, prepends it as a system message.
  List<Message> getMessages() {
    if (summary != null && summary!.isNotEmpty) {
      return [
        Message(
          role: 'system',
          content: 'Summary of previous conversation:\n$summary',
        ),
        ..._messages,
      ];
    }
    return List.of(_messages);
  }

  /// Truncate history, keeping only the last [keepLast] messages.
  /// Returns the messages that were removed (for summarization).
  List<Message> truncateHistory(int keepLast) {
    if (_messages.length <= keepLast) return [];
    final removed = _messages.sublist(0, _messages.length - keepLast);
    _messages.removeRange(0, _messages.length - keepLast);
    updated = DateTime.now();
    return removed;
  }

  /// Serialize to JSON for Hive storage.
  Map<String, dynamic> toJson() => {
        'key': key,
        'messages': _messages.map((m) => m.toJson()).toList(),
        'summary': summary,
        'created': created.toIso8601String(),
        'updated': updated.toIso8601String(),
      };

  /// Deserialize from JSON.
  factory Session.fromJson(Map<String, dynamic> json) => Session(
        key: json['key'] as String,
        messages: (json['messages'] as List?)
            ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] as String?,
        created: json['created'] != null
            ? DateTime.parse(json['created'] as String)
            : null,
        updated: json['updated'] != null
            ? DateTime.parse(json['updated'] as String)
            : null,
      );
}
