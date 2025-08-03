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


}
