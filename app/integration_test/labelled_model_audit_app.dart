// Standalone diagnostic entry point; never the production build target.
import 'package:flutter/material.dart';

import 'labelled_model_audit_test.dart' show runLabelledModelAudit;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier('Preparing labelled image audit…');
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('KrishiDoc Model Audit')),
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (context, value, child) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(value, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    final rows = await runLabelledModelAudit(
      onProgress: (done, total) {
        status.value =
            'Testing labelled photos: $done / $total\n'
            'Keep this app open. Results are saved every 5 photos.';
      },
    );
    status.value =
        'Complete: ${rows.length} photos\n'
        '${rows.where((row) => row.containsKey("error")).length} processing errors';
  } catch (error) {
    status.value = 'Audit stopped: $error';
  }
}
