import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/assistant/crop_assistant.dart';

void main() {
  const service = OfflineCropAssistantService();

  test('language and crop keys map only supported values', () {
    expect(CropAssistantLanguage.fromCode(' NE '), CropAssistantLanguage.ne);
    expect(CropAssistantLanguage.fromCode('bn'), isNull);
    expect(CropAssistantCrop.fromKey('MAIZE'), CropAssistantCrop.maize);
    expect(CropAssistantCrop.fromKey('rice'), isNull);
  });

  test('every crop is covered in English, Nepali and Hindi', () async {
    for (final language in CropAssistantLanguage.values) {
      for (final crop in CropAssistantCrop.values) {
        final answer = await service.answer(
          CropAssistantQuery(
            question: 'How should I protect this crop?',
            language: language,
            crop: crop,
          ),
        );

        expect(answer.language, language);
        expect(answer.crop, crop);
        expect(answer.summary, isNotEmpty);
        expect(answer.immediateActions, isNotEmpty);
        expect(answer.prevention, isNotEmpty);
        expect(answer.control, isNotEmpty);
        expect(answer.seekHelpWhen, isNotEmpty);
        expect(answer.identity.sourceUri.host, endsWith('narc.gov.np'));
        expect(
          answer.identity.attribution.toLowerCase(),
          anyOf(contains('narc'), contains('नार्क')),
        );
      }
    }
  });

  test('the guide identifies itself as offline and non-generative', () {
    final english = service.identity(
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    expect(english.disclosure.toLowerCase(), contains('offline'));
    expect(
      english.disclosure.toLowerCase(),
      contains('not live generative ai'),
    );
    expect(english.disclosure.toLowerCase(), contains('cannot confirm'));

    final nepali = service.identity(
      language: CropAssistantLanguage.ne,
      crop: CropAssistantCrop.potato,
    );
    expect(nepali.disclosure, contains('अफलाइन'));
    expect(nepali.disclosure, contains('जेनेरेटिभ एआई होइन'));

    final hindi = service.identity(
      language: CropAssistantLanguage.hi,
      crop: CropAssistantCrop.maize,
    );
    expect(hindi.disclosure, contains('ऑफ़लाइन'));
    expect(hindi.disclosure, contains('जनरेटिव एआई नहीं'));
  });

  test(
    'visible symptom words select bounded guidance, not a diagnosis',
    () async {
      final general = await service.answer(
        CropAssistantQuery(
          question: 'How do I keep the crop healthy?',
          language: CropAssistantLanguage.en,
          crop: CropAssistantCrop.tomato,
        ),
      );
      final spots = await service.answer(
        CropAssistantQuery(
          question: 'There are dark spots and blight on leaves',
          language: CropAssistantLanguage.en,
          crop: CropAssistantCrop.tomato,
        ),
      );
      final wilt = await service.answer(
        CropAssistantQuery(
          question: 'Leaves are yellow and the plant is wilting',
          language: CropAssistantLanguage.en,
          crop: CropAssistantCrop.tomato,
        ),
      );

      expect(spots.summary, isNot(general.summary));
      expect(wilt.summary, isNot(general.summary));
      expect(spots.summary, contains('cannot confirm'));
      expect(wilt.summary, contains('several causes'));
    },
  );

  test('a follow-up retains recent symptom context in memory', () async {
    final first = await service.answer(
      CropAssistantQuery(
        question: 'There are dark spots and blight on the leaves',
        language: CropAssistantLanguage.en,
        crop: CropAssistantCrop.tomato,
      ),
    );
    final followUp = await service.answer(
      CropAssistantQuery(
        question: 'How can I prevent it next time?',
        previousQuestions: const [
          'There are dark spots and blight on the leaves',
        ],
        language: CropAssistantLanguage.en,
        crop: CropAssistantCrop.tomato,
      ),
    );

    expect(followUp.summary, first.summary);
    expect(followUp.summary, contains('Leaf spots'));
  });

  test('guidance contains no named pesticide or dosage', () async {
    final namedProducts = RegExp(
      r'carbendazim|mancozeb|metalaxyl|chlorothalonil|imidacloprid|'
      r'copper oxychloride|thiophanate|formalin|boric acid',
      caseSensitive: false,
    );
    final dosage = RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:%|g|gram|grams|ml|millilitre|milliliter|'
      r'litre|liter|kg)\b',
      caseSensitive: false,
    );

    for (final language in CropAssistantLanguage.values) {
      for (final crop in CropAssistantCrop.values) {
        final answer = await service.answer(
          CropAssistantQuery(
            question: 'treatment prevention control',
            language: language,
            crop: crop,
          ),
        );
        final guidance = answer.allGuidance.join('\n');
        expect(guidance, isNot(matches(namedProducts)));
        expect(guidance, isNot(matches(dosage)));
      }
    }
  });

  test('questions are trimmed and bounded', () {
    final query = CropAssistantQuery(
      question: '  leaf spots  ',
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    expect(query.question, 'leaf spots');

    expect(
      () => CropAssistantQuery(
        question: '   ',
        language: CropAssistantLanguage.en,
        crop: CropAssistantCrop.tomato,
      ),
      throwsArgumentError,
    );
    expect(
      () => CropAssistantQuery(
        question: 'x' * (CropAssistantQuery.maxQuestionLength + 1),
        language: CropAssistantLanguage.en,
        crop: CropAssistantCrop.tomato,
      ),
      throwsArgumentError,
    );
  });
}
