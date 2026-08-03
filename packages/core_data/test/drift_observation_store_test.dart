import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart' show Migrator, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'helpers/sqlite_loader.dart';

void main() {
  ensureSqliteAvailable();

  // The migration test opens a second database deliberately. Drift's warning
  // is about two instances sharing ONE executor, which would race; these have
  // separate in-memory executors, so the warning is a false positive here and
  // would otherwise bury real output in CI.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftObservationStore store;
  const ids = IdGenerator();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftObservationStore(db);
  });

  tearDown(() => db.close());

  Observation observation({
    required DateTime createdAt,
    String? id,
    String? note,
    String? cropKey = 'tomato',
  }) => Observation(
    id: id ?? ids.newId(),
    imagePath: '/data/photos/leaf.jpg',
    createdAt: createdAt.toUtc(),
    cropKey: cropKey,
    note: note,
  );

  group('round trip', () {
    test('every field survives, including a Devanagari note', () async {
      final saved = Observation(
        id: ids.newId(),
        imagePath: '/data/photos/a.jpg',
        createdAt: DateTime.utc(2026, 8, 2, 14, 5),
        cropKey: 'tomato',
        note: 'तल्लो पातमा खैरो दाग',
      );
      await store.upsert(saved);

      final loaded = await store.byId(saved.id);
      expect(loaded, isNotNull);
      expect(loaded!.imagePath, '/data/photos/a.jpg');
      expect(loaded.createdAt, DateTime.utc(2026, 8, 2, 14, 5));
      expect(loaded.cropKey, 'tomato');
      expect(loaded.note, 'तल्लो पातमा खैरो दाग');
    });

    test('an absent note and an absent crop stay absent', () async {
      final saved = observation(createdAt: DateTime.utc(2026), cropKey: null);
      await store.upsert(saved);

      final loaded = await store.byId(saved.id);
      expect(loaded!.note, isNull);
      expect(loaded.cropKey, isNull);
    });
  });

  test('newest first, and the limit is honoured', () async {
    for (var day = 1; day <= 5; day++) {
      await store.upsert(observation(createdAt: DateTime.utc(2026, 1, day)));
    }
    final recent = await store.recent(limit: 3);
    expect(recent, hasLength(3));
    expect(recent.first.createdAt.day, 5);
    expect(recent.last.createdAt.day, 3);
  });

  test('upsert on the same id replaces rather than duplicating', () async {
    final id = ids.newId();
    await store.upsert(observation(createdAt: DateTime.utc(2026), id: id));
    await store.upsert(
      observation(createdAt: DateTime.utc(2026), id: id, note: 'edited'),
    );

    final all = await store.recent();
    expect(all, hasLength(1));
    expect(all.single.note, 'edited');
  });

  test('delete removes the row and nothing else', () async {
    final keep = observation(createdAt: DateTime.utc(2026, 1, 1));
    final drop = observation(createdAt: DateTime.utc(2026, 1, 2));
    await store.upsert(keep);
    await store.upsert(drop);

    await store.delete(drop.id);

    final all = await store.recent();
    expect(all, hasLength(1));
    expect(all.single.id, keep.id);
    expect(await store.byId(drop.id), isNull);
  });

  test('watchRecent emits on insert', () async {
    final emissions = <int>[];
    final subscription = store.watchRecent().listen(
      (rows) => emissions.add(rows.length),
    );
    addTearDown(subscription.cancel);

    await store.upsert(observation(createdAt: DateTime.utc(2026, 1, 1)));
    await store.upsert(observation(createdAt: DateTime.utc(2026, 1, 2)));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(emissions.last, 2);
  });

  // The first migration this client has ever run. Asserting the strategy in
  // the abstract would prove nothing: what matters is that a database created
  // at v1, carrying real rows, still carries them after the upgrade and can
  // then use the new table.
  group('v1 to v2 migration', () {
    test(
      'is additive: v1 data survives and the notebook works after',
      () async {
        final executor = NativeDatabase.memory();
        final fresh = AppDatabase(executor);

        // Build the v1 shape by hand, then run the real migrator forward. This
        // is the closest a pure-Dart test gets to an upgraded device: the
        // Observations table genuinely does not exist when the upgrade starts.
        await fresh.customStatement('DROP TABLE IF EXISTS observations');
        final diagnoses = DriftDiagnosisStore(fresh);
        final settings = DriftSettingsStore(fresh);
        final legacy = DiagnosisRecord(
          id: ids.newId(),
          state: ResultState.confident,
          predictions: [TopPrediction(label: 'late_blight', confidence: 0.9)],
          modelVersion: 'sample-tomato-v0',
          createdAt: DateTime.utc(2026, 7, 1),
          cropKey: 'tomato',
          imagePath: '/data/old.jpg',
        );
        await diagnoses.upsert(legacy);
        await settings.write(SettingsKeys.selectedLanguage, 'ne');

        await fresh.migration.onUpgrade(Migrator(fresh), 1, 2);

        // Nothing v1 wrote was touched.
        final survived = await diagnoses.byId(legacy.id);
        expect(
          survived,
          isNotNull,
          reason: 'the upgrade must not drop history',
        );
        expect(survived!.modelVersion, 'sample-tomato-v0');
        expect(
          await settings.read(SettingsKeys.selectedLanguage),
          'ne',
          reason:
              'a farmer must not be asked their language again by an update',
        );

        // And the new table is usable.
        final notebook = DriftObservationStore(fresh);
        final entry = Observation(
          id: ids.newId(),
          imagePath: '/data/new.jpg',
          createdAt: DateTime.utc(2026, 8, 2),
        );
        await notebook.upsert(entry);
        expect((await notebook.recent()).single.id, entry.id);

        await fresh.close();
      },
    );

    test('the declared schema version is the one the migration targets', () {
      // A bump without the matching onUpgrade branch is silent on a fresh
      // install and fatal on an upgrading device, which is the worst possible
      // combination to discover in the field.
      //
      // Note there is deliberately NO `expect(onUpgrade, isNotNull)` here.
      // Drift's onUpgrade is non-nullable and defaults to a no-op, so that
      // assertion can never fail and would have read as coverage while
      // proving nothing. What the branch actually DOES is proved by the
      // upgrade test above, which drives a real v1 database through it.
      expect(db.schemaVersion, 2);
    });

    test('a fresh install creates the notebook without any upgrade', () async {
      // onCreate must cover the new table too. It does via createAll, but
      // that is exactly the kind of thing that silently stops being true.
      final entry = observation(createdAt: DateTime.utc(2026));
      await store.upsert(entry);
      expect(await store.byId(entry.id), isNotNull);
    });
  });

  test('no behaviour hides in beforeOpen', () {
    // A beforeOpen callback runs on a real device and never in these tests,
    // so anything hung off it would ship unexercised. Asserting it stays
    // absent is cheap; the day it is needed, this line is the prompt to test
    // it properly rather than to delete the assertion.
    expect(db.migration.beforeOpen, isNull);
  });
}
