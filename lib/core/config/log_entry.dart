import 'package:uuid/uuid.dart';

/// Severity level for log entries.
enum LogLevel { debug, info, warning, error }

/// Origin of a log entry.
enum LogSource { agent, cron, service, telegram, app }

/// A persistent log entry stored in .jsonl files.
class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogSource source;
  final String message;
  final String? sessionKey;
  final String? cronId;
  final Map<String, dynamic>? metadata;

  LogEntry({
    String? id,
    DateTime? timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.sessionKey,
    this.cronId,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'source': source.name,
        'message': message,
        if (sessionKey != null) 'sessionKey': sessionKey,
        if (cronId != null) 'cronId': cronId,
        if (metadata != null) 'metadata': metadata,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: LogLevel.values.byName(json['level'] as String),
        source: LogSource.values.byName(json['source'] as String),
        message: json['message'] as String,
        sessionKey: json['sessionKey'] as String?,
        cronId: json['cronId'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}
