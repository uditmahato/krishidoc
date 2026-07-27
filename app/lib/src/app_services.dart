import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Composition root for device services. Construction is the only place the
/// app touches concrete store implementations; everything else depends on the
/// core_domain ports.
final class AppServices {
  AppServices._(AppDatabase db)
    : _db = db,
      diagnosisStore = DriftDiagnosisStore(db),
      settingsStore = DriftSettingsStore(db),
      ids = const IdGenerator();

  /// Test seam: inject port fakes; no database is opened. Widget tests must
  /// use this (never a live drift database under fake async).
  AppServices.forTest({
    required this.diagnosisStore,
    required this.settingsStore,
    this.ids = const IdGenerator(),
  }) : _db = null;

  final AppDatabase? _db;
  final DiagnosisStore diagnosisStore;
  final SettingsStore settingsStore;
  final IdGenerator ids;
  bool _disposed = false;

  /// Production database in the app documents directory, on a background
  /// isolate so queries never block the UI thread.
  static Future<AppServices> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'krishidoc.db'));
    return AppServices._(AppDatabase(NativeDatabase.createInBackground(file)));
  }

  /// Test seam: everything real except the storage medium.
  factory AppServices.inMemory() =>
      AppServices._(AppDatabase(NativeDatabase.memory()));

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _db?.close();
  }
}
