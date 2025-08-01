import 'package:krishidoc/locale/base_language_key.dart';

class LanguageDe extends BaseLanguage {
  @override
  String get appName => 'KrishiDoc';

  @override
  String get welcome => 'Willkommen bei KrishiDoc!';

  @override
  String get welcomeSubtitle =>
      'Diagnostizieren Sie Pflanzenkrankheiten sofort und erhalten Sie Expertenrat in Ihrer Sprache.';

  @override
  String get diagnoseButton => 'Pflanzenkrankheit diagnostizieren';

  @override
  String get askButton => 'Fragen Sie AgriBot';

  @override
  String get history => 'Verlauf';

  @override
  String get settings => 'Einstellungen';

  @override
  String get login => 'Anmelden';

  @override
  String get logout => 'Abmelden';

  @override
  String get language => 'Sprache';

  @override
  String get voiceOutput => 'Sprachausgabe';

  @override
  String get capturePhoto => 'Foto aufnehmen';

  @override
  String get selectFromGallery => 'Aus Galerie auswählen';

  @override
  String get chatTitle => 'AgriBot-Chat';

  @override
  String get chatInputHint => 'Fragen Sie nach Pflanzen, Krankheiten usw.';

  @override
  String get loginPrompt => 'Melden Sie sich an, um Ihren Verlauf zu sehen';

  @override
  String get noHistory => 'Noch kein Verlauf';

  // 🔽 Newly added keys
  @override
  String get classifyingDisease => 'Krankheit wird klassifiziert';

  @override
  String get pleaseWait => 'Bitte warten...';

  @override
  String get symptoms => 'Symptome';

  @override
  String get treatments => 'Behandlungen';

  @override
  String get backToHome => 'Zurück zur Startseite';

  @override
  String get diagnosisResult => 'Diagnoseergebnis';
}
