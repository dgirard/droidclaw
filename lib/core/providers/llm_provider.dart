import 'llm_response.dart';

/// Abstract interface for LLM providers.
abstract class LLMProvider {
  /// Send a chat request to the LLM.
  Future<LLMResponse> chat({
    required List<Message> messages,
    List<ToolDefinition>? tools,
    required String model,
    Map<String, dynamic>? options,
  });

  /// The default model for this provider.
  String get defaultModel;

  /// Provider name identifier.
  String get providerName;
}
