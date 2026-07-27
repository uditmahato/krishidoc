import 'package:core_domain/core_domain.dart';

import 'database/app_database.dart';

/// Drift-backed [SettingsStore].
final class DriftSettingsStore implements SettingsStore {
  DriftSettingsStore(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  @override
  Future<void> delete(String key) =>
      (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();
}
