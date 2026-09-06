import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A system photo picker grants access only to the image the farmer selects.
abstract interface class GallerySource {
  Future<Uint8List?> pick();
  Future<Uint8List?> recover();
}

final gallerySourceProvider = Provider<GallerySource>(
  (ref) => DeviceGallerySource(),
);

final class DeviceGallerySource implements GallerySource {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> _read(XFile? file) async {
    if (file == null) return null;
    if (await file.length() > 25 * 1024 * 1024) {
      throw const FormatException('Selected image exceeds 25 MB');
    }
    return file.readAsBytes();
  }

  @override
  Future<Uint8List?> pick() async => _read(
    await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    ),
  );

  /// A selection interrupted by Android process reclamation is offered again
  /// when the farmer reopens capture. It still requires the preview step.
  @override
  Future<Uint8List?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    return _read(files == null || files.isEmpty ? null : files.first);
  }
}
