import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'helpers/sqlite_loader.dart';

void main() {
  ensureSqliteAvailable();

  late AppDatabase db;
  late DriftDiagnosisStore store;
  const ids = IdGenerator();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftDiagnosisStore(db);
  });

  tearDown(() => db.close());

  DiagnosisRecord record({
    required DateTime createdAt,
    ResultState state = ResultState.confident,
    String? id,
  }) => DiagnosisRecord(
    id: id ?? ids.newId(),
    state: state,
    predictions: switch (state) {
      ResultState.outOfScope => const [],
      ResultState.confident => [
        TopPrediction(label: 'late_blight', confidence: 0.91),
      ],
      ResultState.uncertain => [
        TopPrediction(label: 'late_blight', confidence: 0.45),
        TopPrediction(label: 'early_blight', confidence: 0.38),
      ],
    },
    modelVersion: 'tomato-v1',
    createdAt: createdAt.toUtc(),
    cropKey: 'tomato',
    imagePath: '/data/img.jpg',
  );

  test('round-trips every field including Devanagari-safe JSON', () async {
    final saved = DiagnosisRecord(
      id: ids.newId(),
      state: ResultState.confident,
      predictions: [TopPrediction(label: 'पातको ढुसी', confidence: 0.77)],
      modelVersion: 'm1',
      createdAt: DateTime.utc(2026, 7, 27, 10, 30),
      cropKey: 'tomato',
      imagePath: null,
    );
    await store.upsert(saved);

    final loaded = await store.byId(saved.id);
    expect(loaded, isNotNull);
    expect(loaded!.state, ResultState.confident);
    expect(loaded.predictions.single.label, 'पातको ढुसी');
    expect(loaded.predictions.single.confidence, closeTo(0.77, 1e-9));
    expect(loaded.createdAt, DateTime.utc(2026, 7, 27, 10, 30));
    expect(loaded.cropKey, 'tomato');
    expect(loaded.imagePath, isNull);
    expect(loaded.modelVersion, 'm1');
  });

  test('round-trips every ResultState (enum stored by name)', () async {
    for (final state in ResultState.values) {
      final saved = record(createdAt: DateTime.now(), state: state);
      await store.upsert(saved);
      final loaded = await store.byId(saved.id);
      expect(loaded!.state, state);
    }
  });

  test('upsert on same id replaces instead of duplicating', () async {
    final id = ids.newId();
    await store.upsert(record(createdAt: DateTime.utc(2026), id: id));
    await store.upsert(
      record(
        createdAt: DateTime.utc(2026, 2),
        id: id,
        state: ResultState.uncertain,
      ),
    );

    final all = await store.recent();
    expect(all, hasLength(1));
    expect(all.single.state, ResultState.uncertain);
  });

  test('recent returns newest first and honors limit', () async {
    for (var day = 1; day <= 5; day++) {
      await store.upsert(record(createdAt: DateTime.utc(2026, 1, day)));
    }
    final recent = await store.recent(limit: 3);
    expect(recent, hasLength(3));
    expect(recent.first.createdAt.day, 5);
    expect(recent.last.createdAt.day, 3);
  });

  test('watchRecent emits on insert', () async {
    final emissions = <int>[];
    final subscription = store.watchRecent().listen(
      (rows) => emissions.add(rows.length),
    );
    addTearDown(subscription.cancel);

    await store.upsert(record(createdAt: DateTime.utc(2026, 1, 1)));
    await store.upsert(record(createdAt: DateTime.utc(2026, 1, 2)));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(emissions.last, 2);
  });

  test(
    'ids from IdGenerator are unique v7 with ordered timestamps (D-11)',
    () async {
      // RFC 9562 leaves same-millisecond monotonicity optional, so ordering is
      // asserted on the 48-bit timestamp prefix across a real time gap: that
      // is the property index locality depends on.
      final first = ids.newId();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = ids.newId();

      expect(first, isNot(second));
      expect(first.substring(14, 15), '7', reason: 'version nibble must be 7');

      String timestampPrefix(String id) =>
          id.replaceAll('-', '').substring(0, 12);
      expect(
        timestampPrefix(first).compareTo(timestampPrefix(second)) <= 0,
        isTrue,
        reason: 'timestamp prefix must be non-decreasing',
      );
    },
  );
}
