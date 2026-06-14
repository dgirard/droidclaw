import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/config_storage.dart';
import 'core/services/app_logger.dart';
import 'core/services/llm_trace_logger.dart';
import 'data/local/storage_service.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize communication port for background service
  FlutterForegroundTask.initCommunicationPort();

  // Sessions live in sessions.db (U6). Hive is only opened by the one-shot
  // migrator with an explicit path — no ambient Hive init needed anymore.

  // Initialize persistent logger (app documents directory — the same
  // directory sessions.db lives in)
  final appDir = await getApplicationDocumentsDirectory();
  AppLogger.init(dirPath: appDir.path, isolateName: 'main');
  await AppLogger.instance.purge();

  // Initialize LLM trace logger
  LlmTraceLogger.init(dirPath: appDir.path, isolateName: 'main');
  await LlmTraceLogger.instance.purge();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // One-time wipe of cleartext secret mirrors left by earlier versions.
  // Runs before the background service isolate can re-cache current keys.
  await ConfigStorage(StorageService(prefs: prefs)).runSecretCacheMigration();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DroidClawApp(),
    ),
  );
}
