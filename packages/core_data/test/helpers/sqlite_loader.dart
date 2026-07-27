import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// Windows dev machines rarely ship `sqlite3.dll`, but Windows 10+ bundles
/// `winsqlite3.dll` in System32, which is recent enough for our schema. Linux
/// CI installs libsqlite3 via apt. Device builds use bundled libs and never
/// touch this helper.
void ensureSqliteAvailable() {
  if (!Platform.isWindows) return;
  open.overrideFor(OperatingSystem.windows, () {
    try {
      return DynamicLibrary.open('sqlite3.dll');
    } on ArgumentError {
      return DynamicLibrary.open('winsqlite3.dll');
    }
  });
}
