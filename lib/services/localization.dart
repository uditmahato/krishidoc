class SupportedLanguages {
  static const english = 'en';
  static const nepali = 'ne'; // Changed from 'ne' to match app_localizations.dart
  static const hindi = 'hi';
  static const arabic = 'ar';
  static const french = 'fr';
  static const german = 'de';

  // Code → Display name
  static const Map<String, String> names = {
    english: 'English',
    nepali: 'नेपाली',
    hindi: 'हिन्दी',
    arabic: 'العربية',
    french: 'Français',
    german: 'Deutsch',
  };

  /// List of all supported language codes
  static List<String> get codes => names.keys.toList();

  /// Turn code ('np') into display name ('नेपाली')
  static String getName(String code) => names[code] ?? code;
}