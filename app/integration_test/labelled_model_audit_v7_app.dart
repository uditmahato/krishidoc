import 'package:inference/inference.dart';
import 'labelled_model_audit_app.dart' as audit;

Future<void> main() async {
  if (!PotatoFieldResearchPack.useV7) {
    throw StateError('V7 audit requires KRISHIDOC_POTATO_V7=true');
  }
  await audit.main();
}
