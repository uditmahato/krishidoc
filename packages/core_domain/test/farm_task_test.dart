import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  FarmTask task({
    String title = '  Check   irrigation  ',
    DateTime? createdAt,
    DateTime? dueAt,
  }) => FarmTask(
    id: 'task-1',
    title: title,
    kind: FarmTaskKind.work,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 4),
    dueAt: dueAt,
  );

  test('normalises a title', () {
    expect(task().title, 'Check irrigation');
    expect(() => task(title: '   '), throwsArgumentError);
  });

  test('rejects local timestamps', () {
    expect(() => task(createdAt: DateTime(2026)), throwsArgumentError);
    expect(() => task(dueAt: DateTime(2026)), throwsArgumentError);
  });

  test('completion and reopening keep the task consistent', () {
    final completed = task().complete(DateTime.utc(2026, 8, 5));
    expect(completed.isCompleted, isTrue);
    expect(completed.completedAt, DateTime.utc(2026, 8, 5));

    final reopened = completed.reopen();
    expect(reopened.isCompleted, isFalse);
    expect(reopened.completedAt, isNull);
  });
}
