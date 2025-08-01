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
  @override
  String get classifyingDisease => 'Classification de la maladie';

  @override
  String get pleaseWait => 'Veuillez patienter...';

  @override
  String get symptoms => 'Symptômes';

  @override
  String get treatments => 'Traitements';

  @override
  String get backToHome => 'Retour à l’accueil';

  @override
  String get diagnosisResult => 'Résultat du diagnostic';
}
