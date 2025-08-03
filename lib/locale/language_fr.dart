import 'package:krishidoc/locale/base_language_key.dart';

class LanguageFr extends BaseLanguage {
  @override
  String get appName => 'KrishiDoc';

  @override
  String get welcome => 'Bienvenue sur KrishiDoc!';

  @override
  String get welcomeSubtitle =>
      'Diagnostiquez les maladies des plantes instantanément et obtenez des conseils d\'experts dans votre langue.';

  @override
  String get diagnoseButton => 'Diagnostiquer la maladie des plantes';

  @override
  String get askButton => 'Demander à AgriBot';

  @override
  String get history => 'Historique';

  @override
  String get settings => 'Paramètres';

  @override
  String get login => 'Connexion';

  @override
  String get logout => 'Déconnexion';

  @override
  String get language => 'Langue';

  @override
  String get voiceOutput => 'Sortie vocale';

  @override
  String get capturePhoto => 'Prendre une photo';

  @override
  String get selectFromGallery => 'Sélectionner depuis la galerie';

  @override
  String get chatTitle => 'Chat AgriBot';

  @override
  String get chatInputHint => 'Posez des questions sur les cultures, maladies, etc.';

  @override
  String get loginPrompt => 'Connectez-vous pour voir votre historique';

  @override
  String get noHistory => 'Aucun historique pour l’instant';

  // 🔽 Newly added translations
  @override String get diagnosisResult => 'Résultat du diagnostic';
@override String get confidence => 'Confiance';
@override String get symptoms => 'Symptômes';
@override String get treatment => 'Traitement';
@override String get backToHome => 'Retour à l\'accueil';
@override String get ofDiagnosis => 'du diagnostic';
@override String get ok => 'OK';

@override String get symptomPrompt => 'Fournissez une liste concise de 5 à 10 symptômes courants et significatifs de {disease}.';
@override String get symptomInstruction => 'Listez uniquement les descriptions de symptômes (une par ligne).';

@override String get treatmentPrompt => 'Fournissez 5 à 10 plans de traitement efficaces pour {disease}.';
@override String get treatmentInstruction => 'Adaptés aux conditions agricoles locales. Un plan par ligne.';

  @override String get classifyingDisease => 'Classification de la maladie...';
@override String get pleaseWait => 'Veuillez patienter...';
@override String get treatments => 'Traitements';


@override
  String get emailLabel => 'E-mail';
  @override
  String get passwordLabel => 'Mot de passe';
  @override
  String get loginButton => 'Connexion';
  @override
  String get forgotPassword => 'Mot de passe oublié ?';
  @override
  String get loginFailed => 'Échec de la connexion. Vérifiez vos identifiants.';
  @override
  String get forgotPasswordNotImplemented => 'La fonctionnalité de mot de passe oublié n\'est pas encore implémentée.';

}
