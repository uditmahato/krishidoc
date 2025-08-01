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
  @override
  String get classifyingDisease => 'रोगको निदान हुँदैछ...';

  @override
  String get pleaseWait => 'कृपया पर्खनुहोस्...';

  @override
  String get symptoms => 'लक्षणहरू';

  @override
  String get treatments => 'उपचारहरू';

  @override
  String get backToHome => 'गृहपृष्ठमा फर्कनुहोस्';

  @override
  String get diagnosisResult => 'निदान नतिजा';
}
