import 'dart:async';

/// Enforced ordering for cross-isolate handoffs: persist (write + flush)
/// MUST complete before the other isolate is notified.
///
/// The service isolate writes a cron session to Hive and then tells the main
/// isolate to reload its cache. If the notification races ahead of the disk
/// flush, the main isolate re-reads the box *before* the bytes land and the
/// cron session is invisible until the next reload — a field incident class
/// that is otherwise unreproducible locally (see
/// `docs/solutions/database-issues/session-data-loss-hive-flush-and-destructive-reads.md`).
///
/// This module makes the ordering structural instead of conventional: the
/// notify closure is only invoked after the persist future has completed
/// successfully. If persist throws, the notification is never sent — the
/// receiving isolate must not be told to reload state that was never written.
///
/// Dependency-light by design (dart:async only) so both the main isolate and
/// the service isolate can use it.
class WriteThenNotify {
  const WriteThenNotify._();

  /// Run [persist] to completion, then — and only then — invoke [notify].
  ///
  /// [persist] must internally include the durability step (e.g. Hive
  /// `put` + `flush`); this function cannot verify that, only that whatever
  /// [persist] awaits has finished before [notify] fires.
  ///
  /// Errors from [persist] propagate to the caller and suppress [notify].
  static Future<void> run({
    required Future<void> Function() persist,
    required void Function() notify,
  }) async {
    await persist();
    notify();
  }
}
