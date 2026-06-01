import 'dart:convert';

/// Pure, isolate-agnostic logic for the durable cron-trigger queue.
///
/// Cron triggers are persisted as a JSON list in SharedPreferences so a cron
/// that fires while the main isolate is dead (app killed by Android) can be
/// replayed on next startup. At most one pending trigger per `cron_id`
/// (behavior-preserving dedupe — the latest trigger for a cron supersedes an
/// unprocessed earlier one).
///
/// This centralizes the encode/decode/dedupe that was duplicated across the
/// service isolate (enqueue/remove) and the main isolate (process/remove). The
/// SharedPreferences read/write stays at the call sites, since each isolate
/// holds its own store handle.
class DurableTriggerQueue {
  const DurableTriggerQueue._();

  /// Decode the persisted list, tolerating null/empty/malformed input.
  static List<Map<String, dynamic>> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String encode(List<Map<String, dynamic>> pending) =>
      jsonEncode(pending);

  /// Add [trigger], replacing any existing entry with the same `cron_id`.
  static List<Map<String, dynamic>> enqueue(
    List<Map<String, dynamic>> pending,
    Map<String, dynamic> trigger,
  ) {
    final cronId = trigger['cron_id'];
    return [
      ...pending.where((t) => t['cron_id'] != cronId),
      trigger,
    ];
  }

  /// Remove the entry with the given [cronId].
  static List<Map<String, dynamic>> removeByCronId(
    List<Map<String, dynamic>> pending,
    String cronId,
  ) =>
      pending.where((t) => t['cron_id'] != cronId).toList();
}
