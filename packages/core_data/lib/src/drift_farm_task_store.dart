import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart';

import 'database/app_database.dart';

final class DriftFarmTaskStore implements FarmTaskStore {
  const DriftFarmTaskStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsert(FarmTask task) =>
      _db.into(_db.farmTasks).insertOnConflictUpdate(farmTaskToRow(task));

  @override
  Future<FarmTask?> byId(String id) async {
    final row = await (_db.select(
      _db.farmTasks,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  Selectable<FarmTaskRow> _recentQuery(int limit) => (_db.select(_db.farmTasks)
    ..orderBy([(table) => OrderingTerm.desc(table.createdAtMs)])
    ..limit(limit));

  @override
  Future<List<FarmTask>> recent({int limit = 100}) async =>
      (await _recentQuery(limit).get()).map((row) => row.toDomain()).toList();

  @override
  Stream<List<FarmTask>> watchRecent({int limit = 100}) => _recentQuery(
    limit,
  ).watch().map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.farmTasks)..where((table) => table.id.equals(id))).go();
}
