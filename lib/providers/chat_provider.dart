import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/agent/agent_loop.dart';
import '../shared/constants.dart';
import 'app_providers.dart';

/// A UI message displayed in the chat.
class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final String? toolName;
  final bool isToolResult;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolName,
    this.isToolResult = false,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.user(String content) => ChatMessage(
        role: 'user',
        content: content,
      );

  factory ChatMessage.assistant(String content) => ChatMessage(
        role: 'assistant',
        content: content,
      );

  factory ChatMessage.toolCall(String name, Map<String, dynamic> args) =>
      ChatMessage(
        role: 'tool',
        content: 'Calling $name...',
        toolName: name,
      );

  factory ChatMessage.toolResult(String name, String content,
          {bool isError = false}) =>
      ChatMessage(
        role: 'tool',
        content: content,
        toolName: name,
        isToolResult: true,
        isError: isError,
      );

  factory ChatMessage.error(String message) => ChatMessage(
        role: 'system',
        content: message,
        isError: true,
      );
}

/// Chat UI state.
class ChatState {
  final String sessionKey;
  final List<ChatMessage> messages;
  final bool isProcessing;
  final AgentEvent? currentEvent;

  const ChatState({
    this.sessionKey = AppConstants.defaultSessionKey,
    this.messages = const [],
    this.isProcessing = false,
    this.currentEvent,
  });

  ChatState copyWith({
    String? sessionKey,
    List<ChatMessage>? messages,
    bool? isProcessing,
    AgentEvent? currentEvent,
    bool clearEvent = false,
  }) =>
      ChatState(
        sessionKey: sessionKey ?? this.sessionKey,
        messages: messages ?? this.messages,
        isProcessing: isProcessing ?? this.isProcessing,
        currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      );
}

/// Chat state notifier — manages the chat UI state and agent interaction.
class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  /// Load existing messages from session.
  Future<void> loadSession(String sessionKey) async {
    final sessions = await ref.read(sessionManagerProvider.future);
    final session = sessions.get(sessionKey);
    if (session != null) {
      final messages = session.messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => m.role == 'user'
              ? ChatMessage.user(m.content)
              : ChatMessage.assistant(m.content))
          .toList();
      state = ChatState(sessionKey: sessionKey, messages: messages);
    } else {
      state = ChatState(sessionKey: sessionKey);
    }
  }

  /// Send a user message and process with the agent.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isProcessing) return;

    final userMessage = ChatMessage.user(text);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isProcessing: true,
    );

    final agentLoop = await ref.read(agentLoopProvider.future);
    if (agentLoop == null) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.error('No LLM provider configured. '
              'Please set up a provider in Settings.'),
        ],
        isProcessing: false,
        clearEvent: true,
      );
      return;
    }

    try {
      await for (final event
          in agentLoop.processMessage(text, state.sessionKey)) {
        switch (event) {
          case ThinkingEvent():
            state = state.copyWith(currentEvent: event);

          case SummarizingEvent():
            state = state.copyWith(currentEvent: event);

          case ToolCallEvent():
            state = state.copyWith(
              messages: [
                ...state.messages,
                ChatMessage.toolCall(event.name, event.arguments),
              ],
              currentEvent: event,
            );

          case ToolResultEvent():
            if (!event.result.silent) {
              state = state.copyWith(
                messages: [
                  ...state.messages,
                  ChatMessage.toolResult(
                    event.name,
                    event.result.forUser,
                    isError: event.result.isError,
                  ),
                ],
                currentEvent: event,
              );
            }

          case ResponseEvent():
            state = state.copyWith(
              messages: [
                ...state.messages,
                ChatMessage.assistant(event.content),
              ],
              isProcessing: false,
              clearEvent: true,
            );

          case ErrorEvent():
            state = state.copyWith(
              messages: [
                ...state.messages,
                ChatMessage.error(event.message),
              ],
              isProcessing: false,
              clearEvent: true,
            );
        }
      }
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.error('Error: $e'),
        ],
        isProcessing: false,
        clearEvent: true,
      );
    }
  }

  /// Start a new session.
  Future<void> newSession() async {
    final sessions = await ref.read(sessionManagerProvider.future);
    final session = sessions.createNew();
    state = ChatState(sessionKey: session.key);
  }
}

/// Chat state provider.
final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
