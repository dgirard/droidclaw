import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/app_logger.dart';
import 'core/services/llm_trace_logger.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize communication port for background service
  FlutterForegroundTask.initCommunicationPort();

  // Initialize Hive for session storage
  await Hive.initFlutter();

  // Initialize persistent logger (same directory as Hive)
  final appDir = await getApplicationDocumentsDirectory();
  AppLogger.init(dirPath: appDir.path, isolateName: 'main');
  await AppLogger.instance.purge();

  // Initialize LLM trace logger
  LlmTraceLogger.init(dirPath: appDir.path, isolateName: 'main');
  await LlmTraceLogger.instance.purge();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DroidClawApp(),
    ),
  );
}
