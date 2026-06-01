import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../agent/agent_loop.dart';
import '../agent/service_agent_factory.dart';
import '../config/cron_config.dart';
import '../config/log_entry.dart';
import '../../shared/constants.dart';
import '../../features/telegram/telegram_api.dart';
import '../session/isolate_persistence/durable_trigger_queue.dart';
import '../session/isolate_persistence/hive_path_resolver.dart';
import 'app_logger.dart';
import 'llm_trace_logger.dart';

/// Top-level callback for the foreground service isolate.
/// Must be a top-level function with @pragma to survive tree-shaking.
@pragma('vm:entry-point')
void backgroundServiceCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundTaskHandler());
}

/// Runs in the foreground service isolate.
///
/// Responsibilities:
/// - Checks cron schedules and executes them via autonomous AgentLoop
/// - Long-polls Telegram for new messages via getUpdates
/// - Forwards incoming messages to main isolate via sendDataToMain
/// - Receives responses from main isolate and sends them to Telegram
/// - Persists update offset across restarts
/// - Implements exponential backoff on failures
class BackgroundTaskHandler extends TaskHandler {
  // Telegram
  TelegramApi? _api;
  int _offset = 0;
  int _consecutiveFailures = 0;
  int _messageCount = 0;
  bool _polling = false;

  // Cron scheduling
  List<CronDefinition> _cronDefinitions = [];
  int _cronCheckCounter = 14; // Start high to trigger check on first event
  static const _cronCheckIntervalSeconds = 15;

  // Autonomous AgentLoop for direct cron execution in service isolate
  AgentLoop? _agentLoop;
  bool _agentInitializing = false;
  bool _cronExecuting = false;
  String _locale = 'en';

  // Log purge: every 6 hours (6 * 3600 = 21600 seconds)
  int _purgeCounter = 0;
  static const _purgeIntervalSeconds = 21600;

  // Knowledge Graph maintenance (reuses AgentLoop's KnowledgeService instance)
  int _kgDecayCounter = 0;
  static const _kgDecayIntervalSeconds = 3600; // hourly
  int _kgPurgeCounter = 0;
  static const _kgPurgeIntervalSeconds = 86400; // daily

  static const _maxBackoff = Duration(seconds: 60);
  static const _baseBackoff = Duration(seconds: 2);
  static const _disconnectedThreshold = 10;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final prefs = await SharedPreferences.getInstance();

    // Receive bot token from init data or stored prefs
    final token = prefs.getString(AppConstants.telegramBotTokenKey);
    if (token != null && token.isNotEmpty) {
      _api = TelegramApi(token: token);
    }

    // Restore persisted offset
    _offset = prefs.getInt(AppConstants.telegramBotOffsetKey) ?? 0;

    // Load locale
    _locale = prefs.getString(AppConstants.cachedLocaleKey) ?? 'en';

    // Initialize logger for service isolate
    final workspacePath = prefs.getString(AppConstants.cachedWorkspacePathKey);
    if (workspacePath != null) {
      final appDir = HivePathResolver.hiveDirFromWorkspace(workspacePath);
      AppLogger.init(dirPath: appDir, isolateName: 'service');
      await AppLogger.instance.purge();

      LlmTraceLogger.init(dirPath: appDir, isolateName: 'service');
      await LlmTraceLogger.instance.purge();
    }

    // Load cron definitions
    _loadCronDefinitions(prefs);
    AppLogger.instance.info(LogSource.service,
        'TaskHandler started: ${_cronDefinitions.length} crons loaded, '
        'telegram=${_api != null}');

    // Initialize AgentLoop for autonomous cron execution
    // (AgentLoop also initializes KnowledgeService if KG is enabled,
    //  which we reuse for maintenance tasks — no separate DB instance)
    _initAgentLoop(prefs);

    FlutterForegroundTask.sendDataToMain({
      'type': 'started',
      'timestamp': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Check crons every ~15 seconds (counter increments every 1s)
    _cronCheckCounter++;
    if (_cronCheckCounter >= _cronCheckIntervalSeconds) {
      _cronCheckCounter = 0;
      // Use DateTime.now() (local time) instead of timestamp (may be UTC)
      await _checkCrons(DateTime.now());
    }

    // Purge old logs every 6 hours
    _purgeCounter++;
    if (_purgeCounter >= _purgeIntervalSeconds) {
      _purgeCounter = 0;
      if (AppLogger.isInitialized) {
        await AppLogger.instance.purge();
      }
      if (LlmTraceLogger.isInitialized) {
        await LlmTraceLogger.instance.purge();
      }
    }

    // KG decay recalculation every hour
    if (_agentLoop?.knowledgeService != null) {
      _kgDecayCounter++;
      if (_kgDecayCounter >= _kgDecayIntervalSeconds) {
        _kgDecayCounter = 0;
        _runKgDecay();
      }

      // KG cold entity purge every 24 hours
      _kgPurgeCounter++;
      if (_kgPurgeCounter >= _kgPurgeIntervalSeconds) {
        _kgPurgeCounter = 0;
        _runKgPurge();
      }
    }

    // Telegram polling — fire and forget (non-blocking)
    // The _polling flag prevents concurrent polls.
    if (_api != null && !_polling) {
      _pollTelegram();
    }
  }

  /// Long-polls Telegram for updates. Runs independently of onRepeatEvent
  /// so the 30-second HTTP timeout doesn't block cron counter increments.
  Future<void> _pollTelegram() async {
    _polling = true;

    try {
      final updates = await _api!.getUpdates(
        offset: _offset > 0 ? _offset : null,
        timeout: AppConstants.telegramPollTimeout,
      );

      // Reset backoff on success
      _consecutiveFailures = 0;

      for (final update in updates) {
        // Skip empty messages
        if (update.text.isEmpty) {
          _offset = update.updateId + 1;
          continue;
        }

        // Forward to main isolate for AgentLoop processing
        FlutterForegroundTask.sendDataToMain({
          'type': 'message',
          'update_id': update.updateId,
          'chat_id': update.chatId,
          'user_id': update.userId,
          'username': update.username,
          'text': update.text,
          'date': update.date.millisecondsSinceEpoch,
        });

        _offset = update.updateId + 1;
        _messageCount++;
      }

      // Persist offset
      if (updates.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(AppConstants.telegramBotOffsetKey, _offset);
      }

      // Update notification
      final l = tr(_locale);
      FlutterForegroundTask.updateService(
        notificationTitle: l.notifBotActive,
        notificationText: l.notifBotMessages(_messageCount),
      );
    } on TelegramRateLimitException catch (e) {
      // Respect Telegram's retry-after
      await Future.delayed(Duration(seconds: e.retryAfter));
    } on TelegramApiException catch (e) {
      _consecutiveFailures++;

      if (e.isUnauthorized) {
        // Invalid token — stop polling, notify main isolate
        FlutterForegroundTask.sendDataToMain({
          'type': 'error',
          'message': 'Invalid bot token (401 Unauthorized)',
        });
        FlutterForegroundTask.updateService(
          notificationTitle: tr(_locale).notifBotError,
          notificationText: tr(_locale).notifBotInvalidToken,
        );
        _api = null; // Stop polling
        return;
      }

      await _backoff();
    } catch (e) {
      _consecutiveFailures++;
      await _backoff();
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> onReceiveData(Object data) async {
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final action = map['action'] as String?;

    if (action == 'send') {
      if (_api == null) return;
      final chatId = map['chat_id'] as int;
      final text = map['text'] as String;

      try {
        await _api!.sendMessage(chatId, text);
      } on TelegramRateLimitException catch (e) {
        await Future.delayed(Duration(seconds: e.retryAfter));
        try {
          await _api!.sendMessage(chatId, text);
        } catch (_) {
          // Give up after retry
        }
      } catch (e) {
        FlutterForegroundTask.sendDataToMain({
          'type': 'send_error',
          'chat_id': chatId,
          'message': 'Failed to send message: $e',
        });
      }
    } else if (action == 'update_token') {
      final token = map['token'] as String;
      _api = TelegramApi(token: token);
      _offset = 0;
      _consecutiveFailures = 0;
    } else if (action == 'reload_crons') {
      // SharedPreferences may be stale in this isolate — reload from disk
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _loadCronDefinitions(prefs);
      AppLogger.instance.info(LogSource.service,
          'Reloaded crons: ${_cronDefinitions.length} definitions, '
          'schedules: ${_cronDefinitions.map((c) => '${c.name}:${c.schedule.type.name}').join(', ')}');
      // Re-init AgentLoop if config may have changed
      if (_agentLoop == null) {
        _initAgentLoop(prefs);
      }
    } else if (action == 'cron_done') {
      // Update lastRun for the cron after main isolate finishes execution
      final cronId = map['cron_id'] as String;
      final prefs = await SharedPreferences.getInstance();
      _updateCronLastRun(cronId, DateTime.now(), prefs);
      // Remove from pending queue
      _removePendingTrigger(prefs, cronId);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Persist final offset
    if (_offset > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.telegramBotOffsetKey, _offset);
    }

    _api?.close();
    _api = null;

    FlutterForegroundTask.sendDataToMain({
      'type': 'stopped',
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isTimeout': isTimeout,
    });
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    // No buttons — service is managed from the app UI
  }

  @override
  Future<void> onNotificationPressed() async {
    FlutterForegroundTask.sendDataToMain({
      'type': 'open_app',
    });
  }

  @override
  Future<void> onNotificationDismissed() async {
    // No-op: notification is persistent for foreground service
  }

  // --- Knowledge Graph maintenance ---

  Future<void> _runKgDecay() async {
    try {
      final changed = await _agentLoop!.knowledgeService!.recalculateDecay();
      if (changed > 0) {
        AppLogger.instance.info(LogSource.service,
            'KG decay: $changed entity temperatures updated');
      }
    } catch (e) {
      AppLogger.instance.warning(LogSource.service,
          'KG decay failed: $e');
    }
  }

  Future<void> _runKgPurge() async {
    try {
      final cutoff = DateTime.now()
              .subtract(Duration(days: AppConstants.knowledgeDecayHalfLifeDays))
              .millisecondsSinceEpoch ~/
          1000;
      final purged = await _agentLoop!.knowledgeService!.db.purgeColdEntities(cutoff);
      if (purged > 0) {
        AppLogger.instance.info(LogSource.service,
            'KG purge: $purged cold entities deactivated');
      }
    } catch (e) {
      AppLogger.instance.warning(LogSource.service,
          'KG purge failed: $e');
    }
  }

  // --- Autonomous AgentLoop ---

  Future<void> _initAgentLoop(SharedPreferences prefs) async {
    if (_agentInitializing || _agentLoop != null) return;
    _agentInitializing = true;

    try {
      await prefs.reload();
      final apiKey = prefs.getString(AppConstants.cachedApiKeyKey);
      final providerName = prefs.getString(AppConstants.cachedProviderNameKey);
      final workspacePath = prefs.getString(AppConstants.cachedWorkspacePathKey);

      if (apiKey == null || providerName == null || workspacePath == null) {
        AppLogger.instance.warning(LogSource.service,
            'Cannot init AgentLoop: missing cached config '
            '(apiKey=${apiKey != null}, provider=${providerName != null}, '
            'workspace=${workspacePath != null})');
        return;
      }

      // Derive Hive path via the shared resolver: the service isolate must use
      // the same directory the main isolate's Hive.initFlutter() uses.
      final hivePath = HivePathResolver.hiveDirFromWorkspace(workspacePath);

      _agentLoop = await ServiceAgentFactory.create(
        prefs: prefs,
        apiKey: apiKey,
        providerName: providerName,
        workspacePath: workspacePath,
        hivePath: hivePath,
        braveApiKey: prefs.getString(AppConstants.cachedBraveApiKeyKey),
        orsApiKey: prefs.getString(AppConstants.cachedOrsApiKeyKey),
        sncfApiKey: prefs.getString(AppConstants.cachedSncfApiKeyKey),
        primApiKey: prefs.getString(AppConstants.cachedPrimApiKeyKey),
        locale: prefs.getString(AppConstants.cachedLocaleKey) ?? 'en',
        kbLanguage: prefs.getString(AppConstants.cachedKbLanguageKey),
        embeddingApiKey:
            prefs.getString(AppConstants.cachedEmbeddingApiKeyKey),
        embeddingProvider:
            prefs.getString(AppConstants.cachedEmbeddingProviderKey) ?? '',
        embeddingModel:
            prefs.getString(AppConstants.cachedEmbeddingModelKey) ?? '',
        embeddingDimensions:
            prefs.getInt(AppConstants.cachedEmbeddingDimensionsKey) ?? 768,
        embeddingApiBase:
            prefs.getString(AppConstants.cachedEmbeddingApiBaseKey) ?? '',
        embeddingUseOwnKey:
            prefs.getBool(AppConstants.cachedEmbeddingUseOwnKeyKey) ?? false,
      );

      AppLogger.instance.info(LogSource.service,
          'AgentLoop initialized in service isolate');
    } catch (e) {
      AppLogger.instance.error(LogSource.service,
          'Failed to init AgentLoop in service: $e');
    } finally {
      _agentInitializing = false;
    }
  }

  Future<void> _executeCronLocally(
      CronDefinition cron, SharedPreferences prefs) async {
    if (_agentLoop == null) return;
    _cronExecuting = true;

    final sessionKey = cron.sessionStrategy == SessionStrategy.sameThread
        ? '${AppConstants.cronSessionPrefix}${cron.id}'
        : '${AppConstants.cronSessionPrefix}${cron.id}_${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.instance.info(LogSource.cron,
        'Executing "${cron.name}" locally (session=$sessionKey)',
        cronId: cron.id, sessionKey: sessionKey);

    try {
      int responseLength = 0;
      await for (final event
          in _agentLoop!.processMessage(cron.prompt, sessionKey)) {
        if (event is ResponseEvent) {
          responseLength = event.content.length;
          AppLogger.instance.info(LogSource.cron,
              'Completed "${cron.name}" ($responseLength chars)',
              cronId: cron.id, sessionKey: sessionKey);
          break;
        } else if (event is ErrorEvent) {
          AppLogger.instance.error(LogSource.cron,
              'ERROR in "${cron.name}": ${event.message}',
              cronId: cron.id, sessionKey: sessionKey);
          break;
        }
      }

      // Save session BEFORE notifying main isolate (avoids race condition
      // where main reloads Hive before session is flushed to disk).
      final session = _agentLoop!.sessions.get(sessionKey);
      if (session != null) {
        await _agentLoop!.sessions.save(session);
        AppLogger.instance.debug(LogSource.cron,
            'Session saved for "${cron.name}"');
      }

      // Notify main isolate of completion (for UI update if app is open)
      FlutterForegroundTask.sendDataToMain({
        'type': 'cron_completed',
        'cron_id': cron.id,
        'cron_name': cron.name,
        'response_length': responseLength,
      });

      // Update notification
      FlutterForegroundTask.updateService(
        notificationTitle: tr(_locale).notifServiceActive,
        notificationText: tr(_locale).notifLastCron(cron.name),
      );
    } catch (e) {
      AppLogger.instance.error(LogSource.cron,
          'EXCEPTION in "${cron.name}": $e',
          cronId: cron.id, sessionKey: sessionKey);
    } finally {
      _cronExecuting = false;
    }
  }

  // --- Cron scheduling ---

  void _loadCronDefinitions(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.cronDefinitionsKey);
    if (raw == null) {
      _cronDefinitions = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _cronDefinitions = list
          .map((e) => CronDefinition.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cronDefinitions = [];
    }
  }

  Future<void> _checkCrons(DateTime now) async {
    AppLogger.instance.debug(LogSource.service,
        'Checking ${_cronDefinitions.length} crons at '
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    for (final cron in _cronDefinitions) {
      if (!cron.enabled) continue;
      final due = _isDue(cron, now);
      final schedInfo = cron.schedule.type == ScheduleType.timeOfDay
          ? 'times=${cron.schedule.times?.map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}').join(',')}'
          : 'interval=${cron.schedule.interval}';
      AppLogger.instance.debug(LogSource.cron,
          '"${cron.name}": due=$due, $schedInfo, lastRun=${cron.lastRun}');
      if (due) {
        AppLogger.instance.info(LogSource.cron,
            'Triggering "${cron.name}"', cronId: cron.id);
        final prefs = await SharedPreferences.getInstance();

        // Immediately update lastRun to prevent re-triggering
        _updateCronLastRun(cron.id, now, prefs);

        if (_agentLoop != null && !_cronExecuting) {
          // Execute directly in service isolate (autonomous mode)
          _executeCronLocally(cron, prefs);
        } else {
          // Fallback: queue for main isolate
          final triggerData = {
            'type': 'cron_trigger',
            'cron_id': cron.id,
            'cron_name': cron.name,
            'prompt': cron.prompt,
            'session_strategy': cron.sessionStrategy.name,
          };
          _addPendingTrigger(prefs, triggerData);
          FlutterForegroundTask.sendDataToMain(triggerData);
          FlutterForegroundTask.launchApp();
        }
      }
    }
  }

  bool _isDue(CronDefinition cron, DateTime now) {
    switch (cron.schedule.type) {
      case ScheduleType.interval:
        if (cron.lastRun == null) return true;
        return now.difference(cron.lastRun!) >= cron.schedule.interval!;
      case ScheduleType.timeOfDay:
        for (final time in cron.schedule.times!) {
          if (now.hour == time.hour && now.minute == time.minute) {
            if (cron.schedule.daysOfWeek != null &&
                !cron.schedule.daysOfWeek!.contains(now.weekday)) {
              continue;
            }
            if (cron.lastRun != null &&
                cron.lastRun!.day == now.day &&
                cron.lastRun!.hour == time.hour &&
                cron.lastRun!.minute == time.minute) {
              continue;
            }
            return true;
          }
        }
        return false;
    }
  }

  /// Add a trigger to the pending queue in SharedPreferences.
  void _addPendingTrigger(
      SharedPreferences prefs, Map<String, dynamic> trigger) {
    final pending = DurableTriggerQueue.enqueue(
      DurableTriggerQueue.decode(
          prefs.getString(AppConstants.cronPendingTriggersKey)),
      trigger,
    );
    prefs.setString(AppConstants.cronPendingTriggersKey,
        DurableTriggerQueue.encode(pending));
    AppLogger.instance.info(LogSource.cron,
        'Queued pending trigger for "${trigger['cron_name']}" '
        '(${pending.length} pending)',
        cronId: trigger['cron_id'] as String?);
  }

  /// Remove a completed trigger from the pending queue.
  void _removePendingTrigger(SharedPreferences prefs, String cronId) {
    final raw = prefs.getString(AppConstants.cronPendingTriggersKey);
    if (raw == null) return;
    final pending = DurableTriggerQueue.removeByCronId(
        DurableTriggerQueue.decode(raw), cronId);
    if (pending.isEmpty) {
      prefs.remove(AppConstants.cronPendingTriggersKey);
    } else {
      prefs.setString(AppConstants.cronPendingTriggersKey,
          DurableTriggerQueue.encode(pending));
    }
    AppLogger.instance.debug(LogSource.cron,
        'Removed pending trigger for $cronId (${pending.length} remaining)');
  }

  void _updateCronLastRun(
      String cronId, DateTime now, SharedPreferences prefs) {
    final index = _cronDefinitions.indexWhere((c) => c.id == cronId);
    if (index < 0) return;
    _cronDefinitions[index] = _cronDefinitions[index].copyWith(lastRun: now);
    // Persist updated definitions
    final json = _cronDefinitions.map((c) => c.toJson()).toList();
    prefs.setString(AppConstants.cronDefinitionsKey, jsonEncode(json));
  }

  /// Exponential backoff on failures.
  Future<void> _backoff() async {
    final delay = _baseBackoff * (1 << (_consecutiveFailures - 1).clamp(0, 5));
    final capped = delay > _maxBackoff ? _maxBackoff : delay;

    if (_consecutiveFailures >= _disconnectedThreshold) {
      FlutterForegroundTask.updateService(
        notificationTitle: tr(_locale).notifBotDisconnected,
        notificationText: tr(_locale).notifBotRetrying,
      );
    }

    await Future.delayed(capped);
  }
}
