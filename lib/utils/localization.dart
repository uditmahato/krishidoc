class SupportedLanguages {
  static const english = 'en';
  static const nepali  = 'ne';
  static const hindi   = 'hi';

  // Code → Display name
  static const Map<String, String> names = {
    english: 'English',
    nepali : 'नेपाली',
    hindi  : 'हिन्दी',
  };

  /// List of all supported language codes
  static List<String> get codes => names.keys.toList();

  /// Turn code ('ne') into display name ('नेपाली')
  static String getName(String code) => names[code] ?? code;
}
