import 'package:krishidoc/locale/base_language_key.dart';

class LanguageAr extends BaseLanguage {
  @override
  String get appName => 'كريشي دوك';

  @override
  String get welcome => 'مرحبًا بك في كريشي دوك';

  @override
  String get welcomeSubtitle => 'تشخيص الأمراض الزراعية بسهولة';

  @override
  String get diagnoseButton => 'تشخيص';

  @override
  String get voiceOutput => 'الإخراج الصوتي';

  @override
  String get askButton => 'اسأل';

  @override
  String get history => 'السجل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get language => 'اللغة';

  @override
  String get capturePhoto => 'التقاط صورة';

  @override
  String get selectFromGallery => 'اختيار من المعرض';

  @override
  String get chatTitle => 'دردشة أجري بوت';

  @override
  String get chatInputHint => 'اسأل عن المحاصيل، الأمراض، إلخ.';

  @override
  String get loginPrompt => 'تسجيل الدخول لعرض سجلك';

  @override
  String get noHistory => 'لا يوجد سجل بعد';

  // 🔽 Newly added keys
  @override String get diagnosisResult => 'نتيجة التشخيص';
@override String get confidence => 'نسبة الثقة';
@override String get symptoms => 'الأعراض';
@override String get treatment => 'العلاج';
@override String get backToHome => 'العودة إلى الصفحة الرئيسية';
@override String get ofDiagnosis => 'للتشخيص';
@override String get ok => 'موافق';

@override String get symptomPrompt => 'قدم قائمة مختصرة بـ 5 إلى 10 أعراض شائعة وهامة لـ {disease}.';
@override String get symptomInstruction => 'اكتب كل عرض في سطر منفصل.';

@override String get treatmentPrompt => 'قدم 5 إلى 10 خطط علاج فعالة لـ {disease}.';
@override String get treatmentInstruction => 'مخصصة للظروف الزراعية المحلية. اكتب كل خطة في سطر منفصل.';

 @override String get classifyingDisease => 'جارٍ تصنيف المرض...';
@override String get pleaseWait => 'يرجى الانتظار...';
@override String get treatments => 'العلاجات';




}
