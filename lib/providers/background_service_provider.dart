import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/agent/agent_loop.dart';
import '../core/config/log_entry.dart';
import '../core/config/service_secret_cache.dart';
import '../core/services/app_logger.dart';
import '../core/services/background_task_handler.dart';
import '../core/session/isolate_persistence/durable_trigger_queue.dart';
import '../l10n/l10n.dart';
import '../shared/constants.dart';
import 'app_providers.dart';

/// Background service state.
class BackgroundServiceState {
  final bool isRunning;
  final String? error;
  final int cronCompletionCount;

  const BackgroundServiceState({
    this.isRunning = false,
    this.error,
    this.cronCompletionCount = 0,
  });

  BackgroundServiceState copyWith({
    bool? isRunning,
    String? error,
    bool clearError = false,
    int? cronCompletionCount,
  }) =>
      BackgroundServiceState(
        isRunning: isRunning ?? this.isRunning,
        error: clearError ? null : (error ?? this.error),
        cronCompletionCount: cronCompletionCount ?? this.cronCompletionCount,
      );
}

/// Manages the foreground service lifecycle and cron execution.
/// Decoupled from Telegram — any feature that needs the background service
/// (crons, Telegram, future services) goes through this notifier.
class BackgroundServiceNotifier extends Notifier<BackgroundServiceState> {
  @override
  BackgroundServiceState build() {
    ref.onDispose(() {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    });

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _checkInitialState();

    return const BackgroundServiceState();
  }

  Future<void> _checkInitialState() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      state = state.copyWith(isRunning: true);
      // Refresh cached secrets so service isolate stays up-to-date
      await _cacheSecretsForService();
    }

    // Check for pending cron triggers (queued while main isolate was dead)
    await _processPendingCronTriggers();
  }

  /// Ensure the foreground service is running.
  /// Called when crons are saved or Telegram is enabled.
  Future<void> ensureServiceRunning() async {
    // Cache secrets so the service isolate can init its own AgentLoop
    await _cacheSecretsForService();

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      // Just reload cron definitions in the task handler
      FlutterForegroundTask.sendDataToTask({'action': 'reload_crons'});
      return;
    }

    // Start the service
    final config = ref.read(appConfigProvider);
    final l = tr(config.resolvedLocale);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'droidclaw_background_service',
        channelName: l.notifChannelName,
        channelDescription: l.notifChannelDesc,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      // Both types are genuinely used by the service isolate (U6 review):
      // remoteMessaging = Telegram long-polling; location = get_location /
      // get_address tools registered in ServiceAgentFactory for cron tasks.
      serviceTypes: [
        ForegroundServiceTypes.remoteMessaging,
        ForegroundServiceTypes.location,
      ],
      notificationTitle: l.notifServiceActive,
      notificationText: l.notifServiceRunning,
      notificationButtons: [],
      callback: backgroundServiceCallback,
    );

    if (result is ServiceRequestFailure) {
      state = state.copyWith(
        error: 'Failed to start service: ${result.error}',
      );
      return;
    }

    state = state.copyWith(isRunning: true);
  }

  /// Stop the service if nothing needs it (no crons, no Telegram, no wake
  /// word). The wake word is a first-class service consumer: toggling Telegram
  /// or cron off must NOT kill an active wake word listener, and disabling the
  /// wake word with no other consumer stops the service cleanly.
  ///
  /// Note: the wake word uses its OWN dedicated microphone foreground service
  /// (separate from this flutter_foreground_task service — see
  /// AndroidManifest WakeWordService). The accounting here keeps the shared
  /// service alive while the wake word is enabled so the two services have a
  /// consistent "is any background feature on" view; the dedicated mic service
  /// is managed by the wake word controller itself.
  Future<void> stopServiceIfIdle() async {
    final configStorage = ref.read(configStorageProvider);
    final storage = ref.read(storageServiceProvider);

    final crons = configStorage.getCronDefinitions();
    final hasActiveCrons = crons.any((c) => c.enabled);
    final telegramEnabled =
        storage.getBool(AppConstants.telegramBotEnabledKey) ?? false;
    final wakeWordEnabled = ref.read(appConfigProvider).voice.wakeWordEnabled;

    if (!hasServiceConsumer(
      hasActiveCrons: hasActiveCrons,
      telegramEnabled: telegramEnabled,
      wakeWordEnabled: wakeWordEnabled,
    )) {
      await FlutterForegroundTask.stopService();
      state = state.copyWith(isRunning: false);
    }
  }

  /// Whether ANY feature still needs the shared foreground service. Pure
  /// predicate so the consumer accounting (incl. the wake word as a
  /// first-class consumer) is unit-testable without platform channels.
  static bool hasServiceConsumer({
    required bool hasActiveCrons,
    required bool telegramEnabled,
    required bool wakeWordEnabled,
  }) =>
      hasActiveCrons || telegramEnabled || wakeWordEnabled;

  /// Refresh the SharedPreferences cache the service isolate reads at init.
  /// Secrets are only mirrored when the service isolate's capability probe
  /// showed it cannot read FlutterSecureStorage directly — see
  /// [ServiceSecretCache.refresh].
  Future<void> _cacheSecretsForService() async {
    try {
      final storage = ref.read(storageServiceProvider);
      await ServiceSecretCache.refresh(
        prefs: ref.read(sharedPreferencesProvider),
        configStorage: ref.read(configStorageProvider),
        config: ref.read(appConfigProvider),
        workspacePath: await storage.workspacePath,
      );
    } catch (e) {
      // Non-critical — service isolate will fall back to pending queue
      AppLogger.instance.warning(LogSource.service,
          'Failed to cache secrets for service: $e');
    }
  }

  /// Handle data received from the TaskHandler isolate (cron-related only).
  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final type = map['type'] as String?;

    switch (type) {
      case 'started':
        state = state.copyWith(isRunning: true, clearError: true);

      case 'stopped':
        state = state.copyWith(isRunning: false);

      case 'cron_trigger':
        // Remove from pending queue (we're handling it now via main isolate)
        _removePendingTrigger(map['cron_id'] as String);
        _handleCronTrigger(map);

      case 'cron_completed':
        // Service isolate executed the cron autonomously
        AppLogger.instance.info(LogSource.cron,
            'Service isolate completed "${map['cron_name']}" '
            '(${map['response_length']} chars)',
            cronId: map['cron_id'] as String?);
        // Reload SharedPreferences (service isolate wrote lastRun) and
        // bump counter so CronConfigScreen can react via ref.watch().
        _reloadAfterCronCompletion();

      case 'backfill_complete':
        // The service isolate finished the charger-gated embedding backfill
        // and the KB coverage flipped to the new embedding space. The main
        // isolate's long-lived KnowledgeService caches its own query-space
        // selection and would keep serving the stale/lexical space until app
        // restart — invalidate it (mirrors the cron-completion refresh) so
        // chat picks up the new embedding space on the next query.
        AppLogger.instance.info(LogSource.service,
            'Service isolate reported embedding backfill complete — '
            'refreshing main-isolate knowledge service');
        _refreshKnowledgeServiceAfterBackfill();

      case 'service_error':
        // Service isolate could not initialize its AgentLoop (e.g. missing
        // cached config). Surface it so the UI does not show a healthy
        // service while crons silently never fire.
        final message = map['message'] as String?;
        AppLogger.instance.warning(LogSource.service,
            'Service isolate reported init failure: $message');
        state = state.copyWith(error: message);

    }
  }

  /// Invalidate the long-lived main-isolate KnowledgeService so its cached
  /// query-space selection is recomputed against the now-complete embedding
  /// space written by the service isolate's backfill (A1). Invalidating the
  /// provider (rather than calling a refresh hook) keeps the cross-isolate
  /// signal handling entirely in this file.
  void _refreshKnowledgeServiceAfterBackfill() {
    try {
      ref.invalidate(knowledgeServiceProvider);
    } catch (e) {
      AppLogger.instance.warning(LogSource.service,
          'Failed to refresh knowledge service after backfill: $e');
    }
  }

  /// Reload SharedPreferences after the service isolate updated lastRun,
  /// then bump cronCompletionCount so the UI rebuilds.
  Future<void> _reloadAfterCronCompletion() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.reload();
      // Refresh the session metadata index so the cron session written by
      // the service isolate appears in list screens. With sessions.db (WAL)
      // the row itself is already readable by a plain get() — this only
      // rebuilds the in-memory index (cheap, no close/reopen).
      final sm = await ref.read(sessionManagerProvider.future);
      await sm.reload();
      state = state.copyWith(
          cronCompletionCount: state.cronCompletionCount + 1);
    } catch (e) {
      AppLogger.instance.error(LogSource.service,
          'Failed to reload after cron completion: $e');
    }
  }

  /// Remove a trigger from the pending queue.
  void _removePendingTrigger(String cronId) {
    final storage = ref.read(storageServiceProvider);
    final raw = storage.getString(AppConstants.cronPendingTriggersKey);
    if (raw == null) return;
    try {
      final pending = DurableTriggerQueue.removeByCronId(
          DurableTriggerQueue.decode(raw), cronId);
      if (pending.isEmpty) {
        storage.remove(AppConstants.cronPendingTriggersKey);
      } else {
        storage.setString(AppConstants.cronPendingTriggersKey,
            DurableTriggerQueue.encode(pending));
      }
    } catch (e) {
      // A corrupt queue blob is not recoverable here; the trigger already
      // ran, so leaving the stale entry only risks one duplicate execution.
      AppLogger.instance.warning(LogSource.cron,
          'Failed to remove pending trigger $cronId: ${e.runtimeType}');
    }
  }

  /// Process pending cron triggers that were queued while the main isolate
  /// was dead (app killed by Android overnight).
  Future<void> _processPendingCronTriggers() async {
    final storage = ref.read(storageServiceProvider);
    final raw = storage.getString(AppConstants.cronPendingTriggersKey);
    if (raw == null) return;

    try {
      final pending = DurableTriggerQueue.decode(raw);
      if (pending.isEmpty) return;

      AppLogger.instance.info(LogSource.cron,
          'Found ${pending.length} pending cron trigger(s), executing...');

      for (final trigger in pending) {
        await _handleCronTrigger(trigger);
      }

      // Clear pending queue after processing
      storage.remove(AppConstants.cronPendingTriggersKey);
      AppLogger.instance.info(LogSource.cron, 'All pending triggers processed');
    } catch (e) {
      AppLogger.instance.error(LogSource.cron,
          'ERROR processing pending triggers: $e');
    }
  }

  /// Execute a cron-triggered prompt via AgentLoop.
  Future<void> _handleCronTrigger(Map<String, dynamic> data) async {
    final cronId = data['cron_id'] as String;
    final cronName = data['cron_name'] as String? ?? cronId;
    final prompt = data['prompt'] as String;
    final strategy = data['session_strategy'] as String;

    AppLogger.instance.info(LogSource.cron,
        'Executing "$cronName" (strategy=$strategy)', cronId: cronId);

    final agentLoop = await ref.read(agentLoopProvider.future);
    if (agentLoop == null) {
      AppLogger.instance.error(LogSource.cron,
          'AgentLoop is null (no LLM provider configured?)');
      return;
    }

    final sessionKey = strategy == 'sameThread'
        ? '${AppConstants.cronSessionPrefix}$cronId'
        : '${AppConstants.cronSessionPrefix}${cronId}_${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.instance.debug(LogSource.cron,
        'Session key: $sessionKey', cronId: cronId);

    try {
      await for (final event in agentLoop.processMessage(prompt, sessionKey)) {
        if (event is ResponseEvent) {
          AppLogger.instance.info(LogSource.cron,
              'Completed "$cronName" (${event.content.length} chars)',
              cronId: cronId, sessionKey: sessionKey);
          break;
        } else if (event is ErrorEvent) {
          AppLogger.instance.error(LogSource.cron,
              'ERROR in "$cronName": ${event.message}',
              cronId: cronId, sessionKey: sessionKey);
          break;
        }
      }

      // Save session
      final sessions = await ref.read(sessionManagerProvider.future);
      final session = sessions.get(sessionKey);
      if (session != null) {
        await sessions.save(session);
        AppLogger.instance.debug(LogSource.cron,
            'Session saved for "$cronName"');
      } else {
        AppLogger.instance.warning(LogSource.cron,
            'No session found for key $sessionKey');
      }

      // Notify task handler that cron is done
      FlutterForegroundTask.sendDataToTask({
        'action': 'cron_done',
        'cron_id': cronId,
      });
    } catch (e) {
      AppLogger.instance.error(LogSource.cron,
          'EXCEPTION in "$cronName": $e', cronId: cronId);
    }
  }
}

/// Background service provider.
final backgroundServiceProvider =
    NotifierProvider<BackgroundServiceNotifier, BackgroundServiceState>(
        BackgroundServiceNotifier.new);
