import 'dart:async';

/// Languages supported by the bundled crop guide.
///
/// This is deliberately independent of Flutter's [Locale]. The service is a
/// plain Dart component, so it can be tested and reused without a widget tree.
enum CropAssistantLanguage {
  en('en'),
  ne('ne'),
  hi('hi');

  const CropAssistantLanguage(this.code);

  final String code;

  static CropAssistantLanguage? fromCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toLowerCase();
    for (final language in values) {
      if (language.code == normalized) return language;
    }
    return null;
  }
}

/// Crop contexts covered by the launch guide.
enum CropAssistantCrop {
  tomato('tomato'),
  potato('potato'),
  maize('maize');

  const CropAssistantCrop(this.key);

  final String key;

  static CropAssistantCrop? fromKey(String? key) {
    if (key == null) return null;
    final normalized = key.trim().toLowerCase();
    for (final crop in values) {
      if (crop.key == normalized) return crop;
    }
    return null;
  }
}

/// Stable identity shown before an answer is requested.
///
/// The attribution says the guide *references* public NARC material. It does
/// not claim that NARC endorses KrishiDoc or validated this implementation.
final class CropAssistantGuideIdentity {
  const CropAssistantGuideIdentity({
    required this.disclosure,
    required this.attribution,
    required this.sourceUri,
  });

  /// Makes the non-generative/offline boundary explicit.
  final String disclosure;

  /// Human-readable source attribution in the selected language.
  final String attribution;

  /// Public NARC page used as the crop-level reference entry point.
  final Uri sourceUri;
}

/// A farmer's question together with the language and crop that constrain it.
final class CropAssistantQuery {
  CropAssistantQuery({
    required String question,
    required this.language,
    required this.crop,
    Iterable<String> previousQuestions = const [],
  }) : question = _validatedQuestion(question),
       previousQuestions = List.unmodifiable(previousQuestions.take(10));

  static const int maxQuestionLength = 500;

  final String question;
  final CropAssistantLanguage language;
  final CropAssistantCrop crop;

  /// Recent in-memory turns, oldest first. They let a bounded follow-up such
  /// as "how do I prevent it?" retain the symptom mentioned one turn ago.
  /// Nothing is persisted or sent to a server.
  final List<String> previousQuestions;

  static String _validatedQuestion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'question', 'must not be empty');
    }
    if (normalized.length > maxQuestionLength) {
      throw ArgumentError.value(
        value,
        'question',
        'must be at most $maxQuestionLength characters',
      );
    }
    return normalized;
  }
}

/// A structured, bounded answer from the offline reference guide.
///
/// There is intentionally no pesticide product or dosage field. Chemical
/// advice changes with registration, formulation and local conditions, and a
/// bundled guide cannot safely make that decision for a farmer.
final class CropAssistantAnswer {
  CropAssistantAnswer({
    required this.language,
    required this.crop,
    required this.summary,
    required List<String> immediateActions,
    required List<String> prevention,
    required List<String> control,
    required List<String> seekHelpWhen,
    required this.identity,
  }) : immediateActions = List.unmodifiable(immediateActions),
       prevention = List.unmodifiable(prevention),
       control = List.unmodifiable(control),
       seekHelpWhen = List.unmodifiable(seekHelpWhen);

  final CropAssistantLanguage language;
  final CropAssistantCrop crop;
  final String summary;
  final List<String> immediateActions;
  final List<String> prevention;
  final List<String> control;
  final List<String> seekHelpWhen;
  final CropAssistantGuideIdentity identity;

  Iterable<String> get allGuidance sync* {
    yield summary;
    yield* immediateActions;
    yield* prevention;
    yield* control;
    yield* seekHelpWhen;
    yield identity.disclosure;
    yield identity.attribution;
  }
}

/// Port retained even though the first implementation is local.
///
/// A future versioned pack can replace the bundled data without changing the
/// controller or screen. A live chatbot is not implied by this interface.
abstract interface class CropAssistantService {
  CropAssistantGuideIdentity identity({
    required CropAssistantLanguage language,
    required CropAssistantCrop crop,
  });

  Future<CropAssistantAnswer> answer(CropAssistantQuery query);
}

enum _GuideTopic { general, leafDamage, yellowingOrWilt }

/// Deterministic, network-free crop guidance for Nepal.
///
/// It selects one of a small number of bounded guidance cards using visible
/// keywords. It does not generate text, infer a diagnosis, or call a server.
final class OfflineCropAssistantService implements CropAssistantService {
  const OfflineCropAssistantService();

  @override
  CropAssistantGuideIdentity identity({
    required CropAssistantLanguage language,
    required CropAssistantCrop crop,
  }) {
    final languageCopy = _languageCopy[language]!;
    return CropAssistantGuideIdentity(
      disclosure: languageCopy.disclosure,
      attribution: languageCopy.attribution,
      sourceUri: _sourceUris[crop]!,
    );
  }

  @override
  Future<CropAssistantAnswer> answer(CropAssistantQuery query) async {
    final topic = _topicFor(query);
    final cropCopy = _cropCopy[query.language]![query.crop]!;
    final languageCopy = _languageCopy[query.language]!;
    return CropAssistantAnswer(
      language: query.language,
      crop: query.crop,
      summary: switch (topic) {
        _GuideTopic.general => cropCopy.generalSummary,
        _GuideTopic.leafDamage => cropCopy.leafDamageSummary,
        _GuideTopic.yellowingOrWilt => cropCopy.yellowingSummary,
      },
      immediateActions: cropCopy.immediateActions,
      prevention: cropCopy.prevention,
      control: cropCopy.control,
      seekHelpWhen: languageCopy.seekHelpWhen,
      identity: identity(language: query.language, crop: query.crop),
    );
  }

  _GuideTopic _topicFor(CropAssistantQuery query) {
    final current = _explicitTopicFor(query.question);
    if (current != null) return current;
    for (final question in query.previousQuestions.reversed) {
      final previous = _explicitTopicFor(question);
      if (previous != null) return previous;
    }
    return _GuideTopic.general;
  }

  _GuideTopic? _explicitTopicFor(String question) {
    final normalized = question.toLowerCase();
    if (_leafDamageWords.any(normalized.contains)) {
      return _GuideTopic.leafDamage;
    }
    if (_yellowingWords.any(normalized.contains)) {
      return _GuideTopic.yellowingOrWilt;
    }
    return null;
  }
}

const Set<String> _leafDamageWords = {
  'spot',
  'blight',
  'lesion',
  'rot',
  'दाग',
  'थोप्ल',
  'डढुवा',
  'कुहि',
  'धब्ब',
  'झुलस',
  'सड़',
};

const Set<String> _yellowingWords = {
  'yellow',
  'wilt',
  'droop',
  'curl',
  'पहेँल',
  'पहेंल',
  'ओइल',
  'बटार',
  'पीला',
  'पीली',
  'मुरझ',
  'मुड़',
};

final Map<CropAssistantCrop, Uri> _sourceUris = {
  CropAssistantCrop.tomato: Uri.parse(
    'https://soil.narc.gov.np/crop/tsm/tomato/',
  ),
  CropAssistantCrop.potato: Uri.parse(
    'https://opac.narc.gov.np/opac_css/index.php?id=15790&lvl=notice_display',
  ),
  CropAssistantCrop.maize: Uri.parse(
    'https://soil.narc.gov.np/crop/bmp/maizebmp/',
  ),
};

final class _LanguageCopy {
  const _LanguageCopy({
    required this.disclosure,
    required this.attribution,
    required this.seekHelpWhen,
  });

  final String disclosure;
  final String attribution;
  final List<String> seekHelpWhen;
}

const Map<CropAssistantLanguage, _LanguageCopy> _languageCopy = {
  CropAssistantLanguage.en: _LanguageCopy(
    disclosure:
        'This is a bounded offline reference guide based on public NARC '
        'material. It is not live generative AI, cannot confirm a disease, '
        'and its Nepali and Hindi wording still needs native-language review.',
    attribution:
        'Reference: public crop guidance from the Nepal Agricultural '
        'Research Council (NARC). NARC does not endorse KrishiDoc.',
    seekHelpWhen: [
      'The problem is spreading quickly across more plants.',
      'Plants collapse suddenly, or stems, roots, fruit, tubers or cobs are affected.',
      'You need to decide whether to use a pesticide. Ask a local agriculture technician first.',
    ],
  ),
  CropAssistantLanguage.ne: _LanguageCopy(
    disclosure:
        'यो सार्वजनिक नार्क सामग्रीमा आधारित सीमित अफलाइन सन्दर्भ मार्गदर्शिका '
        'हो। यो प्रत्यक्ष जेनेरेटिभ एआई होइन, रोग पुष्टि गर्न सक्दैन, र यसको '
        'नेपाली तथा हिन्दी भाषा मातृभाषीबाट समीक्षा हुन बाँकी छ।',
    attribution:
        'सन्दर्भ: नेपाल कृषि अनुसन्धान परिषद् (नार्क) का सार्वजनिक बालीसम्बन्धी '
        'सामग्री। नार्कले कृषिडकलाई समर्थन गरेको भन्ने अर्थ होइन।',
    seekHelpWhen: [
      'समस्या धेरै बोटमा छिट्टै फैलिँदै गएमा।',
      'बिरुवा अचानक ढलेमा वा डाँठ, जरा, फल, गानो वा घोगामा असर देखिएमा।',
      'विषादी प्रयोग गर्ने निर्णय लिनुपरेमा पहिले स्थानीय कृषि प्राविधिकसँग सल्लाह लिनुहोस्।',
    ],
  ),
  CropAssistantLanguage.hi: _LanguageCopy(
    disclosure:
        'यह सार्वजनिक NARC सामग्री पर आधारित सीमित ऑफ़लाइन संदर्भ '
        'मार्गदर्शिका है। यह लाइव जनरेटिव एआई नहीं है, रोग की पुष्टि नहीं '
        'कर सकती, और इसकी नेपाली व हिंदी भाषा की मातृभाषी समीक्षा बाकी है।',
    attribution:
        'संदर्भ: नेपाल कृषि अनुसंधान परिषद (NARC) की सार्वजनिक फसल '
        'सामग्री। NARC द्वारा KrishiDoc के समर्थन का दावा नहीं है।',
    seekHelpWhen: [
      'समस्या तेज़ी से अधिक पौधों में फैल रही हो।',
      'पौधे अचानक गिरें या तना, जड़, फल, कंद या भुट्टा प्रभावित हो।',
      'कीटनाशक या रोगनाशक इस्तेमाल करने का निर्णय लेना हो तो पहले स्थानीय कृषि तकनीशियन से पूछें।',
    ],
  ),
};

final class _CropCopy {
  const _CropCopy({
    required this.generalSummary,
    required this.leafDamageSummary,
    required this.yellowingSummary,
    required this.immediateActions,
    required this.prevention,
    required this.control,
  });

  final String generalSummary;
  final String leafDamageSummary;
  final String yellowingSummary;
  final List<String> immediateActions;
  final List<String> prevention;
  final List<String> control;
}

const Map<CropAssistantLanguage, Map<CropAssistantCrop, _CropCopy>>
_cropCopy = {
  CropAssistantLanguage.en: {
    CropAssistantCrop.tomato: _CropCopy(
      generalSummary:
          'Tomato problems can come from disease, insects, water stress or nutrition. Check several plants before choosing a response.',
      leafDamageSummary:
          'Leaf spots and blight-like damage in tomato can look alike. This offline guide cannot confirm which disease is present.',
      yellowingSummary:
          'Yellowing, curling or wilting in tomato may have several causes. Compare new and old leaves and check the stem and soil moisture.',
      immediateActions: [
        'Photograph both sides of affected leaves and compare nearby plants.',
        'Water at soil level and avoid handling plants while leaves are wet.',
        'Mark the affected row so you can check whether the problem spreads.',
      ],
      prevention: [
        'Start with healthy seedlings and keep enough space for air to move.',
        'Keep weeds and fallen diseased leaves out of the crop area.',
        'Rotate with crops other than tomato, potato, chilli or eggplant when possible.',
      ],
      control: [
        'Work in healthy rows before affected rows, then clean hands and tools.',
        'Separate badly affected material and follow local advice for safe disposal.',
        'Do not choose a pesticide from this guide; ask a local agriculture technician to confirm the problem first.',
      ],
    ),
    CropAssistantCrop.potato: _CropCopy(
      generalSummary:
          'Potato problems can begin in seed tubers, soil, leaves or drainage. Inspect more than one part of the plant before acting.',
      leafDamageSummary:
          'Spots or rapidly darkening potato leaves may have several causes. This offline guide cannot confirm late blight or another disease.',
      yellowingSummary:
          'Yellowing or wilting in potato can be linked to roots, stems, water or disease. Check whether whole plants or only leaves are affected.',
      immediateActions: [
        'Check the underside of leaves, the lower stem and several plants in the same row.',
        'Keep foliage dry when watering and improve drainage around standing water.',
        'Mark affected patches and avoid moving soil or tubers from them.',
      ],
      prevention: [
        'Plant healthy seed tubers from a trusted source.',
        'Remove volunteer potato plants and rotate with non-host crops.',
        'Keep tools, sacks and footwear clean before moving to another plot.',
      ],
      control: [
        'Handle healthy plants first and affected patches last.',
        'Keep suspect tubers separate from seed and food storage.',
        'Do not choose a pesticide from this guide; ask a local agriculture technician to confirm the problem first.',
      ],
    ),
    CropAssistantCrop.maize: _CropCopy(
      generalSummary:
          'Maize symptoms can be caused by disease, insects, waterlogging or nutrient stress. Compare plants across the field pattern.',
      leafDamageSummary:
          'Maize leaf spots and blight-like streaks can look similar. This offline guide cannot confirm the cause from words alone.',
      yellowingSummary:
          'Yellowing or wilting in maize may follow water, root, stem or nutrient problems. Check whether symptoms follow rows, low areas or single plants.',
      immediateActions: [
        'Inspect lower and upper leaves and compare plants inside and outside the affected patch.',
        'Check drainage, stem damage and the base of the plant.',
        'Mark the patch and take clear photos to show a local technician.',
      ],
      prevention: [
        'Use healthy seed and locally recommended tolerant varieties when available.',
        'Keep suitable spacing and drainage so leaves do not stay wet for long.',
        'Rotate crops and manage infected crop residue using local disease guidance.',
      ],
      control: [
        'Avoid carrying affected leaves or soil through healthy parts of the field.',
        'Clean tools after working in the affected patch and keep checking new growth.',
        'Do not choose a pesticide from this guide; ask a local agriculture technician to confirm the problem first.',
      ],
    ),
  },
  CropAssistantLanguage.ne: {
    CropAssistantCrop.tomato: _CropCopy(
      generalSummary:
          'गोलभेँडामा रोग, किरा, पानीको समस्या वा पोषणका कारण समस्या देखिन सक्छ। उपाय छान्नुअघि धेरै बोट जाँच्नुहोस्।',
      leafDamageSummary:
          'गोलभेँडाका पातका थोप्ला र डढुवाजस्ता लक्षण उस्तै देखिन सक्छन्। यो अफलाइन मार्गदर्शिकाले कुन रोग हो भनेर पुष्टि गर्न सक्दैन।',
      yellowingSummary:
          'गोलभेँडाको पात पहेँलो हुने, बटारिने वा ओइलाउने कारण धेरै हुन सक्छन्। नयाँ र पुराना पात, डाँठ र माटोको चिस्यान जाँच्नुहोस्।',
      immediateActions: [
        'असर परेको पातको दुवै पट्टि तस्बिर लिनुहोस् र नजिकका बोटसँग तुलना गर्नुहोस्।',
        'माटोमा पानी दिनुहोस् र पात भिजेको बेला बोट नछुनुहोस्।',
        'समस्या फैलिएको छ कि छैन हेर्न असर परेको लाइन चिनो लगाउनुहोस्।',
      ],
      prevention: [
        'स्वस्थ बेर्ना प्रयोग गर्नुहोस् र हावा चल्ने गरी दूरी राख्नुहोस्।',
        'झारपात र झरेका रोगी पात बाली क्षेत्रबाट हटाउनुहोस्।',
        'सम्भव भए गोलभेँडा, आलु, खुर्सानी वा भण्टा बाहेकका बालीसँग घुम्ती बाली लगाउनुहोस्।',
      ],
      control: [
        'पहिले स्वस्थ लाइनमा र पछि असर परेको लाइनमा काम गरी हात र औजार सफा गर्नुहोस्।',
        'धेरै असर परेको भाग छुट्टै राखी सुरक्षित व्यवस्थापनका लागि स्थानीय सल्लाह पालना गर्नुहोस्।',
        'यो मार्गदर्शिकाबाट विषादी नछान्नुहोस्; पहिले स्थानीय कृषि प्राविधिकबाट समस्या पुष्टि गराउनुहोस्।',
      ],
    ),
    CropAssistantCrop.potato: _CropCopy(
      generalSummary:
          'आलुको समस्या बीउ गानो, माटो, पात वा पानी निकासबाट सुरु हुन सक्छ। उपाय गर्नुअघि बोटका धेरै भाग जाँच्नुहोस्।',
      leafDamageSummary:
          'आलुको पातमा थोप्ला वा छिट्टै कालो हुने लक्षणका धेरै कारण हुन सक्छन्। यो अफलाइन मार्गदर्शिकाले डढुवा वा अर्को रोग पुष्टि गर्न सक्दैन।',
      yellowingSummary:
          'आलु पहेँलो हुने वा ओइलाउने समस्या जरा, डाँठ, पानी वा रोगसँग जोडिएको हुन सक्छ। पूरै बोट कि पात मात्र असर परेको हो जाँच्नुहोस्।',
      immediateActions: [
        'पातको तलपट्टि, तल्लो डाँठ र एउटै लाइनका धेरै बोट जाँच्नुहोस्।',
        'पानी दिँदा पात नभिजाउनुहोस् र पानी जमेको ठाउँको निकास सुधार्नुहोस्।',
        'असर परेको ठाउँ चिनो लगाउनुहोस् र त्यहाँको माटो वा गानो अर्को ठाउँमा नलानुहोस्।',
      ],
      prevention: [
        'विश्वसनीय स्रोतको स्वस्थ बीउ आलु प्रयोग गर्नुहोस्।',
        'आफैँ उम्रेका पुराना आलु हटाउनुहोस् र अन्य बालीसँग घुम्ती बाली लगाउनुहोस्।',
        'अर्को बारीमा जानुअघि औजार, बोरा र जुत्ता सफा गर्नुहोस्।',
      ],
      control: [
        'पहिले स्वस्थ बोट र अन्त्यमा असर परेको ठाउँमा काम गर्नुहोस्।',
        'शंका लागेको गानोलाई बीउ र खाने आलुको भण्डारणबाट अलग राख्नुहोस्।',
        'यो मार्गदर्शिकाबाट विषादी नछान्नुहोस्; पहिले स्थानीय कृषि प्राविधिकबाट समस्या पुष्टि गराउनुहोस्।',
      ],
    ),
    CropAssistantCrop.maize: _CropCopy(
      generalSummary:
          'मकैमा रोग, किरा, पानी जम्ने वा पोषणको कमीले लक्षण देखिन सक्छ। खेतको विभिन्न भागका बोट तुलना गर्नुहोस्।',
      leafDamageSummary:
          'मकैका पातका थोप्ला र डढुवाजस्ता धर्सा उस्तै देखिन सक्छन्। यो अफलाइन मार्गदर्शिकाले शब्दका आधारमा कारण पुष्टि गर्न सक्दैन।',
      yellowingSummary:
          'मकै पहेँलो हुने वा ओइलाउने समस्या पानी, जरा, डाँठ वा पोषणसँग जोडिएको हुन सक्छ। लाइन, होचो ठाउँ वा एकल बोटमा लक्षण छ कि जाँच्नुहोस्।',
      immediateActions: [
        'तल्लो र माथिल्लो पात जाँच्नुहोस् र असर परेको क्षेत्रभित्र र बाहिरका बोट तुलना गर्नुहोस्।',
        'पानी निकास, डाँठको क्षति र बोटको फेद जाँच्नुहोस्।',
        'असर परेको ठाउँ चिनो लगाई स्थानीय प्राविधिकलाई देखाउन स्पष्ट तस्बिर लिनुहोस्।',
      ],
      prevention: [
        'स्वस्थ बीउ र उपलब्ध भए स्थानीय रूपमा सिफारिस गरिएको सहनशील जात प्रयोग गर्नुहोस्।',
        'पात लामो समय भिजिरहन नदिन उचित दूरी र पानी निकास कायम गर्नुहोस्।',
        'घुम्ती बाली लगाउनुहोस् र रोगी अवशेष स्थानीय सल्लाहअनुसार व्यवस्थापन गर्नुहोस्।',
      ],
      control: [
        'असर परेको पात वा माटो स्वस्थ भागमा नलानुहोस्।',
        'असर परेको ठाउँमा काम गरेपछि औजार सफा गर्नुहोस् र नयाँ पात जाँचिरहनुहोस्।',
        'यो मार्गदर्शिकाबाट विषादी नछान्नुहोस्; पहिले स्थानीय कृषि प्राविधिकबाट समस्या पुष्टि गराउनुहोस्।',
      ],
    ),
  },
  CropAssistantLanguage.hi: {
    CropAssistantCrop.tomato: _CropCopy(
      generalSummary:
          'टमाटर में रोग, कीट, पानी या पोषण के कारण समस्या हो सकती है। कोई उपाय चुनने से पहले कई पौधों को जाँचें।',
      leafDamageSummary:
          'टमाटर के पत्तों के धब्बे और झुलसा जैसे लक्षण एक जैसे दिख सकते हैं। यह ऑफ़लाइन मार्गदर्शिका रोग की पुष्टि नहीं कर सकती।',
      yellowingSummary:
          'टमाटर के पत्ते पीले पड़ने, मुड़ने या मुरझाने के कई कारण हो सकते हैं। नई-पुरानी पत्तियाँ, तना और मिट्टी की नमी जाँचें।',
      immediateActions: [
        'प्रभावित पत्ते की दोनों तरफ़ की तस्वीर लें और पास के पौधों से तुलना करें।',
        'पानी मिट्टी पर दें और पत्तियाँ गीली होने पर पौधों को न छुएँ।',
        'प्रभावित कतार पर निशान लगाकर देखें कि समस्या फैल रही है या नहीं।',
      ],
      prevention: [
        'स्वस्थ पौध का उपयोग करें और हवा के लिए पर्याप्त दूरी रखें।',
        'खरपतवार और गिरे हुए रोगग्रस्त पत्तों को फसल क्षेत्र से हटाएँ।',
        'संभव हो तो टमाटर, आलू, मिर्च या बैंगन के अलावा दूसरी फसल के साथ चक्र अपनाएँ।',
      ],
      control: [
        'पहले स्वस्थ और बाद में प्रभावित कतार में काम करें, फिर हाथ और औज़ार साफ़ करें।',
        'बहुत प्रभावित सामग्री अलग रखें और सुरक्षित निपटान के लिए स्थानीय सलाह मानें।',
        'इस मार्गदर्शिका से कोई रोगनाशक न चुनें; पहले स्थानीय कृषि तकनीशियन से समस्या की पुष्टि कराएँ।',
      ],
    ),
    CropAssistantCrop.potato: _CropCopy(
      generalSummary:
          'आलू की समस्या बीज कंद, मिट्टी, पत्तियों या पानी की निकासी से शुरू हो सकती है। कदम उठाने से पहले पौधे के कई हिस्से जाँचें।',
      leafDamageSummary:
          'आलू के पत्तों पर धब्बे या तेज़ी से कालापन कई कारणों से हो सकता है। यह ऑफ़लाइन मार्गदर्शिका पछेती झुलसा या किसी रोग की पुष्टि नहीं कर सकती।',
      yellowingSummary:
          'आलू का पीला पड़ना या मुरझाना जड़, तना, पानी या रोग से जुड़ा हो सकता है। देखें कि पूरा पौधा प्रभावित है या केवल पत्तियाँ।',
      immediateActions: [
        'पत्तियों की निचली तरफ़, निचला तना और उसी कतार के कई पौधे जाँचें।',
        'पानी देते समय पत्तियाँ न भिगोएँ और जहाँ पानी रुका है वहाँ निकासी सुधारें।',
        'प्रभावित जगह पर निशान लगाएँ और वहाँ की मिट्टी या कंद दूसरी जगह न ले जाएँ।',
      ],
      prevention: [
        'विश्वसनीय स्रोत से स्वस्थ बीज आलू लगाएँ।',
        'अपने आप उगे पुराने आलू हटाएँ और दूसरी फसलों के साथ चक्र अपनाएँ।',
        'दूसरे खेत में जाने से पहले औज़ार, बोरे और जूते साफ़ करें।',
      ],
      control: [
        'पहले स्वस्थ पौधों और अंत में प्रभावित हिस्से में काम करें।',
        'संदिग्ध कंदों को बीज और खाने वाले आलू के भंडारण से अलग रखें।',
        'इस मार्गदर्शिका से कोई रोगनाशक न चुनें; पहले स्थानीय कृषि तकनीशियन से समस्या की पुष्टि कराएँ।',
      ],
    ),
    CropAssistantCrop.maize: _CropCopy(
      generalSummary:
          'मक्का में रोग, कीट, जलभराव या पोषण की कमी से लक्षण हो सकते हैं। खेत के अलग-अलग हिस्सों के पौधों की तुलना करें।',
      leafDamageSummary:
          'मक्का के पत्तों के धब्बे और झुलसा जैसी धारियाँ एक जैसी दिख सकती हैं। यह ऑफ़लाइन मार्गदर्शिका शब्दों से कारण की पुष्टि नहीं कर सकती।',
      yellowingSummary:
          'मक्का का पीला पड़ना या मुरझाना पानी, जड़, तना या पोषण से जुड़ा हो सकता है। देखें कि लक्षण कतार, नीची जगह या अकेले पौधे में हैं।',
      immediateActions: [
        'ऊपरी और निचली पत्तियाँ देखें और प्रभावित जगह के अंदर-बाहर के पौधों की तुलना करें।',
        'पानी की निकासी, तने की क्षति और पौधे का आधार जाँचें।',
        'प्रभावित जगह पर निशान लगाएँ और स्थानीय तकनीशियन को दिखाने के लिए साफ़ तस्वीरें लें।',
      ],
      prevention: [
        'स्वस्थ बीज और उपलब्ध होने पर स्थानीय रूप से सुझाई गई सहनशील किस्म लगाएँ।',
        'पत्तियाँ लंबे समय तक गीली न रहें, इसके लिए उचित दूरी और निकासी रखें।',
        'फसल चक्र अपनाएँ और रोगग्रस्त अवशेष स्थानीय सलाह के अनुसार संभालें।',
      ],
      control: [
        'प्रभावित पत्तियाँ या मिट्टी खेत के स्वस्थ हिस्से में न ले जाएँ।',
        'प्रभावित जगह में काम करने के बाद औज़ार साफ़ करें और नई बढ़त देखते रहें।',
        'इस मार्गदर्शिका से कोई रोगनाशक न चुनें; पहले स्थानीय कृषि तकनीशियन से समस्या की पुष्टि कराएँ।',
      ],
    ),
  },
};
