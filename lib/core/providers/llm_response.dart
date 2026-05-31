import 'dart:convert';

/// A message in the conversation history.
class Message {
  final String role;
  final String content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? name;

  const Message({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
  });

  /// Serialize to OpenAI message format.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      json['tool_calls'] = toolCalls!.map((t) => t.toJson()).toList();
    }
    if (toolCallId != null) {
      json['tool_call_id'] = toolCallId;
    }
    if (name != null) {
      json['name'] = name;
    }
    return json;
  }

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        role: json['role'] as String,
        content: json['content'] as String? ?? '',
        toolCalls: (json['tool_calls'] as List?)
            ?.map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
            .toList(),
        toolCallId: json['tool_call_id'] as String?,
        name: json['name'] as String?,
      );

  Message copyWith({
    String? role,
    String? content,
    List<ToolCall>? toolCalls,
    String? toolCallId,
    String? name,
  }) =>
      Message(
        role: role ?? this.role,
        content: content ?? this.content,
        toolCalls: toolCalls ?? this.toolCalls,
        toolCallId: toolCallId ?? this.toolCallId,
        name: name ?? this.name,
      );
}

/// A tool call requested by the LLM.
class ToolCall {
  final String id;
  final String type;
  final String name;
  final Map<String, dynamic> arguments;

  /// Opaque extra content from the provider (e.g. Gemini thought_signature).
  /// Must be echoed back unchanged in conversation history.
  final Map<String, dynamic>? extraContent;

  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.name,
    required this.arguments,
    this.extraContent,
  });

  /// Parse from OpenAI format (function.name) or Anthropic format (name).
  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final function_ = json['function'] as Map<String, dynamic>?;
    String name;
    Map<String, dynamic> arguments;

    if (function_ != null) {
      // OpenAI format: { id, type, function: { name, arguments } }
      name = function_['name'] as String;
      final argsRaw = function_['arguments'];
      arguments = argsRaw is String
          ? (jsonDecode(argsRaw) as Map<String, dynamic>)
          : (argsRaw as Map<String, dynamic>?) ?? {};
    } else {
      // Anthropic format: { id, type, name, input }
      name = json['name'] as String;
      arguments = (json['input'] as Map<String, dynamic>?) ??
          (json['arguments'] as Map<String, dynamic>?) ??
          {};
    }

    // Preserve extra_content (Gemini thought_signature lives here)
    final extraContent = json['extra_content'] as Map<String, dynamic>?;

    return ToolCall(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'function',
      name: name,
      arguments: arguments,
      extraContent: extraContent,
    );
  }

  /// Serialize to OpenAI tool_calls format.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type,
      'function': {
        'name': name,
        'arguments': jsonEncode(arguments),
      },
    };
    // Echo back extra_content (required by Gemini 3.x for thought_signature)
    if (extraContent != null) {
      json['extra_content'] = extraContent;
    }
    return json;
  }
}

/// Response from an LLM provider.
class LLMResponse {
  final String content;
  final List<ToolCall> toolCalls;
  final String finishReason;
  final UsageInfo? usage;

  const LLMResponse({
    required this.content,
    this.toolCalls = const [],
    required this.finishReason,
    this.usage,
  });
}

/// Token usage information.
class UsageInfo {
  final int promptTokens;
  final int completionTokens;

  int get totalTokens => promptTokens + completionTokens;

  const UsageInfo({
    required this.promptTokens,
    required this.completionTokens,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) => UsageInfo(
        promptTokens: json['prompt_tokens'] as int? ??
            json['input_tokens'] as int? ??
            0,
        completionTokens: json['completion_tokens'] as int? ??
            json['output_tokens'] as int? ??
            0,
      );
}

/// Definition of a tool available to the LLM.
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// Serialize to OpenAI tools format.
  Map<String, dynamic> toOpenAIJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };

  /// Serialize to Anthropic tools format.
  Map<String, dynamic> toAnthropicJson() => {
        'name': name,
        'description': description,
        'input_schema': parameters,
      };
}
