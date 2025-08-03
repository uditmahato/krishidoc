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
  @override String get diagnosisResult => 'Diagnoseergebnis';
@override String get confidence => 'Vertrauensgrad';
@override String get symptoms => 'Symptome';
@override String get treatment => 'Behandlung';
@override String get backToHome => 'Zurück zur Startseite';
@override String get ofDiagnosis => 'der Diagnose';
@override String get ok => 'OK';

@override String get symptomPrompt => 'Geben Sie eine kurze Liste von 5–10 häufigen und bedeutenden Symptomen von {disease}.';
@override String get symptomInstruction => 'Listen Sie nur die Symptombeschreibungen auf (jeweils eine pro Zeile).';

@override String get treatmentPrompt => 'Geben Sie 5–10 wirksame Behandlungspläne für {disease} an.';
@override String get treatmentInstruction => 'An lokale landwirtschaftliche Bedingungen angepasst. Jede Zeile ein Plan.';

  @override String get classifyingDisease => 'Krankheit wird klassifiziert...';
@override String get pleaseWait => 'Bitte warten...';
@override String get treatments => 'Behandlungen';

@override
  String get emailLabel => 'E-Mail';
  @override
  String get passwordLabel => 'Passwort';
  @override
  String get loginButton => 'Anmelden';
  @override
  String get forgotPassword => 'Passwort vergessen?';
  @override
  String get loginFailed => 'Anmeldung fehlgeschlagen. Überprüfen Sie Ihre Anmeldedaten.';
  @override
  String get forgotPasswordNotImplemented => 'Die Funktion "Passwort vergessen" ist noch nicht implementiert.';
@override
  String get signupButton => 'Registrieren';
  @override
  String get nameLabel => 'Name';
  @override
  String get confirmPasswordLabel => 'Passwort bestätigen';
  @override
  String get invalidEmail => 'Ungültige E-Mail-Adresse. Muss @ und eine Domain enthalten.';
  @override
  String get invalidPassword => 'Das Passwort muss mindestens 8 Zeichen lang sein und Großbuchstaben, Kleinbuchstaben, Zahlen und Sonderzeichen enthalten.';
  @override
  String get passwordsDoNotMatch => 'Die Passwörter stimmen nicht überein.';
  @override
  String get signupFailed => 'Registrierung fehlgeschlagen. Bitte überprüfen Sie Ihre Angaben.';
  @override
  String get signupSuccess => 'Registrierung erfolgreich! Bitte melden Sie sich an.';
  @override
  String get alreadyHaveAccount => 'Haben Sie schon ein Konto? Anmelden';
  @override
  String get resetPasswordButton => 'Passwort zurücksetzen';
  @override
  String get verificationCodeLabel => 'Verifizierungscode';
  @override
  String get newPasswordLabel => 'Neues Passwort';
  @override
  String get passwordResetSuccess => 'Passwort zurücksetzen erfolgreich! Bitte melden Sie sich an.';
  @override
  String get invalidVerificationCode => 'Ungültiger Verifizierungscode.';

  @override
  String get dontHaveAccount => 'Kein Konto? Registrieren';

}
