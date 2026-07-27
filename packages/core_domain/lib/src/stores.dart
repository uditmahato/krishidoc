import 'dart:async';

import 'diagnosis.dart';

/// Port for local diagnosis persistence. Implementations live in core_data;
/// the domain depends only on this contract (D-42 severability).
abstract interface class DiagnosisStore {
  Future<void> upsert(DiagnosisRecord record);

  Future<DiagnosisRecord?> byId(String id);

  /// Newest first.
  Future<List<DiagnosisRecord>> recent({int limit = 50});

  /// Reactive newest-first window for offline-first UI.
  Stream<List<DiagnosisRecord>> watchRecent({int limit = 50});
}

/// Port for small scalar preferences (selected language, consent cache tags).
/// Not a document store: values are short strings by design.
abstract interface class SettingsStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Well-known settings keys. Additions only; renames are a data migration.
abstract final class SettingsKeys {
  static const String selectedLanguage = 'selected_language';
}
