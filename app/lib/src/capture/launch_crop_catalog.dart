import 'package:core_domain/core_domain.dart';

/// Provisional launch coverage (D-49 pins launch scope at three crops).
///
/// These keys are placeholders pending the content workstream's decision and
/// agronomist sign-off, and this class disappears once the catalog is derived
/// from installed model packs (D-47). Coverage must always be stated to the
/// farmer rather than assumed, so it lives in one place.
final class LaunchCropCatalog implements CropCatalog {
  const LaunchCropCatalog();

  @override
  List<Crop> get available => const [
    Crop('tomato'),
    Crop('potato'),
    Crop('maize'),
  ];
}
