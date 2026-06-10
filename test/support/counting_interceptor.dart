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

/// Counts UPDATE statements issued through a drift executor, including
/// statements executed inside batches (one count per argument set).
///
/// Used to assert that maintenance paths touch only the rows they must
/// (U15: the hourly decay recompute updates only threshold-crossing rows).
class UpdateCountingInterceptor extends QueryInterceptor {
  int updateCount = 0;

  /// Every intercepted UPDATE statement, in order (for diagnostics).
  final List<String> updateStatements = [];

  void reset() {
    updateCount = 0;
    updateStatements.clear();
  }

  bool _isUpdate(String statement) =>
      statement.trimLeft().toUpperCase().startsWith('UPDATE');

  void _record(String statement) {
    if (_isUpdate(statement)) {
      updateCount++;
      updateStatements.add(statement);
    }
  }

  @override
  Future<int> runUpdate(
      QueryExecutor executor, String statement, List<Object?> args) {
    _record(statement);
    return executor.runUpdate(statement, args);
  }

  @override
  Future<void> runCustom(
      QueryExecutor executor, String statement, List<Object?> args) {
    _record(statement);
    return executor.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(
      QueryExecutor executor, BatchedStatements statements) {
    for (final args in statements.arguments) {
      _record(statements.statements[args.statementIndex]);
    }
    return executor.runBatched(statements);
  }
}
