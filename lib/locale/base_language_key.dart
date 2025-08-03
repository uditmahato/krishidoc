import 'package:flutter/material.dart';
import 'package:krishidoc/locale/language_en.dart'; // Import default language

abstract class BaseLanguage {
  static BaseLanguage of(BuildContext context) {
    final baseLanguage = Localizations.of<BaseLanguage>(context, BaseLanguage);
    if (baseLanguage == null) {
      // Optionally log for debugging
      print(
        'Warning: BaseLanguage is null for context. Falling back to LanguageEn.',
      );
      return LanguageEn(); // Fallback to English
    }
    return baseLanguage;
  }

  String get appName;
  String get welcome;
  String get welcomeSubtitle;
  String get diagnoseButton;
  String get askButton;
  String get history;
  String get settings;
  String get login;
  String get logout;
  String get language;
  String get voiceOutput;
  String get capturePhoto;
  String get selectFromGallery;
  String get chatTitle;
  String get chatInputHint;
  String get loginPrompt;
  String get noHistory;

  // 🔽 Newly added
  String get classifyingDisease;
  String get pleaseWait;
  String get symptoms;
  String get treatments;
  String get backToHome;
  String get diagnosisResult;
  String get confidence;
  String get treatment;

  String get ofDiagnosis;
  String get ok;
  String get symptomPrompt;
  String get treatmentPrompt;
  String get treatmentInstruction;
  String get symptomInstruction;

  
  String get emailLabel;
  String get passwordLabel;
  String get loginButton;
  String get forgotPassword;
  String get loginFailed;
  String get forgotPasswordNotImplemented;
}
