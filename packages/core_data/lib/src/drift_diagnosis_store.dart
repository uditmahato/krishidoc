import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart';

import 'database/app_database.dart';

/// Drift-backed [DiagnosisStore].
final class DriftDiagnosisStore implements DiagnosisStore {
  DriftDiagnosisStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsert(DiagnosisRecord record) =>
      _db.into(_db.diagnoses).insertOnConflictUpdate(diagnosisToRow(record));

  @override
  Future<DiagnosisRecord?> byId(String id) async {
    final row = await (_db.select(
      _db.diagnoses,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<DiagnosisRecord>> recent({int limit = 50}) async {
    final rows = await _recentQuery(limit).get();
    return [for (final row in rows) row.toDomain()];
  }

  @override
  Stream<List<DiagnosisRecord>> watchRecent({int limit = 50}) => _recentQuery(
    limit,
  ).watch().map((rows) => [for (final row in rows) row.toDomain()]);

  SimpleSelectStatement<$DiagnosesTable, DiagnosisRow> _recentQuery(
    int limit,
  ) => _db.select(_db.diagnoses)
    ..orderBy([
      (t) => OrderingTerm(expression: t.createdAtMs, mode: OrderingMode.desc),
    ])
    ..limit(limit);
}
