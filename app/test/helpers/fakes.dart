import 'dart:async';

import 'package:core_domain/core_domain.dart';

/// Plain in-memory [DiagnosisStore]. Widget tests fake the ports; the real
/// drift implementations are covered by core_data's pure-Dart suite, where
/// the event loop is real. Driving drift through flutter_test's fake-async
/// zone hangs (stream timers re-arm; close() never resolves), so it is
/// banned in widget tests.
final class FakeDiagnosisStore implements DiagnosisStore {
  final Map<String, DiagnosisRecord> _records = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<DiagnosisRecord> _snapshot(int limit) {
    final all = _records.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList(growable: false);
  }

  @override
  Future<void> upsert(DiagnosisRecord record) async {
    _records[record.id] = record;
    _changes.add(null);
  }

  @override
  Future<DiagnosisRecord?> byId(String id) async => _records[id];

  @override
  Future<List<DiagnosisRecord>> recent({int limit = 50}) async =>
      _snapshot(limit);

  @override
  Stream<List<DiagnosisRecord>> watchRecent({int limit = 50}) async* {
    yield _snapshot(limit);
    yield* _changes.stream.map((_) => _snapshot(limit));
  }
}

/// Plain in-memory [SettingsStore].
final class FakeSettingsStore implements SettingsStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
