import 'package:sqlite3/sqlite3.dart';

/// One metadata row of the `sessions` table, read synchronously.
typedef SessionMetaRow = ({
  String key,
  int created,
  int updated,
  int messageCount,
  int conversationMessageCount,
  String? preview,
  String? summaryPreview,
});

/// Synchronous, read-only companion connection to `sessions.db`.
///
/// **This is the load-bearing design decision of the Hive→SQLite migration
/// (U6).** `SessionManager.get()`/`getOrCreate()` are SYNCHRONOUS (pinned by
/// the characterization tests and relied on throughout the agent loop), but
/// Drift is async-only. Loading every payload into memory at init would
/// regress the U13 lazy load, and making the getters async would break the
/// public API. So reads go through this second connection using
/// `package:sqlite3`'s synchronous API (the same native library Drift sits
/// on), opened read-only on the same file:
///
/// - WAL guarantees a read-only connection always sees the LATEST committed
///   snapshot per statement — including commits from the OTHER isolate's
///   writer connection, with no reload protocol.
/// - Because a sync read is always possible (there is no "closed box
///   window" like Hive reload had), `getOrCreate` can always check row
///   existence before fabricating a fresh session — the
///   never-overwrite-persisted-history invariant holds by construction and
///   the whole rehydration machinery is gone.
/// - Read-only means this connection can never interleave writes with the
///   Drift writer; all writes stay on the single async path.
///
/// The caller must open this AFTER the Drift connection has opened the
/// database (file + WAL mode exist by then) and close it BEFORE the files
/// are deleted (DataWiper).
class SyncSessionReader {
  SyncSessionReader._(this._db);

  final Database _db;

  static SyncSessionReader open(String dbPath) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    // Same contention envelope as the Drift connections (KG-proven pattern).
    db.execute('PRAGMA busy_timeout = 5000');
    return SyncSessionReader._(db);
  }

  /// The stored Session JSON for [key], or null when no row exists.
  String? sessionPayload(String key) {
    final rows = _db
        .select('SELECT payload FROM sessions WHERE session_key = ?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['payload'] as String;
  }

  /// Metadata columns of every session — no payload decode (lazy load).
  List<SessionMetaRow> allMetadata() {
    final rows = _db.select(
        'SELECT session_key, created, updated, message_count, '
        'conversation_message_count, preview, summary_preview FROM sessions');
    return [
      for (final r in rows)
        (
          key: r['session_key'] as String,
          created: r['created'] as int,
          updated: r['updated'] as int,
          messageCount: r['message_count'] as int,
          conversationMessageCount: r['conversation_message_count'] as int,
          preview: r['preview'] as String?,
          summaryPreview: r['summary_preview'] as String?,
        ),
    ];
  }

  void close() => _db.dispose();
}
