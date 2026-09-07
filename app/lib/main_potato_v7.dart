// Full app, isolated package and persistent research banner; V3 is untouched.
import 'package:inference/inference.dart';
import 'main.dart' as app;
import 'src/providers.dart';

Future<void> main() async {
  if (!PotatoFieldResearchPack.useV7 || !useExperimentalPlantModel) {
    throw StateError('V7 test entry point requires KRISHIDOC_POTATO_V7=true');
  }
  await app.main();
}
