import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a diagnosed photo lives on the device.
///
/// A port, so widget tests never touch the real file system, for the same
/// reason they never touch a live drift database.
///
/// Photos stay on the device. Nothing here uploads, and the bytes written are
/// the prepared derivative from `ImageProcessor`, which has already had every
/// EXIF tag cleared. V1 uploaded originals carrying the farmer's plot GPS.
abstract interface class PhotoStore {
  /// Writes [bytes] for [diagnosisId] and returns the path to record.
  Future<String> save(String diagnosisId, Uint8List bytes);

  /// Bytes for a previously saved photo, or null when the file is gone.
  ///
  /// Null is a normal outcome, not an error: Android reclaims app storage
  /// under pressure, and a history entry whose photo has been evicted must
  /// still open.
  Future<Uint8List?> read(String path);
}

final class FilePhotoStore implements PhotoStore {
  const FilePhotoStore(this._directory);

  final Directory _directory;

  static Future<FilePhotoStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(documents.path, 'photos'));
    if (!photos.existsSync()) {
      await photos.create(recursive: true);
    }
    return FilePhotoStore(photos);
  }

  @override
  Future<String> save(String diagnosisId, Uint8List bytes) async {
    final file = File(p.join(_directory.path, '$diagnosisId.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }
}

/// In-memory implementation for tests.
final class MemoryPhotoStore implements PhotoStore {
  final Map<String, Uint8List> _files = {};

  @override
  Future<String> save(String diagnosisId, Uint8List bytes) async {
    final path = 'memory://photos/$diagnosisId.jpg';
    _files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List?> read(String path) async => _files[path];
}
