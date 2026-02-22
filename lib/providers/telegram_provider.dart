import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/telegram/telegram_api.dart';
import '../features/telegram/telegram_bot_manager.dart';
import '../shared/constants.dart';
import 'app_providers.dart';
import 'background_service_provider.dart';

/// Telegram bot state.
class TelegramState {
  final bool isEnabled;
  final bool isRunning;
  final String? botUsername;
  final int messageCount;
  final DateTime? lastMessageTime;
  final String? error;

  const TelegramState({
    this.isEnabled = false,
    this.isRunning = false,
    this.botUsername,
    this.messageCount = 0,
    this.lastMessageTime,
    this.error,
  });

  TelegramState copyWith({
    bool? isEnabled,
    bool? isRunning,
    String? botUsername,
    int? messageCount,
    DateTime? lastMessageTime,
    String? error,
    bool clearError = false,
  }) =>
      TelegramState(
        isEnabled: isEnabled ?? this.isEnabled,
        isRunning: isRunning ?? this.isRunning,
        botUsername: botUsername ?? this.botUsername,
        messageCount: messageCount ?? this.messageCount,
        lastMessageTime: lastMessageTime ?? this.lastMessageTime,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Manages Telegram bot lifecycle and message routing.
/// Delegates foreground service lifecycle to BackgroundServiceNotifier.
class TelegramNotifier extends Notifier<TelegramState> {
  TelegramBotManager? _botManager;

  @override
  TelegramState build() {
    ref.onDispose(() {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      _botManager?.dispose();
    });

    // Register callback for Telegram-specific data from TaskHandler isolate
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Check if already enabled
    _checkInitialState();

    return const TelegramState();
  }

  Future<void> _checkInitialState() async {
    final storage = ref.read(storageServiceProvider);
    final token =
        await storage.getSecure(AppConstants.telegramBotTokenKey);
    final enabled =
        storage.getBool(AppConstants.telegramBotEnabledKey) ?? false;

    if (token != null && token.isNotEmpty && enabled) {
      final bgState = ref.read(backgroundServiceProvider);
      state = state.copyWith(
        isEnabled: true,
        isRunning: bgState.isRunning,
      );

      if (bgState.isRunning) {
        await _initBotManager();
      }
    }
  }

  /// Test bot token by calling getMe.
  Future<String> testConnection(String token) async {
    final api = TelegramApi(token: token);
    try {
      final me = await api.getMe();
      final username = me['username'] as String? ?? 'unknown';
      state = state.copyWith(botUsername: username);
      return username;
    } finally {
      api.close();
    }
  }

  /// Enable the Telegram bot and start the foreground service.
  Future<void> enable(String token) async {
    state = state.copyWith(clearError: true);

    try {
      // Validate token first
      final api = TelegramApi(token: token);
      try {
        final me = await api.getMe();
        state = state.copyWith(
          botUsername: me['username'] as String?,
        );
      } finally {
        api.close();
      }

      // Save token and enabled state
      final storage = ref.read(storageServiceProvider);
      await storage.setSecure(AppConstants.telegramBotTokenKey, token);
      await storage.setBool(AppConstants.telegramBotEnabledKey, true);

      // Delegate service start to BackgroundServiceNotifier
      final bgService = ref.read(backgroundServiceProvider.notifier);
      await bgService.ensureServiceRunning();

      await _initBotManager();

      state = state.copyWith(
        isEnabled: true,
        isRunning: true,
      );
    } on TelegramApiException catch (e) {
      state = state.copyWith(error: 'Telegram API error: $e');
    } catch (e) {
      state = state.copyWith(error: 'Failed to start bot: $e');
    }
  }

  /// Disable the Telegram bot.
  /// The background service will stop only if no crons need it.
  Future<void> disable() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setBool(AppConstants.telegramBotEnabledKey, false);

    _botManager?.dispose();
    _botManager = null;

    // Ask BackgroundService to stop if nothing else needs it
    final bgService = ref.read(backgroundServiceProvider.notifier);
    await bgService.stopServiceIfIdle();

    state = state.copyWith(
      isEnabled: false,
      isRunning: false,
      clearError: true,
    );
  }

  /// Update allowed users list.
  Future<void> setAllowedUsers(String usersStr) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setString(AppConstants.telegramAllowedUsersKey, usersStr);

    final users = _parseAllowedUsers(usersStr);
    _botManager?.setAllowedUsers(users);
  }

  /// Initialize the bot manager for message processing.
  Future<void> _initBotManager() async {
    final agentLoop = await ref.read(agentLoopProvider.future);
    if (agentLoop == null) {
      state = state.copyWith(
        error: 'No LLM provider configured',
      );
      return;
    }

    final config = ref.read(appConfigProvider);
    _botManager = TelegramBotManager(
      agentLoop: agentLoop,
      locale: config.resolvedLocale,
    );
    _botManager!.onEvent = _onBotEvent;

    // Load allowed users
    final storage = ref.read(storageServiceProvider);
    final allowedUsersStr =
        storage.getString(AppConstants.telegramAllowedUsersKey);
    if (allowedUsersStr != null) {
      _botManager!.setAllowedUsers(_parseAllowedUsers(allowedUsersStr));
    }
  }

  /// Handle data received from the TaskHandler isolate (Telegram-specific only).
  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final type = map['type'] as String?;

    switch (type) {
      case 'message':
        // Forward to bot manager for AgentLoop processing
        _botManager?.handleIncomingMessage(
          chatId: map['chat_id'] as int,
          text: map['text'] as String,
          username: map['username'] as String?,
          updateId: map['update_id'] as int,
        );

      case 'error':
        state = state.copyWith(
          error: map['message'] as String?,
          isRunning: false,
        );

      case 'send_error':
        // Log but don't stop the bot
        state = state.copyWith(
          error: map['message'] as String?,
        );
    }
  }

  /// Handle events from the bot manager for stats tracking.
  void _onBotEvent(TelegramBotEvent event) {
    switch (event) {
      case MessageReceivedEvent():
        state = state.copyWith(
          messageCount: state.messageCount + 1,
          lastMessageTime: DateTime.now(),
        );
      case ResponseSentEvent():
        break;
      case AccessDeniedEvent():
        break;
      case BotErrorEvent():
        state = state.copyWith(error: event.message);
    }
  }

  Set<String> _parseAllowedUsers(String usersStr) {
    return usersStr
        .split(',')
        .map((u) => u.trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toSet();
  }
}

/// Telegram bot state provider.
final telegramProvider =
    NotifierProvider<TelegramNotifier, TelegramState>(TelegramNotifier.new);
