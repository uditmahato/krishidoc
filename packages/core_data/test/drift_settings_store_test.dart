import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'helpers/sqlite_loader.dart';

void main() {
  ensureSqliteAvailable();

  late AppDatabase db;
  late DriftSettingsStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSettingsStore(db);
  });

  tearDown(() => db.close());

  test('missing key reads as null', () async {
    expect(await store.read('absent'), isNull);
  });

  test('write, overwrite, delete round trip', () async {
    await store.write(SettingsKeys.selectedLanguage, AppLanguage.ne.code);
    expect(await store.read(SettingsKeys.selectedLanguage), 'ne');

    await store.write(SettingsKeys.selectedLanguage, AppLanguage.hi.code);
    expect(await store.read(SettingsKeys.selectedLanguage), 'hi');

    await store.delete(SettingsKeys.selectedLanguage);
    expect(await store.read(SettingsKeys.selectedLanguage), isNull);
  });

  test('stored language codes parse back into AppLanguage (D-06)', () async {
    await store.write(SettingsKeys.selectedLanguage, AppLanguage.ne.code);
    final stored = await store.read(SettingsKeys.selectedLanguage);
    expect(AppLanguage.fromCode(stored), AppLanguage.ne);
  });
}
