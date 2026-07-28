import 'dart:async';
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:krishidoc_app/src/capture/camera_session.dart';

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

/// Scriptable [CameraSession]: the test drives frames and failures, so the
/// screen's coaching and gating are exercised without a device.
final class FakeCameraSession implements CameraSession {
  FakeCameraSession({this.failOnStart = false});

  final bool failOnStart;
  final StreamController<LumaFrame> _frames =
      StreamController<LumaFrame>.broadcast();

  bool didStart = false;
  bool didStop = false;
  int captureCount = 0;

  /// Bytes handed back by [capturePhoto]; tests override the preparation
  /// step, so they need not be a real image.
  Uint8List photoBytes = Uint8List.fromList(List<int>.filled(64, 7));

  bool get hasListener => _frames.hasListener;

  void emit(LumaFrame frame) => _frames.add(frame);

  Future<void> close() => _frames.close();

  @override
  Future<void> start() async {
    if (failOnStart) {
      throw StateError('camera unavailable');
    }
    didStart = true;
  }

  @override
  Stream<LumaFrame> get frames => _frames.stream;

  @override
  Future<Uint8List> capturePhoto() async {
    captureCount++;
    return photoBytes;
  }

  @override
  Future<void> stop() async => didStop = true;

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF000000));
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
