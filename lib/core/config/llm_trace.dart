import 'dart:math';

/// A single LLM API call trace with full request/response data.
class LlmTrace {
  final String id;
  final DateTime timestamp;
  final String provider;
  final String model;
  final String callType; // 'chat', 'summarize', 'extract'
  final int iteration;
  final String? sessionKey;

  // Request
  final int messageCount;
  final int systemPromptChars;
  final String systemPromptPreview;
  final List<LlmTraceMessage> messages;
  final int toolDefinitionCount;

  // Response
  final String? responseContent;
  final int? responseChars;
  final List<String> toolCalls;
  final String? finishReason;
  final String? error;

  // Metrics
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int latencyMs;

  LlmTrace({
    String? id,
    DateTime? timestamp,
    required this.provider,
    required this.model,
    required this.callType,
    this.iteration = 0,
    this.sessionKey,
    required this.messageCount,
    this.systemPromptChars = 0,
    this.systemPromptPreview = '',
    this.messages = const [],
    this.toolDefinitionCount = 0,
    this.responseContent,
    this.responseChars,
    this.toolCalls = const [],
    this.finishReason,
    this.error,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    required this.latencyMs,
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  bool get isError => error != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'provider': provider,
        'model': model,
        'callType': callType,
        'iteration': iteration,
        if (sessionKey != null) 'sessionKey': sessionKey,
        'messageCount': messageCount,
        'systemPromptChars': systemPromptChars,
        'systemPromptPreview': systemPromptPreview,
        'messages': messages.map((m) => m.toJson()).toList(),
        'toolDefinitionCount': toolDefinitionCount,
        if (responseContent != null) 'responseContent': responseContent,
        if (responseChars != null) 'responseChars': responseChars,
        'toolCalls': toolCalls,
        if (finishReason != null) 'finishReason': finishReason,
        if (error != null) 'error': error,
        if (promptTokens != null) 'promptTokens': promptTokens,
        if (completionTokens != null) 'completionTokens': completionTokens,
        if (totalTokens != null) 'totalTokens': totalTokens,
        'latencyMs': latencyMs,
      };

  factory LlmTrace.fromJson(Map<String, dynamic> json) => LlmTrace(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        provider: json['provider'] as String,
        model: json['model'] as String,
        callType: json['callType'] as String? ?? 'chat',
        iteration: json['iteration'] as int? ?? 0,
        sessionKey: json['sessionKey'] as String?,
        messageCount: json['messageCount'] as int? ?? 0,
        systemPromptChars: json['systemPromptChars'] as int? ?? 0,
        systemPromptPreview: json['systemPromptPreview'] as String? ?? '',
        messages: (json['messages'] as List?)
                ?.map((m) =>
                    LlmTraceMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        toolDefinitionCount: json['toolDefinitionCount'] as int? ?? 0,
        responseContent: json['responseContent'] as String?,
        responseChars: json['responseChars'] as int?,
        toolCalls: (json['toolCalls'] as List?)
                ?.map((t) => t as String)
                .toList() ??
            [],
        finishReason: json['finishReason'] as String?,
        error: json['error'] as String?,
        promptTokens: json['promptTokens'] as int?,
        completionTokens: json['completionTokens'] as int?,
        totalTokens: json['totalTokens'] as int?,
        latencyMs: json['latencyMs'] as int? ?? 0,
      );

  static String _generateId() {
    final r = Random();
    final hex = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Compact representation of a message in a trace.
class LlmTraceMessage {
  final String role;
  final int contentLength;
  final String preview;
  final String? toolName;

  const LlmTraceMessage({
    required this.role,
    required this.contentLength,
    required this.preview,
    this.toolName,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'contentLength': contentLength,
        'preview': preview,
        if (toolName != null) 'toolName': toolName,
      };

  factory LlmTraceMessage.fromJson(Map<String, dynamic> json) =>
      LlmTraceMessage(
        role: json['role'] as String,
        contentLength: json['contentLength'] as int? ?? 0,
        preview: json['preview'] as String? ?? '',
        toolName: json['toolName'] as String?,
      );
}

/// Aggregated stats across all traces.
class LlmTraceStats {
  final int totalCalls;
  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int avgLatencyMs;
  final DateTime? oldestTrace;
  final DateTime? newestTrace;

  const LlmTraceStats({
    this.totalCalls = 0,
    this.totalPromptTokens = 0,
    this.totalCompletionTokens = 0,
    this.avgLatencyMs = 0,
    this.oldestTrace,
    this.newestTrace,
  });
}
