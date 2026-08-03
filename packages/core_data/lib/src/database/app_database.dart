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

/// The field notebook: a photograph, a date, and nothing asserted.
///
/// Separate from [Diagnoses] rather than a nullable-answer column on it,
/// because the two have different truth conditions. A diagnosis row is a
/// claim the app made; an observation row is a thing the farmer did. Merging
/// them would put a `resultState` on rows that have no result, and every
/// exhaustive switch downstream would have to invent a case for it.
@DataClassName('ObservationRow')
@TableIndex(name: 'idx_observations_created', columns: {#createdAtMs})
class Observations extends Table {
  /// Client-minted UUIDv7 (D-11).
  TextColumn get id => text()();
  TextColumn get cropKey => text().nullable()();

  /// Never nullable: an observation without its photograph is not one.
  TextColumn get imagePath => text()();

  /// Capped in the domain type, which is the single owner of the rule.
  TextColumn get note => text().nullable()();

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

@DriftDatabase(tables: [Diagnoses, Observations, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Client migrations follow the same expand-and-contract discipline as
    // the server (D-28): schemaVersion bumps ship additive DDL first.
    //
    // v1 -> v2 adds the field notebook. It is purely additive: no existing
    // column is altered, narrowed or dropped, so a device upgrading keeps
    // every diagnosis and every setting it already had. This is the first
    // migration this client has ever run, which is why it is deliberately
    // the smallest possible one and why a test drives a real v1 database
    // through it rather than asserting the strategy in the abstract.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(observations);
      }
    },
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

extension ObservationRowMapping on ObservationRow {
  Observation toDomain() => Observation(
    id: id,
    imagePath: imagePath,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
    cropKey: cropKey,
    note: note,
  );
}

ObservationsCompanion observationToRow(Observation observation) =>
    ObservationsCompanion.insert(
      id: observation.id,
      cropKey: Value(observation.cropKey),
      imagePath: observation.imagePath,
      note: Value(observation.note),
      createdAtMs: observation.createdAt.millisecondsSinceEpoch,
    );

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
