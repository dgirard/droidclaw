import 'dart:io';

import 'package:hive/hive.dart';

/// Initializes Hive against a fresh temp directory so tests can open the same
/// boxes the app uses (e.g. the `sessions` box) without a device.
///
/// ```dart
/// late HiveTestHarness hive;
/// setUp(() async => hive = await HiveTestHarness.create());
/// tearDown(() => hive.dispose());
/// ```
class HiveTestHarness {
  final Directory dir;

  HiveTestHarness._(this.dir);

  static Future<HiveTestHarness> create() async {
    final dir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(dir.path);
    return HiveTestHarness._(dir);
  }

  Future<void> dispose() async {
    await Hive.close();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
