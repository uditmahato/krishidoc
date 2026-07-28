/// A crop the app can diagnose (D-16).
///
/// Identified by a stable [key] that ties together the model pack, the KB
/// entries, and the farmer's remembered choice. Display names are never
/// stored here: they are reviewed KB data (D-35).
final class Crop {
  const Crop(this.key);

  final String key;

  @override
  bool operator ==(Object other) => other is Crop && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Crop($key)';
}

/// What the installed packs can diagnose. Implementations later derive this
/// from installed model packs (D-47); coverage must always be something the
/// app can state plainly rather than assume.
abstract interface class CropCatalog {
  /// Never empty: an install always carries at least the starter pack.
  List<Crop> get available;
}

extension CropCatalogLookup on CropCatalog {
  /// Resolves a stored key, tolerating keys from packs no longer installed.
  Crop? byKey(String? key) {
    if (key == null) return null;
    for (final crop in available) {
      if (crop.key == key) return crop;
    }
    return null;
  }

  /// The crop to use when nothing is remembered yet.
  Crop get fallback => available.first;
}
