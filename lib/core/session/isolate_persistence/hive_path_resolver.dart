import 'dart:io';

/// Single source of truth for the Hive storage directory across isolates.
///
/// The main isolate initializes Hive via `Hive.initFlutter()`, which uses the
/// application documents directory. The service isolate has no Flutter binding
/// and must call `Hive.init(<dir>)` with the SAME directory, or the two
/// isolates read and write different boxes — the root cause of the
/// "cron sessions not visible" incident, where a `/app_flutter/app_flutter`
/// double-nesting desynced them.
///
/// The cached workspace path is `<appDocDir>/droidclaw_workspace`, so the Hive
/// directory is its parent — never the workspace path itself (appending a
/// subdirectory is what double-nested and desynced the isolates).
class HivePathResolver {
  const HivePathResolver._();

  /// The Hive directory derived from a workspace path: the workspace's parent,
  /// which equals the main isolate's `Hive.initFlutter()` directory.
  static String hiveDirFromWorkspace(String workspacePath) =>
      Directory(workspacePath).parent.path;
}
