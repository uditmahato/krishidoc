import 'package:krishidoc/locale/base_language_key.dart';

class LanguageNp extends BaseLanguage {
  @override
  String get appName => 'कृषिडक';

  @override
  String get welcome => 'कृषिडकमा तपाईँलाई स्वागत छ!';

  @override
  String get welcomeSubtitle =>
      'तत्काल बिरुवाको रोगको निदान गर्नुहोस् र आफ्नो भाषामा विशेषज्ञ सल्लाह प्राप्त गर्नुहोस्।';

  @override
  String get diagnoseButton => 'बिरुवाको रोगको निदान गर्नुहोस्';

  @override
  String get voiceOutput => 'आवाज आउटपुट';

  @override
  String get askButton => 'एग्रीबोटलाई सोध्नुहोस्';

  @override
  String get history => 'इतिहास';

  @override
  String get settings => 'सेटिङहरू';

  @override
  String get login => 'लगइन';

  @override
  String get logout => 'लगआउट';

  @override
  String get language => 'भाषा';

  @override
  String get capturePhoto => 'फोटो खिच्नुहोस्';

  @override
  String get selectFromGallery => 'ग्यालरीबाट चयन गर्नुहोस्';

  @override
  String get chatTitle => 'एग्रीबोट च्याट';

  @override
  String get chatInputHint => 'बाली, रोग, आदि बारे सोध्नुहोस्';

  @override
  String get loginPrompt => 'तपाईंको इतिहास हेर्न लगइन गर्नुहोस्';

  @override
  String get noHistory => 'अहिलेसम्म कुनै इतिहास छैन';

  // 🔽 New translations
  @override String get diagnosisResult => 'रोगको नतिजा';
@override String get confidence => 'विश्वास स्तर';
@override String get symptoms => 'लक्षणहरू';
@override String get treatment => 'उपचार';
@override String get backToHome => 'मुख्य पृष्ठमा फर्कनुहोस्';
@override String get ofDiagnosis => 'को निदान';
@override String get ok => 'ठीक छ';

@override String get symptomPrompt => 'कृपया {disease} का ५–१० साधारण र महत्वपूर्ण लक्षणहरूको सूची दिनुहोस्।';
@override String get symptomInstruction => 'प्रत्येक लाइनमा एक लक्षण मात्र लेख्नुहोस्।';

@override String get treatmentPrompt => '{disease} को लागि ५–१० प्रभावकारी उपचार योजना दिनुहोस्।';
@override String get treatmentInstruction => 'स्थानीय कृषि सन्दर्भ अनुसार प्रत्येक योजना छुट्याएर लेख्नुहोस्।';

  @override String get classifyingDisease => 'रोग वर्गीकरण हुँदैछ...';
@override String get pleaseWait => 'कृपया पर्खनुहोस्...';
@override String get treatments => 'उपचारहरू';

@override
  String get emailLabel => 'इमेल';
  @override
  String get passwordLabel => 'पासवर्ड';
  @override
  String get loginButton => 'लगइन';
  @override
  String get forgotPassword => 'पासवर्ड बिर्सनुभयो?';
  @override
  String get loginFailed => 'लगइन असफल। प्रमाणहरू जाँच गर्नुहोस्।';
  @override
  String get forgotPasswordNotImplemented => 'पासवर्ड बिर्सने सुविधा अझै लागू गरिएको छैन।';

@override
  String get signupButton => 'साइन अप';
  @override
  String get nameLabel => 'नाम';
  @override
  String get confirmPasswordLabel => 'पासवर्ड पुष्टि गर्नुहोस्';
  @override
  String get invalidEmail => 'अमान्य इमेल ठेगाना। @ र डोमेन समावेश हुनुपर्छ।';
  @override
  String get invalidPassword => 'पासवर्ड कम्तीमा 8 अक्षरको हुनुपर्छ, ठूला अक्षर, साना अक्षर, अंक र विशेष अक्षरहरू समावेश गर्नुपर्छ।';
  @override
  String get passwordsDoNotMatch => 'पासवर्डहरू मेल खाँदैनन्।';
  @override
  String get signupFailed => 'साइन अप असफल। कृपया तपाईंको विवरण जाँच गर्नुहोस्।';
  @override
  String get signupSuccess => 'साइन अप सफल! कृपया लगइन गर्नुहोस्।';
  @override
  String get alreadyHaveAccount => 'पहिले नै खाता छ? लगइन गर्नुहोस्';
  @override
  String get resetPasswordButton => 'पासवर्ड रिसेट गर्नुहोस्';
  @override
  String get verificationCodeLabel => 'प्रमाणीकरण कोड';
  @override
  String get newPasswordLabel => 'नयाँ पासवर्ड';
  @override
  String get passwordResetSuccess => 'पासवर्ड रिसेट सफल! कृपया लगइन गर्नुहोस्।';
  @override
  String get invalidVerificationCode => 'अमान्य प्रमाणीकरण कोड।';

  @override
  String get dontHaveAccount => 'खाता छैन? साइन अप गर्नुहोस्';

}
