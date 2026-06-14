import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../shared/constants.dart';

/// Single source of truth for where `sessions.db` lives, across isolates
/// (successor of the retired `HivePathResolver` — same directory
/// derivation, so the SQLite store sits next to the legacy Hive box files
/// it was migrated from).
///
/// The cached workspace path is `<appDocDir>/droidclaw_workspace`, so the
/// sessions directory is its PARENT — never the workspace path itself
/// (appending a subdirectory is what double-nested and desynced the two
/// isolates in the "cron sessions not visible" incident). The main isolate
/// resolves the same directory by deriving it from
/// `StorageService.workspacePath`, guaranteeing both FlutterEngines open
/// the SAME database file.
class SessionsDbPath {
  const SessionsDbPath._();

  /// The sessions directory derived from a workspace path: the workspace's
  /// parent, which equals the app documents directory in the main isolate.
  static String dirFromWorkspace(String workspacePath) =>
      Directory(workspacePath).parent.path;

  /// Full path of `sessions.db` for a given workspace path.
  static String fileFromWorkspace(String workspacePath) =>
      p.join(dirFromWorkspace(workspacePath), AppConstants.sessionsDbFilename);
}
