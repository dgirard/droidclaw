import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize communication port for foreground task (Telegram bot)
  FlutterForegroundTask.initCommunicationPort();

  // Initialize Hive for session storage
  await Hive.initFlutter();

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
