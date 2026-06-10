import 'package:droidclaw/core/providers/llm_provider.dart';
import 'package:droidclaw/core/providers/llm_response.dart';

/// A scripted [LLMProvider] for tests.
///
/// Returns queued responses in order (repeating the last once the queue is
/// exhausted) and records the messages it received so tests can assert on the
/// request side — e.g. that query expansion did or did not fire, or that a
/// language tag was appended to the last user message.
class FakeLLMProvider implements LLMProvider {
  final List<LLMResponse> _responses;

  /// The `messages` argument captured on each [chat] call, in order.
  final List<List<Message>> receivedMessages = [];

  int callCount = 0;

  FakeLLMProvider(this._responses)
      : assert(_responses.isNotEmpty, 'provide at least one response');

  /// Always returns a single text response.
  factory FakeLLMProvider.text(String content) =>
      FakeLLMProvider([textResponse(content)]);

  @override
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  }) async {
    callCount++;
    receivedMessages.add(List.of(messages));
    return callCount <= _responses.length
        ? _responses[callCount - 1]
        : _responses.last;
  }

  @override
  String get defaultModel => 'fake-model';

  @override
  String get providerName => 'fake';
}

/// A tool-call response (`finishReason: 'tool_calls'`).
LLMResponse toolCallResponse(
  String name,
  Map<String, dynamic> arguments, {
  String id = 'call_1',
}) =>
    LLMResponse(
      content: '',
      toolCalls: [ToolCall(id: id, name: name, arguments: arguments)],
      finishReason: 'tool_calls',
    );

/// A final text response (`finishReason: 'stop'`).
LLMResponse textResponse(String content) =>
    LLMResponse(content: content, finishReason: 'stop');
