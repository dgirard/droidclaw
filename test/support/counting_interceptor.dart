import 'package:drift/drift.dart';

/// Counts SELECT statements issued through a drift executor.
///
/// Used to assert that hot retrieval paths issue a bounded number of DB
/// round-trips (U12: no per-candidate N+1 loops). Apply with
/// `NativeDatabase.memory().interceptWith(counter)`.
class SelectCountingInterceptor extends QueryInterceptor {
  int selectCount = 0;

  /// Every intercepted SELECT statement, in order (for diagnostics).
  final List<String> statements = [];

  void reset() {
    selectCount = 0;
    statements.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) {
    selectCount++;
    statements.add(statement);
    return executor.runSelect(statement, args);
  }
}
