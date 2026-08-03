import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart';

import 'database/app_database.dart';

/// Drift-backed [ObservationStore].
final class DriftObservationStore implements ObservationStore {
  DriftObservationStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsert(Observation observation) => _db
      .into(_db.observations)
      .insertOnConflictUpdate(observationToRow(observation));

  @override
  Future<Observation?> byId(String id) async {
    final row = await (_db.select(
      _db.observations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<Observation>> recent({int limit = 50}) async {
    final rows = await _recentQuery(limit).get();
    return [for (final row in rows) row.toDomain()];
  }

  @override
  Stream<List<Observation>> watchRecent({int limit = 50}) => _recentQuery(
    limit,
  ).watch().map((rows) => [for (final row in rows) row.toDomain()]);

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.observations)..where((t) => t.id.equals(id))).go();

  SimpleSelectStatement<$ObservationsTable, ObservationRow> _recentQuery(
    int limit,
  ) => _db.select(_db.observations)
    ..orderBy([
      (t) => OrderingTerm(expression: t.createdAtMs, mode: OrderingMode.desc),
    ])
    ..limit(limit);
}
