import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inference/inference.dart';
import 'package:integration_test/integration_test.dart';
import 'package:krishidoc_app/src/capture/photo_review.dart';
import 'package:krishidoc_app/src/inference/crop_suggestion.dart';
import 'package:krishidoc_app/src/inference/experimental_tflite_classifier.dart';
import 'package:krishidoc_app/src/inference/potato_field_tflite_classifier.dart';
import 'package:path_provider/path_provider.dart';

/// Diagnostic accuracy audit. Generate fixtures with prepare_mobile_audit.py
/// and TEMPORARILY bundle test_assets/mobile_audit/; never ship these photos.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'labelled images through the actual phone inference pipeline',
    (tester) async {
      final rows = await runLabelledModelAudit();
      expect(rows.where((row) => row.containsKey('error')), isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

Future<List<Map<String, dynamic>>> runLabelledModelAudit({
  void Function(int completed, int total)? onProgress,
}) async {
  const assetRoot = 'test_assets/mobile_audit/';
  final destination = await getExternalStorageDirectory();
  if (destination == null) throw StateError('No external app report directory');
  const externalInputs = bool.fromEnvironment('KD_AUDIT_EXTERNAL');
  Future<Uint8List> loadInput(String name) async {
    if (externalInputs) {
      if (name.contains('..') || name.contains('/') || name.contains('\\')) {
        throw StateError('Audit input must be a plain file name');
      }
      return File('${destination.path}/v7_inputs/$name').readAsBytes();
    }
    final data = await rootBundle.load('$assetRoot$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  final fixtureBytes = await loadInput('manifest.json');
  final fixture = jsonDecode(utf8.decode(fixtureBytes)) as Map<String, dynamic>;
  final samples = fixture['samples'] as List<dynamic>;
  final modelBytes = await rootBundle.load(potatoFieldModelAsset);
  final modelHash = sha256
      .convert(
        modelBytes.buffer.asUint8List(
          modelBytes.offsetInBytes,
          modelBytes.lengthInBytes,
        ),
      )
      .toString();
  if (modelHash != PotatoFieldResearchPack.artifactSha256 ||
      (fixture['expected_potato_sha256'] != null &&
          fixture['expected_potato_sha256'] != modelHash)) {
    throw StateError('Bundled potato artifact does not match the audit');
  }
  final global = TfliteExperimentalTensorRunner();
  final potato = TflitePotatoFieldTensorRunner();
  final rows = <Map<String, dynamic>>[];
  final reportFile = File('${destination.path}/labelled_model_audit.json');
  Future<void> save() => reportFile
      .writeAsString(
        jsonEncode({
          'schema_version': 1,
          'platform': Platform.operatingSystem,
          'potato_model': PotatoFieldResearchPack.modelVersion,
          'potato_artifact_sha256': modelHash,
          'fixture_sha256': sha256.convert(fixtureBytes).toString(),
          'global_model': ExperimentalPlantPack.modelVersion,
          'selection_independent': false,
          'promotion_eligible': false,
          'rows': rows,
        }),
      )
      .then((_) {});
  for (final value in samples) {
    final sample = value as Map<String, dynamic>;
    final row = <String, dynamic>{
      'id': sample['id'],
      'crop': sample['crop'],
      'label': sample['condition_label'],
      'validity': sample['validity_label'],
      'split': sample['split'],
      'source': sample['source_id'],
    };
    final timer = Stopwatch()..start();
    try {
      final original = await loadInput(sample['file'] as String);
      row['image_sha256'] = sha256.convert(original).toString();
      if (row['image_sha256'] != sample['sha256']) {
        throw StateError('Audit input bytes changed');
      }
      final prepared = await Isolate.run(
        () => const ImageProcessor().prepare(original),
      );
      try {
        final quality = await Isolate.run(() => assessGalleryPhoto(prepared));
        row['gallery_quality_pass'] = quality.isAcceptable;
        row['gallery_issues'] = quality.issues.map((v) => v.name).toList();
        row['edge_energy'] = quality.edgeEnergy;
        row['mean_luminance'] = quality.meanLuminance;
      } on FormatException catch (error) {
        // Score the model diagnostically even when the app would reject the
        // image before inference. Do not count a size veto as a runtime crash.
        row['gallery_quality_pass'] = false;
        row['gallery_issues'] = ['invalid_size'];
        row['gallery_error'] = error.message;
      }
      final probabilities = await global.run(
        const ExperimentalPlantImagePreprocessor().prepare(prepared),
      );
      row['global_probabilities'] = probabilities;
      row['crop_suggestion'] = CropSuggestionService.fromProbabilities(
        probabilities,
      );
      final globalBest = probabilities.indexOf(probabilities.reduce(math.max));
      row['global_top'] = ExperimentalPlantPack.labelKeys[globalBest];
      final globalCrop = sample['crop'] as String;
      if (ExperimentalPlantPack.enabledCrops.contains(globalCrop)) {
        final globalOutcome = await ClassificationService(
          classifier: _GlobalOutput(probabilities),
          pack: ExperimentalPlantPack.global,
          allowedLabelKeys: ExperimentalPlantPack.allowedLabelsForCrop(
            globalCrop,
          ),
        ).classify(prepared);
        row['global_scoped_state'] = globalOutcome.state.name;
        row['global_scoped_top'] = globalOutcome.ranked.firstOrNull?.label;
      }
      final potatoInput = const PotatoFieldImagePreprocessor().prepare(
        prepared,
      );
      final nativeTimer = Stopwatch()..start();
      final raw = await potato.run(potatoInput);
      nativeTimer.stop();
      row['potato_model_ms'] = nativeTimer.elapsedMicroseconds / 1000;
      row['potato_cold_start'] = rows.isEmpty;
      final result = await ClassificationService(
        classifier: PotatoFieldTfliteClassifier(runner: _PotatoOutput(raw)),
        pack: PotatoFieldResearchPack.pack,
      ).classify(prepared);
      row['potato_validity'] = raw.validityLogits;
      row['potato_condition'] = raw.conditionLogits;
      row['potato_state'] = result.state.name;
      row['potato_top'] = result.ranked.firstOrNull?.label;
      final reference = await loadInput(sample['reference_file'] as String);
      if (sample['reference_sha256'] != null &&
          sha256.convert(reference).toString() != sample['reference_sha256']) {
        throw StateError('Reference image bytes changed');
      }
      final refRaw = await potato.run(
        const PotatoFieldImagePreprocessor().prepare(reference),
      );
      row['reference_validity'] = refRaw.validityLogits;
      row['reference_condition'] = refRaw.conditionLogits;
      row['onnx_native_max_error'] = [
        ...List.generate(
          5,
          (i) =>
              (refRaw.validityLogits[i] -
                      ((sample['reference_validity'] as List<dynamic>)[i]
                          as num))
                  .abs(),
        ),
        ...List.generate(
          3,
          (i) =>
              (refRaw.conditionLogits[i] -
                      ((sample['reference_condition'] as List<dynamic>)[i]
                          as num))
                  .abs(),
        ),
      ].reduce(math.max);
    } catch (error) {
      row['error'] = '$error';
    }
    row['elapsed_ms'] = timer.elapsedMilliseconds;
    rows.add(row);
    onProgress?.call(rows.length, samples.length);
    if (rows.length % 5 == 0 || rows.length == samples.length) {
      await save();
      // ignore: avoid_print
      print(
        'MODEL_AUDIT ${rows.length}/${samples.length}; last=${row['id']} ${row['label']} => ${row['global_top']} / ${row['potato_top']}; quality=${row['gallery_quality_pass']}; error=${row['error']}',
      );
    }
  }
  await save();
  // ignore: avoid_print
  print('MODEL_AUDIT_REPORT ${reportFile.path}');
  await global.dispose();
  await potato.dispose();
  return rows;
}

class _GlobalOutput implements ImageClassifier {
  _GlobalOutput(this.probabilities);
  final List<double> probabilities;
  @override
  Future<List<double>> logits(Uint8List bytes) async =>
      probabilities.map((p) => math.log(math.max(p, 1e-12))).toList();
  @override
  Future<void> dispose() async {}
}

class _PotatoOutput implements PotatoFieldTensorRunner {
  _PotatoOutput(this.output);
  final PotatoFieldRawOutput output;
  @override
  Future<PotatoFieldRawOutput> run(Float32List input) async => output;
  @override
  Future<void> dispose() async {}
}
