// ignore_for_file: depend_on_referenced_packages

import 'package:test/test.dart';

import 'package:droidclaw/core/session/isolate_persistence/hive_path_resolver.dart';

void main() {
  group('HivePathResolver.hiveDirFromWorkspace', () {
    test('returns the workspace parent (the main-isolate Hive dir)', () {
      expect(
        HivePathResolver.hiveDirFromWorkspace('/data/app_flutter/droidclaw_workspace'),
        '/data/app_flutter',
      );
    });

    test('does not double-nest by appending to the workspace path', () {
      const workspace = '/data/app_flutter/droidclaw_workspace';
      final hiveDir = HivePathResolver.hiveDirFromWorkspace(workspace);
      // The bug being guarded against was using the workspace path itself (or
      // a subdir of it) as the Hive dir, desyncing the two isolates.
      expect(hiveDir, isNot(contains('droidclaw_workspace')));
      expect(workspace.startsWith(hiveDir), isTrue);
    });
  });
}
