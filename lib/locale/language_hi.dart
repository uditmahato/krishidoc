import 'package:krishidoc/locale/base_language_key.dart';

class LanguageHi extends BaseLanguage {
  @override
  String get appName => 'कृषिडक';

  @override
  String get welcome => 'कृषिडक में आपका स्वागत है!';

  @override
  String get welcomeSubtitle =>
      'तुरंत पौधों की बीमारियों का निदान करें और अपनी भाषा में विशेषज्ञ सलाह प्राप्त करें।';

  @override
  String get diagnoseButton => 'पौधों की बीमारी का निदान करें';

  @override
  String get askButton => 'एग्रीबॉट से पूछें';

  @override
  String get history => 'इतिहास';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get login => 'लॉगिन';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get language => 'भाषा';

  @override
  String get voiceOutput => 'आवाज आउटपुट';

  @override
  String get capturePhoto => 'फोटो खींचें';

  @override
  String get selectFromGallery => 'गैलरी से चयन करें';

  @override
  String get chatTitle => 'एग्रीबोट चैट';

  @override
  String get chatInputHint => 'फसल, रोग आदि के बारे में पूछें';

  @override
  String get loginPrompt => 'अपना इतिहास देखने के लिए लॉगिन करें';

  @override
  String get noHistory => 'अभी तक कोई इतिहास नहीं';

  // 🆕 Newly added keys
  @override String get diagnosisResult => 'निदान परिणाम';
@override String get confidence => 'विश्वास स्तर';
@override String get symptoms => 'लक्षण';
@override String get treatment => 'उपचार';
@override String get backToHome => 'होम पर वापस जाएं';
@override String get ofDiagnosis => 'का निदान';
@override String get ok => 'ठीक है';

@override String get symptomPrompt => '{disease} के 5–10 सामान्य और महत्वपूर्ण लक्षणों की एक सूची प्रदान करें।';
@override String get symptomInstruction => 'प्रत्येक पंक्ति में केवल एक लक्षण लिखें।';

@override String get treatmentPrompt => '{disease} के लिए 5–10 प्रभावी उपचार योजनाएं प्रदान करें।';
@override String get treatmentInstruction => 'स्थानीय कृषि परिस्थितियों के अनुसार। प्रत्येक योजना को एक अलग पंक्ति में लिखें।';

 @override String get classifyingDisease => 'रोग का वर्गीकरण हो रहा है...';
@override String get pleaseWait => 'कृपया प्रतीक्षा करें...';
@override String get treatments => 'उपचार';




}
