import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/telegram/telegram_api.dart';
import '../features/telegram/telegram_bot_manager.dart';
import '../features/telegram/telegram_task_handler.dart';
import '../shared/constants.dart';
import 'app_providers.dart';

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

/// Manages Telegram bot lifecycle, foreground service, and message routing.
class TelegramNotifier extends Notifier<TelegramState> {
  TelegramBotManager? _botManager;

  @override
  TelegramState build() {
    ref.onDispose(() {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      _botManager?.dispose();
    });

    // Register callback for data from TaskHandler isolate
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Check if service is already running
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
      final isRunning = await FlutterForegroundTask.isRunningService;
      state = state.copyWith(
        isEnabled: true,
        isRunning: isRunning,
      );

      if (isRunning) {
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

      // Initialize foreground task
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'droidclaw_telegram_bot',
          channelName: 'DroidClaw Telegram Bot',
          channelDescription:
              'Notification for the Telegram bot foreground service',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          // Poll every 1 second — actual blocking is done by long poll timeout
          eventAction: ForegroundTaskEventAction.repeat(1000),
          autoRunOnBoot: true,
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      // Request notification permission
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Start the service
      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'DroidClaw Bot - Starting...',
        notificationText: 'Connecting to Telegram...',
        notificationButtons: [
          const NotificationButton(id: 'btn_stop', text: 'Stop'),
        ],
        callback: telegramServiceCallback,
      );

      if (result is ServiceRequestFailure) {
        state = state.copyWith(
          error: 'Failed to start service: ${result.error}',
        );
        return;
      }

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

  /// Disable the Telegram bot and stop the foreground service.
  Future<void> disable() async {
    await FlutterForegroundTask.stopService();

    final storage = ref.read(storageServiceProvider);
    await storage.setBool(AppConstants.telegramBotEnabledKey, false);

    _botManager?.dispose();
    _botManager = null;

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

    _botManager = TelegramBotManager(agentLoop: agentLoop);
    _botManager!.onEvent = _onBotEvent;

    // Load allowed users
    final storage = ref.read(storageServiceProvider);
    final allowedUsersStr =
        storage.getString(AppConstants.telegramAllowedUsersKey);
    if (allowedUsersStr != null) {
      _botManager!.setAllowedUsers(_parseAllowedUsers(allowedUsersStr));
    }
  }

  /// Handle data received from the TaskHandler isolate.
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

      case 'started':
        state = state.copyWith(isRunning: true, clearError: true);

      case 'stopped':
        state = state.copyWith(isRunning: false);

      case 'error':
        state = state.copyWith(
          error: map['message'] as String?,
          isRunning: false,
        );

      case 'stop_requested':
        disable();

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
