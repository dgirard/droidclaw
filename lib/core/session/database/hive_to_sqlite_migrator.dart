import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../../shared/constants.dart';
import '../../config/log_entry.dart';
import '../../services/app_logger.dart';
import '../session.dart';
import '../session_metadata.dart';
import 'sessions_db.dart';

/// Thrown when the post-copy verification (row count + spot-check decode
/// comparison) fails: the transaction rolls back, the migration marker is
/// NOT set, and the Hive files stay untouched — Hive remains the truth and
/// the migration re-runs on the next startup.
class SessionMigrationVerificationException implements Exception {
  SessionMigrationVerificationException(this.message);
  final String message;
  @override
  String toString() => 'SessionMigrationVerificationException: $message';
}

/// One-shot, idempotent, race-safe Hive → SQLite session migration (U6).
///
/// Runs inside [SessionsDb] on every `SessionManager.init()` until the
/// `app_state` marker says [AppConstants.sessionsMigrationDone]. Ownership
/// is first-comer, guarded by SQLite itself (R13 — a SharedPreferences flag
/// is not atomic between the two FlutterEngines, and `autoRunOnBoot` lets
/// the service isolate start first):
///
/// 1. The whole copy runs in ONE Drift transaction whose FIRST statement is
///    a write (`INSERT OR IGNORE` of the marker row), so the transaction
///    takes the database write lock immediately — a concurrent migrator
///    blocks on `busy_timeout` instead of reading a stale snapshot.
/// 2. The marker is re-read INSIDE the transaction: the loser of the race
///    acquires the lock only after the winner committed, sees `done`, and
///    skips the copy (idempotent by construction — re-execution is a no-op).
/// 3. Verification BEFORE the marker: row count must equal the Hive session
///    count (metadata sidecars excluded) and N spot-checked sessions must
///    decode from SQLite identical to their Hive source. A failure throws,
///    rolling everything back.
/// 4. Only after commit are the Hive files renamed `<name>.backup` (kept
///    2-3 releases). A kill anywhere before commit rolls the transaction
///    back and the migration simply re-runs at next startup; a kill between
///    commit and rename is healed by the rename being retried whenever the
///    marker is `done` but backup-able files still exist.
///
/// A missing/empty Hive box (fresh install) short-circuits to marker `done`.
///
/// The service isolate cannot write sessions during a migration in
/// progress by construction: both isolates run this from
/// `SessionManager.init()`, and no session write happens before `init()`
/// returns (cron triggers ride the SharedPreferences-based
/// DurableTriggerQueue, which is independent of this store).
class HiveToSqliteMigrator {
  HiveToSqliteMigrator({
    required this.db,
    required this.directory,
    this.beforeVerifyHook,
  });

  /// Name of the legacy Hive box (and base name of its on-disk files).
  static const String legacyBoxName = 'sessions';

  final SessionsDb db;

  /// Directory holding both `sessions.db` and the legacy Hive box files.
  final String directory;

  /// Fault-injection seam for tests: runs inside the migration transaction,
  /// after the copy and before verification (e.g. corrupt a row to prove a
  /// failed verification never sets the marker).
  @visibleForTesting
  final Future<void> Function(SessionsDb db)? beforeVerifyHook;

  /// Runs the migration if it has not completed yet. Returns true when THIS
  /// call performed the copy (false: already done, lost the race, or fresh
  /// install).
  Future<bool> migrate() async {
    // Fast path — also forces the Drift connection open (schema + WAL), a
    // precondition for SessionManager's read-only sync reader.
    final marker = await db.readAppState(AppConstants.sessionsMigrationMarkerKey);
    if (marker == AppConstants.sessionsMigrationDone) {
      // Heal a kill between commit and rename: backup-able files may remain.
      await _renameHiveFilesToBackup();
      return false;
    }

    final hiveFile = File(p.join(directory, '$legacyBoxName.hive'));
    if (!hiveFile.existsSync()) {
      // Fresh install — nothing to migrate. Marker write is race-safe
      // (INSERT OR IGNORE: a concurrent winner's marker is never clobbered).
      await db.customStatement(
        'INSERT OR IGNORE INTO app_state(state_key, value) VALUES(?, ?)',
        [
          AppConstants.sessionsMigrationMarkerKey,
          AppConstants.sessionsMigrationDone,
        ],
      );
      return false;
    }

    // Read the Hive source up front (outside the transaction — Hive is not
    // touched again once the copy starts). Corrupt records are skipped
    // entry-by-entry, exactly like the old SessionManager did on init.
    // Both engines live in ONE process and share the Hive box singleton, so
    // a concurrent migrator may close/rename the box under us — if that
    // happens and the winner finished, the loss is benign.
    final Map<String, ({String raw, Session session})> source;
    try {
      source = await _readHiveSessions();
    } catch (e) {
      final after =
          await db.readAppState(AppConstants.sessionsMigrationMarkerKey);
      if (after == AppConstants.sessionsMigrationDone) return false;
      rethrow;
    }

    var didCopy = false;
    try {
      await db.transaction(() async {
        // First statement is a WRITE: takes the write lock immediately, so
        // the marker re-read below can never see a stale snapshot.
        await db.customStatement(
          'INSERT OR IGNORE INTO app_state(state_key, value) VALUES(?, ?)',
          [AppConstants.sessionsMigrationMarkerKey, 'in_progress'],
        );
        final inTx =
            await db.readAppState(AppConstants.sessionsMigrationMarkerKey);
        if (inTx == AppConstants.sessionsMigrationDone) return; // lost race

        for (final entry in source.entries) {
          await db.upsertSession(_toRow(entry.key, entry.value));
        }

        await beforeVerifyHook?.call(db);
        await _verify(source);

        await db.writeAppState(AppConstants.sessionsMigrationMarkerKey,
            AppConstants.sessionsMigrationDone);
        didCopy = true;
      });
    } catch (e) {
      // A concurrent migrator can surface as a SqliteException the
      // busy_timeout could not absorb — if the winner finished, this loss
      // is benign.
      final after =
          await db.readAppState(AppConstants.sessionsMigrationMarkerKey);
      if (after != AppConstants.sessionsMigrationDone) rethrow;
    }

    await _renameHiveFilesToBackup();
    if (didCopy) {
      AppLogger.instance.info(
        LogSource.app,
        'Hive→SQLite session migration complete: '
        '${source.length} sessions copied and verified',
      );
    }
    return didCopy;
  }

  /// All decodable session records from the legacy box, key → (raw, decoded).
  /// Metadata sidecars (`__meta__:` prefix) are excluded: they became real
  /// columns. The box is closed before returning so the post-commit rename
  /// does not race a live file handle.
  ///
  /// Retries on [HiveError]: Hive box handles are per-isolate singletons
  /// (and its advisory locks per-process), so a concurrent migrator — the
  /// other engine, or the in-process race the tests exercise — can close
  /// the box between our open and our read (and `Hive.openBox` can even
  /// hand back an instance that is mid-close). A fresh reopen after a short
  /// backoff reads from disk; if the winner already renamed the files, the
  /// reopened box is simply empty and the marker check inside the
  /// transaction settles it.
  Future<Map<String, ({String raw, Session session})>>
      _readHiveSessions() async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _readHiveSessionsOnce();
      } on HiveError {
        if (attempt >= 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
  }

  Future<Map<String, ({String raw, Session session})>>
      _readHiveSessionsOnce() async {
    final out = <String, ({String raw, Session session})>{};
    Box<String>? box;
    try {
      box = await Hive.openBox<String>(legacyBoxName, path: directory);
      for (final key in box.keys) {
        final k = key as String;
        if (k.startsWith(AppConstants.sessionMetaKeyPrefix)) continue;
        final raw = box.get(k);
        if (raw == null) continue;
        try {
          final session =
              Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          out[k] = (raw: raw, session: session);
        } catch (e) {
          AppLogger.instance.warning(
            LogSource.app,
            'Migration: corrupted Hive session skipped: $k — '
            '${e.runtimeType}',
          );
        }
      }
    } finally {
      if (box != null && box.isOpen) await box.close();
    }
    return out;
  }

  SessionsCompanion _toRow(String key, ({String raw, Session session}) src) {
    final meta = SessionMetadata.fromSession(src.session);
    return SessionsCompanion(
      sessionKey: Value(key),
      payload: Value(src.raw),
      created: Value(meta.created.millisecondsSinceEpoch),
      updated: Value(meta.updated.millisecondsSinceEpoch),
      messageCount: Value(meta.messageCount),
      conversationMessageCount: Value(meta.conversationMessageCount),
      preview: Value(meta.preview),
      summaryPreview: Value(meta.summaryPreview),
    );
  }

  /// Count + spot-check verification, inside the migration transaction.
  Future<void> _verify(
      Map<String, ({String raw, Session session})> source) async {
    final count = await db.countSessions();
    if (count != source.length) {
      throw SessionMigrationVerificationException(
          'row count $count != Hive session count ${source.length}');
    }

    // Spot-check sample spanning oldest + newest (DM-02): `keys` is in Hive
    // insertion order, so a plain `take(n)` only ever checked the OLDEST
    // sessions and would miss a mapping bug affecting only recent ones.
    // Combine the first n/2 (oldest) and last n/2 (newest) into a Set so the
    // newest sessions are always covered.
    final keys = source.keys.toList();
    final n = AppConstants.sessionsMigrationSpotCheckCount;
    final half = n ~/ 2;
    final sample = <String>{
      ...keys.take(half == 0 ? n : half),
      ...keys.reversed.take(n - half),
    };
    for (final key in sample) {
      final row = await (db.select(db.sessions)
            ..where((t) => t.sessionKey.equals(key)))
          .getSingleOrNull();
      if (row == null) {
        throw SessionMigrationVerificationException(
            'spot-check: migrated row missing for "$key"');
      }
      final Session migrated;
      try {
        migrated =
            Session.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
      } catch (e) {
        throw SessionMigrationVerificationException(
            'spot-check: migrated payload for "$key" does not decode '
            '(${e.runtimeType})');
      }
      final original = source[key]!.session;
      final lastOriginal =
          original.messages.isEmpty ? null : original.messages.last.content;
      final lastMigrated =
          migrated.messages.isEmpty ? null : migrated.messages.last.content;
      if (migrated.key != original.key ||
          migrated.messageCount != original.messageCount ||
          lastMigrated != lastOriginal ||
          migrated.summary != original.summary) {
        throw SessionMigrationVerificationException(
            'spot-check: migrated session "$key" differs from Hive source');
      }
    }
  }

  /// Rename the legacy Hive file set to `*.backup` (idempotent, per-file).
  /// An existing backup is never overwritten: a stray empty box file
  /// re-created by a racing loser must not clobber the real backup.
  Future<void> _renameHiveFilesToBackup() async {
    for (final suffix in ['.hive', '.hivec', '.lock']) {
      final file = File(p.join(directory, '$legacyBoxName$suffix'));
      final backupPath =
          '${file.path}${AppConstants.sessionsHiveBackupSuffix}';
      try {
        if (file.existsSync() && !File(backupPath).existsSync()) {
          await file.rename(backupPath);
        }
      } catch (e) {
        // Best-effort: a failed rename only means the backup keeps its
        // original name; the marker already made SQLite the truth.
        AppLogger.instance.warning(
          LogSource.app,
          'Migration: could not rename ${file.path} to .backup — '
          '${e.runtimeType}',
        );
      }
    }
  }
}
