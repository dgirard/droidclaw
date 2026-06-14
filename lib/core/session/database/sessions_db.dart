import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'sessions_db.g.dart';

/// The sessions SQLite database (U6 — successor of the Hive `sessions` box).
///
/// Dual-isolate access follows the pattern proven in production on the
/// knowledge graph: each FlutterEngine opens its OWN independent connection
/// on the same file, with WAL + `busy_timeout` set in [migration].beforeOpen
/// on BOTH connections. A row committed by one isolate is immediately
/// visible to a fresh read on the other — no close/reopen reload protocol,
/// no per-isolate page cache to desync (the bug class the Hive store kept
/// producing). Drift stream queries do NOT synchronize across connections;
/// cross-isolate UI refresh keeps going through the existing
/// `sendDataToMain` signal + Riverpod counter.
///
/// ## Durability mapping (successor of the tiered Hive flush policy)
///
/// `PRAGMA synchronous = NORMAL` under WAL: every committed transaction is
/// durable against process death (OOM kill, task swipe) the moment the
/// commit returns — the WAL write syscall has completed. What a NORMAL
/// commit does not flush through to durable storage is the power-loss /
/// kernel-panic window, the same residual envelope the tiered Hive policy
/// accepted for mid-turn saves; WAL guarantees the database never corrupts
/// in that window (the transaction is simply rolled back). See
/// [SessionManager] for how `save(flush:)` maps onto this.
///
/// ## VACUUM ban
///
/// Do NOT add `VACUUM` (or `journal_mode` changes) anywhere in this
/// subsystem. VACUUM rewrites the database file and cannot run while the
/// other isolate's connection holds the file open — it is the direct heir
/// of the Hive `compact()` ban (cross-isolate compaction silently lost the
/// other isolate's writes; see the retired
/// `isolate_persistence/cache_reload.dart` history in git).
@DriftDatabase(include: {'sessions_schema.drift'})
class SessionsDb extends _$SessionsDb {
  SessionsDb(String dbPath) : super(_openConnection(dbPath));

  /// Test-only: construct against a caller-provided executor.
  SessionsDb.forExecutor(super.executor);

  @override
  int get schemaVersion => 1;

  /// Same executor the KG's `driftDatabase(...)` wrapper resolves to (a
  /// background drift isolate per connection), minus its path_provider
  /// lookups — SessionManager already receives an explicit path, and unit
  /// tests have no platform channels. `temp_store = MEMORY` (below)
  /// replaces the wrapper's `sqlite3.tempDirectory` setup: SQLite never
  /// needs an on-disk temp file for this workload.
  static QueryExecutor _openConnection(String dbPath) {
    return NativeDatabase.createInBackground(File(dbPath));
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA busy_timeout = 5000');
          await customStatement('PRAGMA temp_store = MEMORY');
        },
      );

  /// UPSERT a full session row (payload + metadata columns) in one
  /// statement — the single write path of [SessionManager.save].
  Future<void> upsertSession(SessionsCompanion row) =>
      into(sessions).insertOnConflictUpdate(row);

  Future<void> deleteSessionRow(String key) =>
      (delete(sessions)..where((t) => t.sessionKey.equals(key))).go();

  Future<void> deleteAllSessionRows() => delete(sessions).go();

  Future<int> countSessions() async {
    final c = countAll();
    final row = await (selectOnly(sessions)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<String?> readAppState(String key) async {
    final row = await (select(appState)..where((t) => t.stateKey.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> writeAppState(String key, String value) =>
      into(appState).insertOnConflictUpdate(
          AppStateCompanion(stateKey: Value(key), value: Value(value)));
}
