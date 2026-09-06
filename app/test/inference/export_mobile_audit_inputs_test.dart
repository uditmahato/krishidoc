// Opt-in local diagnostic. These data-dependent checks are not ordinary CI.
import 'dart:convert';
import 'dart:io';

import 'package:capture/capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/capture/photo_review.dart';
import 'package:krishidoc_app/src/inference/potato_field_tflite_classifier.dart';

void main() {
  test(
    'export actual mobile preprocessing for desktop reference evaluation',
    () async {
      final assets = Directory(
        const String.fromEnvironment(
          'KD_AUDIT_INPUT',
          defaultValue: 'test_assets/mobile_audit',
        ),
      );
      final manifest =
          jsonDecode(File('${assets.path}/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final output = Directory(
        const String.fromEnvironment(
          'KD_AUDIT_OUTPUT',
          defaultValue: '../ml/artifacts/mobile_audit_20260906/host_inputs',
        ),
      )..createSync(recursive: true);
      final rows = <Map<String, dynamic>>[];
      const crop = String.fromEnvironment('KD_AUDIT_CROP');
      final samples = (manifest['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((sample) => crop.isEmpty || sample['crop'] == crop)
          .toList();
      for (final sample in samples) {
        final bytes = File(
          '${assets.path}/${sample['file']}',
        ).readAsBytesSync();
        final prepared = const ImageProcessor().prepare(bytes);
        CaptureQuality? quality;
        String? qualityError;
        try {
          quality = assessGalleryPhoto(prepared);
        } on FormatException catch (error) {
          qualityError = error.message;
        }
        final tensor = const PotatoFieldImagePreprocessor().prepare(prepared);
        File('${output.path}/${sample['id']}.f32').writeAsBytesSync(
          tensor.buffer.asUint8List(tensor.offsetInBytes, tensor.lengthInBytes),
        );
        rows.add({
          'id': sample['id'],
          'gallery_quality_pass': quality?.isAcceptable ?? false,
          'gallery_issues':
              quality?.issues.map((v) => v.name).toList() ?? ['invalid_size'],
          if (qualityError != null) 'gallery_error': qualityError,
          'edge_energy': quality?.edgeEnergy,
          'mean_luminance': quality?.meanLuminance,
        });
      }
      File('${output.path}/quality.json').writeAsStringSync(jsonEncode(rows));
      expect(rows.length, samples.length);
    },
    skip: !const bool.fromEnvironment('KD_EXPORT_AUDIT'),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
