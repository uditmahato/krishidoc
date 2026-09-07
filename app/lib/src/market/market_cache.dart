import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'market_models.dart';

/// Last successfully validated Kalimati snapshot available to the app.
///
/// A cache miss and an unreadable cache are both represented by `null`. The
/// market controller can therefore continue to the live request without
/// exposing file-system or decoding details to the UI.
abstract interface class MarketSnapshotCache {
  Future<MarketSnapshot?> read();

  Future<void> write(MarketSnapshot snapshot);

  Future<void> clear();
}

/// Test and preview cache that never touches device storage.
final class MemoryMarketSnapshotCache implements MarketSnapshotCache {
  MemoryMarketSnapshotCache([MarketSnapshot? initial]) : _snapshot = initial;

  MarketSnapshot? _snapshot;

  @override
  Future<MarketSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(MarketSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = null;
  }
}

/// JSON cache in the app-support directory.
///
/// Writes are staged beside the destination and renamed into place. The
/// previous valid generation is retained as a backup, so a process or device
/// interruption between renames still leaves a readable snapshot. Missing,
/// corrupt and unknown-version files are ordinary cache misses.
final class FileMarketSnapshotCache implements MarketSnapshotCache {
  FileMarketSnapshotCache(Directory directory)
    : this.forFile(
        File('${directory.path}${Platform.pathSeparator}$_fileName'),
      );

  FileMarketSnapshotCache.forFile(File file)
    : _file = file,
      _temporary = File('${file.path}.tmp'),
      _backup = File('${file.path}.bak');

  static const int _schemaVersion = 1;
  static const String _fileName = 'kalimati_market_snapshot.json';

  final File _file;
  final File _temporary;
  final File _backup;

  static Future<FileMarketSnapshotCache> open() async {
    final directory = await getApplicationSupportDirectory();
    return FileMarketSnapshotCache.forFile(
      File('${directory.path}${Platform.pathSeparator}$_fileName'),
    );
  }

  @override
  Future<MarketSnapshot?> read() async {
    final primary = await _readFile(_file);
    if (primary != null) return primary;
    return _readFile(_backup);
  }

  @override
  Future<void> write(MarketSnapshot snapshot) async {
    await _file.parent.create(recursive: true);
    await _deleteIfPresent(_temporary);

    final payload = jsonEncode(<String, Object?>{
      'schemaVersion': _schemaVersion,
      'snapshot': snapshot.toJson(),
    });
    await _temporary.writeAsString(payload, flush: true);

    try {
      if (await _file.exists()) {
        final currentIsReadable = await _readFile(_file) != null;
        if (currentIsReadable) {
          await _deleteIfPresent(_backup);
          await _file.rename(_backup.path);
        } else {
          // Preserve an older readable backup rather than replacing it with
          // a corrupt primary generation.
          await _file.delete();
        }
      }
      await _temporary.rename(_file.path);
    } on Object {
      // If the old primary was moved but the staged generation could not take
      // its place, restore it. Failure to restore is deliberately swallowed:
      // read() can still recover directly from the backup.
      if (!await _file.exists() && await _backup.exists()) {
        try {
          await _backup.rename(_file.path);
        } on Object {
          // The original write error remains the useful failure to report.
        }
      }
      rethrow;
    } finally {
      await _deleteIfPresent(_temporary);
    }
  }

  @override
  Future<void> clear() async {
    await _deleteIfPresent(_temporary);
    await _deleteIfPresent(_file);
    await _deleteIfPresent(_backup);
  }

  static Future<MarketSnapshot?> _readFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<Object?, Object?>) return null;
      final envelope = decoded.cast<String, Object?>();
      if (envelope['schemaVersion'] != _schemaVersion) return null;
      final rawSnapshot = envelope['snapshot'];
      if (rawSnapshot is! Map<Object?, Object?>) return null;
      return MarketSnapshot.fromJson(rawSnapshot.cast<String, Object?>());
    } on Object {
      return null;
    }
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup is best-effort. A subsequent read validates every generation
      // before returning it, so a stale temp or backup file is never trusted.
    }
  }
}
