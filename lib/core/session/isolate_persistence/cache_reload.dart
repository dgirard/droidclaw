import 'package:hive/hive.dart';

/// The explicit cache-reload protocol for cross-isolate Hive visibility.
///
/// Hive caches box contents in memory per isolate; a write flushed to disk by
/// the service isolate is NOT visible to a box the main isolate already holds
/// open. The only way to observe it is to close the box and reopen it, which
/// forces a full disk re-read (see
/// `docs/solutions/architecture/cron-sessions-hive-path-mismatch-between-isolates.md`).
/// This module owns that close → reopen (from the ambient Hive home, set via
/// `Hive.initFlutter()` / `HivePathResolver`) → rebuild-cache sequence so the
/// visibility semantics live in one place.
///
/// Decode failures are tolerated entry-by-entry: a corrupted record is
/// skipped and reported via `onCorrupt`, never aborting the whole rebuild —
/// one bad session must not take down the rest.
///
/// ## Cross-isolate compaction constraint (todos/001)
///
/// Hive's advisory locks are per-process, not per-isolate; both FlutterEngines
/// of the dual-isolate architecture live in ONE process and typically hold the
/// `sessions` box open simultaneously. A `compact()` in either isolate
/// rewrites the box file via temp-file + rename while the other isolate's file
/// handle still points at the old inode — its subsequent writes are silently
/// lost. There is no cross-isolate lock available to serialize this, so:
///
/// - The explicit startup `compact()` was REMOVED from `SessionManager.init()`
///   (it ran in both isolates at boot, the worst possible moment).
/// - Hive's built-in write-time auto-compaction (default strategy: >60
///   deleted/overwritten frames AND >15% of entries) remains unchanged; the
///   residual risk is accepted and documented here until a real cross-isolate
///   lock exists. U13's save batching will reduce the frame churn (each
///   overwrite of a session counts as one deleted frame) that drives it.
/// - Do NOT add `compact()` calls anywhere in this subsystem.
class CacheReload {
  const CacheReload._();

  /// Populate [cache] from every entry of an (already open) [box].
  ///
  /// Used at first open (init): no close/reopen is needed because the box was
  /// just read from disk. Entries that fail [decode] are skipped and reported
  /// via [onCorrupt].
  static void populate<T>({
    required Box<String> box,
    required Map<String, T> cache,
    required T Function(String raw) decode,
    required void Function(String key, Object error) onCorrupt,
  }) {
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        try {
          cache[key as String] = decode(raw);
        } catch (e) {
          onCorrupt(key as String, e);
        }
      }
    }
  }

  /// Close [box], reopen it by name from the ambient Hive home directory
  /// (forcing a disk re-read), clear [cache], and rebuild it from the
  /// reopened box. Returns the reopened box — the caller must replace its
  /// stale handle with it.
  static Future<Box<String>> reload<T>({
    required Box<String> box,
    required Map<String, T> cache,
    required T Function(String raw) decode,
    required void Function(String key, Object error) onCorrupt,
  }) async {
    final boxName = box.name;
    await box.close();
    final reopened = await Hive.openBox<String>(boxName);
    cache.clear();
    populate(box: reopened, cache: cache, decode: decode, onCorrupt: onCorrupt);
    return reopened;
  }
}
