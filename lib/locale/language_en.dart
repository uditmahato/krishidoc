import 'package:krishidoc/locale/base_language_key.dart';

class LanguageEn extends BaseLanguage {
  @override
  String get appName => 'KrishiDoc';

  @override
  String get welcome => 'Welcome to KrishiDoc!';

  @override
  String get welcomeSubtitle => 'Diagnose plant disease instantly and get expert advice in your language.';

  @override
  String get diagnoseButton => 'Diagnose Plant Disease';

  @override
  String get askButton => 'Ask AgriBot';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
String get voiceOutput => 'Voice Output';

@override
  String get capturePhoto => 'Capture Photo';
  @override
  String get selectFromGallery => 'Select from Gallery';

  @override
  String get chatTitle => 'AgriBot Chat';
  @override
  String get chatInputHint => 'Ask about crop, disease, etc.';
  @override
  String get loginPrompt => 'Login to view your history.';
  @override
  String get noHistory => 'No history yet.';
}
