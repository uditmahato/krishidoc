import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'helpers/sqlite_loader.dart';

void main() {
  ensureSqliteAvailable();

  late AppDatabase db;
  late DriftFarmTaskStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftFarmTaskStore(db);
  });

  tearDown(() => db.close());

  test('round trips every field and watches updates', () async {
    final task = FarmTask(
      id: 'task-1',
      title: 'Check lower field',
      kind: FarmTaskKind.work,
      cropKey: 'maize',
      createdAt: DateTime.utc(2026, 8, 4, 4),
      dueAt: DateTime.utc(2026, 8, 5, 6),
    );

    final first = store.watchRecent().firstWhere((rows) => rows.isNotEmpty);
    await store.upsert(task);
    final watched = await first;
    expect(watched.single.title, task.title);

    final loaded = await store.byId(task.id);
    expect(loaded!.kind, FarmTaskKind.work);
    expect(loaded.cropKey, 'maize');
    expect(loaded.dueAt, task.dueAt);
  });

  test('upsert completes and delete removes', () async {
    final task = FarmTask(
      id: 'question-1',
      title: 'Why are leaves yellow?',
      kind: FarmTaskKind.question,
      createdAt: DateTime.utc(2026, 8, 4),
    );
    await store.upsert(task);
    await store.upsert(task.complete(DateTime.utc(2026, 8, 5)));
    expect((await store.byId(task.id))!.isCompleted, isTrue);

    await store.delete(task.id);
    expect(await store.byId(task.id), isNull);
  });
}
