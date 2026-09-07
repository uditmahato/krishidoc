/// Launch languages (D-06). Adding a language is a data-and-packs exercise;
/// this enum only grows together with a shipped translation set.
enum AppLanguage {
  en('en'),
  ne('ne'),
  hi('hi');

  const AppLanguage(this.code);

  /// BCP-47 primary language subtag.
  final String code;

  static AppLanguage? fromCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toLowerCase();
    for (final language in values) {
      if (language.code == normalized) return language;
    }
    return null;
  }
}
