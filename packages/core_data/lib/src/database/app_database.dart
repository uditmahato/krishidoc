import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Local diagnoses (D-05 history is device-first). Predictions are stored as
/// a JSON array; they are read back through [DiagnosisRecord]'s invariants.
@DataClassName('DiagnosisRow')
@TableIndex(name: 'idx_diagnoses_created', columns: {#createdAtMs})
class Diagnoses extends Table {
  /// Client-minted UUIDv7 (D-11).
  TextColumn get id => text()();
  TextColumn get cropKey => text().nullable()();

  /// Stored by enum NAME: renaming a [ResultState] member is a data
  /// migration, never a refactor.
  TextColumn get resultState => textEnum<ResultState>()();
  TextColumn get predictionsJson => text()();
  TextColumn get modelVersion => text()();
  TextColumn get imagePath => text().nullable()();

  /// Epoch milliseconds UTC.
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small scalar preferences (SettingsStore port).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Diagnoses, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Client migrations follow the same expand-and-contract discipline as
    // the server (D-28): schemaVersion bumps ship additive DDL first.
  );
}

/// Row <-> domain mapping kept in one place so the JSON shape has a single
/// owner.
extension DiagnosisRowMapping on DiagnosisRow {
  DiagnosisRecord toDomain() => DiagnosisRecord(
    id: id,
    state: resultState,
    predictions: (jsonDecode(predictionsJson) as List<dynamic>)
        .map((e) => TopPrediction.fromJson((e as Map).cast<String, Object?>()))
        .toList(growable: false),
    modelVersion: modelVersion,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
    cropKey: cropKey,
    imagePath: imagePath,
  );
}

DiagnosesCompanion diagnosisToRow(DiagnosisRecord record) =>
    DiagnosesCompanion.insert(
      id: record.id,
      cropKey: Value(record.cropKey),
      resultState: record.state,
      predictionsJson: jsonEncode([
        for (final p in record.predictions) p.toJson(),
      ]),
      modelVersion: record.modelVersion,
      imagePath: Value(record.imagePath),
      createdAtMs: record.createdAt.millisecondsSinceEpoch,
    );
