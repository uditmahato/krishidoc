enum FarmTaskKind { work, question }

enum FarmTaskStatus { open, completed }

/// A small, offline-first unit of farm work or a question to remember.
///
/// Questions intentionally use the same lifecycle as work. Until an expert
/// service exists, they are private notes on this phone—not messages that the
/// product pretends to have sent.
final class FarmTask {
  FarmTask({
    required this.id,
    required String title,
    required this.kind,
    required this.createdAt,
    this.status = FarmTaskStatus.open,
    this.cropKey,
    this.dueAt,
    this.completedAt,
  }) : title = _normaliseTitle(title) {
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id');
    if (createdAt.isUtc == false) {
      throw ArgumentError.value(createdAt, 'createdAt', 'must be UTC');
    }
    if (dueAt != null && dueAt!.isUtc == false) {
      throw ArgumentError.value(dueAt, 'dueAt', 'must be UTC');
    }
    if (completedAt != null && completedAt!.isUtc == false) {
      throw ArgumentError.value(completedAt, 'completedAt', 'must be UTC');
    }
    if (status == FarmTaskStatus.completed && completedAt == null) {
      throw ArgumentError('A completed task needs completedAt.');
    }
    if (status == FarmTaskStatus.open && completedAt != null) {
      throw ArgumentError('An open task cannot have completedAt.');
    }
  }

  static const int maxTitleLength = 240;

  final String id;
  final String title;
  final FarmTaskKind kind;
  final FarmTaskStatus status;
  final String? cropKey;
  final DateTime createdAt;
  final DateTime? dueAt;
  final DateTime? completedAt;

  bool get isCompleted => status == FarmTaskStatus.completed;

  FarmTask complete(DateTime when) => FarmTask(
    id: id,
    title: title,
    kind: kind,
    status: FarmTaskStatus.completed,
    cropKey: cropKey,
    createdAt: createdAt,
    dueAt: dueAt,
    completedAt: when.toUtc(),
  );

  FarmTask reopen() => FarmTask(
    id: id,
    title: title,
    kind: kind,
    cropKey: cropKey,
    createdAt: createdAt,
    dueAt: dueAt,
  );

  static String _normaliseTitle(String value) {
    final normalised = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalised.isEmpty) {
      throw ArgumentError.value(value, 'title', 'must not be empty');
    }
    if (normalised.length > maxTitleLength) {
      throw ArgumentError.value(value, 'title', 'is too long');
    }
    return normalised;
  }
}

abstract interface class FarmTaskStore {
  Future<void> upsert(FarmTask task);

  Future<FarmTask?> byId(String id);

  Future<List<FarmTask>> recent({int limit = 100});

  Stream<List<FarmTask>> watchRecent({int limit = 100});

  Future<void> delete(String id);
}
