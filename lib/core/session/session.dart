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
  /// Repairs tool messages missing `name` and strips orphaned tool results.
  /// Gemini returns 400 if function_response has empty name or appears first.
  List<Message> getMessages() {
    _repairToolNames();
    _stripOrphanedLeadingMessages();

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

  /// Repair tool result messages that are missing or have empty `name`.
  /// Old sessions saved before the name field was added, or sessions
  /// restored after summarization, may have tool messages without names.
  /// Gemini API returns 400 if name is missing/empty on function_response.
  void _repairToolNames() {
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.role != 'tool') continue;
      if (msg.name != null && msg.name!.isNotEmpty) continue;

      // Try to find the name from the preceding assistant message's toolCalls
      String? repairedName;
      if (msg.toolCallId != null) {
        for (var j = i - 1; j >= 0; j--) {
          final prev = _messages[j];
          if (prev.role == 'assistant' && prev.toolCalls != null) {
            for (final tc in prev.toolCalls!) {
              if (tc.id == msg.toolCallId) {
                repairedName = tc.name;
                break;
              }
            }
            if (repairedName != null) break;
          }
        }
      }

      _messages[i] = msg.copyWith(name: repairedName ?? 'unknown');
    }
  }

  /// Strip orphaned tool results and assistant tool_calls at the start.
  /// After summarization, the first messages may be tool results whose
  /// parent assistant message was summarized away, or assistant messages
  /// with tool_calls whose tool results were removed. Gemini rejects
  /// these as contents[0] (function_response without context).
  void _stripOrphanedLeadingMessages() {
    while (_messages.isNotEmpty) {
      final first = _messages.first;
      if (first.role == 'tool') {
        // Orphaned tool result — no preceding assistant with tool_calls
        _messages.removeAt(0);
      } else if (first.role == 'assistant' &&
          first.toolCalls != null &&
          first.toolCalls!.isNotEmpty) {
        // Assistant message with tool_calls but tool results may follow.
        // Check if all its tool_calls have matching tool results after it.
        final tcIds = first.toolCalls!.map((tc) => tc.id).toSet();
        final hasAllResults = tcIds.every((id) => _messages.any(
              (m) => m.role == 'tool' && m.toolCallId == id,
            ));
        if (!hasAllResults) {
          // Orphaned assistant tool_calls — remove it
          _messages.removeAt(0);
        } else {
          break;
        }
      } else {
        break;
      }
    }
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
