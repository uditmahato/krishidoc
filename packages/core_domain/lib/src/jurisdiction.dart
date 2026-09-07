/// Pesticide-regulation jurisdictions (D-21, D-46). Advisory chemical content
/// is filtered by the user's jurisdiction; "both" exists only as a content
/// tag, never as a user state.
enum Jurisdiction {
  nepal('NP'),
  india('IN');

  const Jurisdiction(this.code);

  /// ISO 3166-1 alpha-2 code as stored in KB entries and the registry.
  final String code;

  static Jurisdiction? fromCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    for (final jurisdiction in values) {
      if (jurisdiction.code == normalized) return jurisdiction;
    }
    return null;
  }
}
