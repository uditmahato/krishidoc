// Explicit diagnostic entry point. Never replace the normal app's main.dart.
// Release build reuses real production providers, without flutter_test or mocks.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:capture/capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inference/inference.dart';
import 'package:krishidoc_app/src/capture/photo_review.dart';
import 'package:krishidoc_app/src/inference/crop_suggestion.dart';
import 'package:krishidoc_app/src/inference/experimental_tflite_classifier.dart';
import 'package:krishidoc_app/src/inference/potato_field_tflite_classifier.dart';
import 'package:krishidoc_app/src/providers.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _AuditScreen()));
}

class _AuditScreen extends StatefulWidget {
  const _AuditScreen();
  @override
  State<_AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<_AuditScreen> {
  final _providers = ProviderContainer();
  String _status = 'Preparing real-model audit…';
  String? _photo;
  String _lastResult = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _message(String value) {
    if (mounted) setState(() => _status = value);
    // Diagnostics contain public dataset identifiers, never user photographs.
    // ignore: avoid_print
    print('CLASSWISE_AUDIT $value');
  }

  Future<void> _run() async {
    try {
      if (!kReleaseMode || !useExperimentalPlantModel) {
        throw StateError('This audit requires release mode and real models.');
      }
      final destination = await getExternalStorageDirectory();
      if (destination == null) {
        throw StateError('No diagnostic output directory');
      }
      await destination.create(recursive: true);
      final input = Directory('${destination.path}/audit-input');
      final manifestFile = File('${input.path}/manifest.json');
      _message(
        'Waiting for labelled photos\n${input.path}\nKeep this app open.',
      );
      while (!await manifestFile.exists()) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final samples = (manifest['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final reportFile = File('${destination.path}/classwise_report.json');
      final rows = <Map<String, dynamic>>[];
      final report = <String, dynamic>{
        'schema_version': 2,
        'audit_id': manifest['audit_id'],
        'runtime':
            'Android release, production Riverpod classification providers',
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'global_model': ExperimentalPlantPack.modelVersion,
        'potato_model': PotatoFieldResearchPack.modelVersion,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'complete': false,
        'expected_count': samples.length,
        'rows': rows,
      };
      if (await reportFile.exists()) {
        final old =
            jsonDecode(await reportFile.readAsString()) as Map<String, dynamic>;
        if (old['audit_id'] != manifest['audit_id'] ||
            old['global_model'] != ExperimentalPlantPack.modelVersion ||
            old['potato_model'] != PotatoFieldResearchPack.modelVersion) {
          throw StateError(
            'Existing report belongs to another audit; preserve it before rerunning.',
          );
        }
        rows.addAll(
          (old['rows'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
        report['started_at'] = old['started_at'];
      }
      Future<void> save() async {
        final temporary = File('${reportFile.path}.tmp');
        await temporary.writeAsString(jsonEncode(report), flush: true);
        await temporary.rename(reportFile.path);
      }

      final finished = rows.map((r) => r['id']).toSet();
      for (final sample in samples) {
        if (finished.contains(sample['id'])) continue;
        // Batch inference on public test photos does not need an unlocked UI.
        // Android may reclaim the process; saved rows resume on reopening.
        if (!mounted) return;
        final fileName = sample['file'] as String;
        if (fileName.contains('/') ||
            fileName.contains('\\') ||
            fileName.contains('..')) {
          throw FormatException('Invalid fixture file name: $fileName');
        }
        final path = '${input.path}/$fileName';
        if (mounted) setState(() => _photo = path);
        _message(
          'Testing ${rows.length + 1}/${samples.length}\n${sample['condition_label']}',
        );
        final timer = Stopwatch()..start();
        final row = <String, dynamic>{
          'id': sample['id'],
          'crop': sample['crop'],
          'label': sample['condition_label'],
          'split': sample['split'],
          'source': sample['source_id'],
          'photo_sha256': sample['sha256'],
        };
        try {
          final original = await File(path).readAsBytes();
          final prepared = await _providers.read(imagePreparationProvider)(
            original,
          );
          row['preparation_ms'] = timer.elapsedMilliseconds;
          try {
            final quality = await _providers.read(galleryQualityProvider)(
              prepared,
            );
            row['quality_issues'] = quality.issues.map((x) => x.name).toList();
            row['edge_energy'] = quality.edgeEnergy;
            row['mean_luminance'] = quality.meanLuminance;
            row['gallery_disposition'] =
                quality.issues.any(
                  (x) =>
                      x == CaptureIssue.tooDark || x == CaptureIssue.tooBright,
                )
                ? 'blocked_exposure'
                : quality.isAcceptable
                ? 'ready'
                : 'blur_warning_requires_confirmation';
          } on FormatException catch (error) {
            row['gallery_disposition'] = 'blocked_invalid';
            row['quality_error'] = error.message;
          }
          final globalTimer = Stopwatch()..start();
          final probabilities = await _providers
              .read(experimentalTensorRunnerProvider)
              .run(
                const ExperimentalPlantImagePreprocessor().prepare(prepared),
              );
          row['global_ms'] = globalTimer.elapsedMilliseconds;
          row['global_probabilities'] = probabilities;
          final globalTop = probabilities.indexOf(
            probabilities.reduce(math.max),
          );
          row['global_top'] = ExperimentalPlantPack.labelKeys[globalTop];
          row['global_score'] = probabilities[globalTop];
          row['crop_suggestion_raw'] = CropSuggestionService.fromProbabilities(
            probabilities,
          );
          row['crop_suggestion_shown'] = row['gallery_disposition'] == 'ready'
              ? row['crop_suggestion_raw']
              : null;
          final crop = sample['crop'] as String;
          // Exactly the route used after the farmer confirms the correct crop.
          final service = _providers.read(classificationServiceProvider(crop));
          if (service != null) {
            final diagnosisTimer = Stopwatch()..start();
            final outcome = await service.classify(prepared);
            row['diagnosis_ms'] = diagnosisTimer.elapsedMilliseconds;
            row['state'] = outcome.state.name;
            row['model_version'] = outcome.modelVersion;
            row['threshold_version'] = outcome.thresholdSetVersion;
            row['ranked'] = [
              for (final item in outcome.ranked)
                {'label': item.label, 'probability': item.probability},
            ];
            row['app_top'] = outcome.ranked.firstOrNull?.label;
            row['gallery_app_top'] =
                (row['gallery_disposition'] as String).startsWith('blocked')
                ? null
                : row['app_top'];
            if (crop == 'potato') {
              final raw = await _providers
                  .read(potatoFieldTensorRunnerProvider)
                  .run(const PotatoFieldImagePreprocessor().prepare(prepared));
              row['potato_validity_logits'] = raw.validityLogits;
              row['potato_condition_logits'] = raw.conditionLogits;
            }
          } else {
            row['state'] = 'unsupported_crop';
            row['app_top'] = null;
          }
          if (mounted) {
            setState(
              () => _lastResult =
                  "Expected: ${sample['condition_label']}\n"
                  "App: ${row['app_top'] ?? row['state']}\n"
                  "Crop suggestion: ${row['crop_suggestion_shown'] ?? 'none'}",
            );
          }
        } catch (error, stack) {
          row['error'] = '$error';
          row['stack'] = '$stack';
        }
        row['elapsed_ms'] = timer.elapsedMilliseconds;
        rows.add(row);
        await save();
      }
      report['complete'] = rows.length == samples.length;
      report['completed_at'] = DateTime.now().toUtc().toIso8601String();
      await save();
      _message(
        'Complete: ${rows.length} photos\n'
        '${rows.where((r) => r.containsKey('error')).length} processing errors\n'
        'Results saved for analysis.',
      );
    } catch (error) {
      _message('Audit stopped: $error');
    }
  }

  @override
  void dispose() {
    _providers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('KrishiDoc Model Audit')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Diagnostic app — your normal KrishiDoc data is untouched.',
          ),
          const SizedBox(height: 20),
          Text(_status, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_photo != null)
            Image.file(
              File(_photo!),
              height: 260,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) =>
                  const Text('Photo preview unavailable'),
            ),
          const SizedBox(height: 16),
          Text(_lastResult),
          const SizedBox(height: 16),
          const Text(
            'Do not use these diagnostic predictions as treatment advice.',
          ),
        ],
      ),
    ),
  );
}
