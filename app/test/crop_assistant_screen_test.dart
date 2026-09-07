import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/assistant/crop_assistant.dart';

const _englishStrings = CropAssistantUiStrings(
  title: 'Crop assistant',
  intro: 'Ask about crop care in Nepal.',
  offlineLabel: 'Bounded offline reference',
  cropContextLabel: 'Crop',
  cropName: 'Tomato',
  questionLabel: 'Your question',
  questionHint: 'What did you notice?',
  askButton: 'Show guidance',
  emptyQuestionError: 'Write a question first.',
  questionTooLongError: 'Make the question shorter.',
  failedMessage: 'The guide could not open.',
  immediateHeading: 'Do now',
  preventionHeading: 'Prevention',
  controlHeading: 'Control',
  seekHelpHeading: 'Get local help when',
  sourceHeading: 'Source',
);

const _hindiStrings = CropAssistantUiStrings(
  title: 'फसल सहायक',
  intro: 'नेपाल की फसल देखभाल के बारे में पूछें।',
  offlineLabel: 'सीमित ऑफ़लाइन संदर्भ',
  cropContextLabel: 'फसल',
  cropName: 'मक्का',
  questionLabel: 'आपका सवाल',
  questionHint: 'आपने क्या देखा?',
  askButton: 'सलाह देखें',
  emptyQuestionError: 'पहले सवाल लिखें।',
  questionTooLongError: 'सवाल छोटा करें।',
  failedMessage: 'मार्गदर्शिका नहीं खुली।',
  immediateHeading: 'अभी क्या करें',
  preventionHeading: 'रोकथाम',
  controlHeading: 'नियंत्रण',
  seekHelpHeading: 'स्थानीय मदद कब लें',
  sourceHeading: 'स्रोत',
);

void main() {
  testWidgets('discloses the offline non-generative boundary before asking', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(cropAssistantDisclosureKey), findsOneWidget);
    expect(find.textContaining('not live generative AI'), findsOneWidget);
    expect(find.text('Crop: Tomato'), findsOneWidget);
    expect(find.byKey(cropAssistantAnswerKey), findsNothing);
  });

  testWidgets('an empty submission shows an inline localized error', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(cropAssistantAskKey));
    await tester.pump();

    expect(find.text('Write a question first.'), findsOneWidget);
  });

  testWidgets('renders structured guidance and NARC attribution', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(cropAssistantQuestionKey),
      'The leaves have dark spots',
    );
    await tester.tap(find.byKey(cropAssistantAskKey));
    await tester.pumpAndSettle();

    expect(find.byKey(cropAssistantAnswerKey), findsOneWidget);
    expect(find.text('Do now'), findsOneWidget);
    expect(find.text('Prevention'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Get local help when'), findsOneWidget);
    expect(
      find.textContaining('Nepal Agricultural Research Council'),
      findsOneWidget,
    );
  });

  testWidgets('a scan context immediately opens caveated guidance', (
    tester,
  ) async {
    await _pump(
      tester,
      initialContext: const CropAssistantInitialContext(
        query: 'tomato_late_blight treatment prevention control',
        displayText:
            'Tomato late blight. Experimental possible match — not a diagnosis.',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tomato late blight. Experimental possible match'),
      findsOneWidget,
    );
    expect(find.textContaining('tomato_late_blight'), findsNothing);
    expect(find.byKey(cropAssistantAnswerKey), findsOneWidget);
    expect(find.text('Prevention'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
  });

  testWidgets('keeps previous questions and answers in the session', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(
      find.byKey(cropAssistantQuestionKey),
      'How can I prevent leaf spots?',
    );
    await tester.tap(find.byKey(cropAssistantAskKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(cropAssistantQuestionKey),
      'What should I control now?',
    );
    await tester.tap(find.byKey(cropAssistantAskKey));
    await tester.pumpAndSettle();

    expect(find.text('How can I prevent leaf spots?'), findsOneWidget);
    expect(find.text('What should I control now?'), findsOneWidget);
    expect(find.text('Prevention'), findsNWidgets(2));
    expect(find.text('Control'), findsNWidgets(2));
  });

  testWidgets('answer language follows the selected Hindi context', (
    tester,
  ) async {
    await _pump(
      tester,
      language: CropAssistantLanguage.hi,
      crop: CropAssistantCrop.maize,
      strings: _hindiStrings,
    );
    await tester.enterText(
      find.byKey(cropAssistantQuestionKey),
      'पत्ते पीले होकर मुरझा रहे हैं',
    );
    await tester.tap(find.byKey(cropAssistantAskKey));
    await tester.pumpAndSettle();

    expect(find.text('रोकथाम'), findsOneWidget);
    expect(find.text('नियंत्रण'), findsOneWidget);
    expect(find.textContaining('मक्का का पीला पड़ना'), findsOneWidget);
    expect(find.textContaining('जनरेटिव एआई नहीं'), findsOneWidget);
  });

  testWidgets('long guidance remains scrollable at 200 percent text', (
    tester,
  ) async {
    // Submit at the default viewport first. At 200% the lazily-built question
    // field begins below the initial ListView cache extent and cannot be
    // targeted by enterText until the list has been scrolled.
    await _pump(tester);
    await tester.enterText(find.byKey(cropAssistantQuestionKey), 'yellow wilt');
    await tester.tap(find.byKey(cropAssistantAskKey));
    await tester.pumpAndSettle();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  CropAssistantLanguage language = CropAssistantLanguage.en,
  CropAssistantCrop crop = CropAssistantCrop.tomato,
  CropAssistantUiStrings strings = _englishStrings,
  CropAssistantInitialContext? initialContext,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kdLightTheme(locale: Locale(language.code)),
      home: CropAssistantScreen(
        language: language,
        crop: crop,
        strings: strings,
        initialContext: initialContext,
      ),
    ),
  );
  await tester.pump();
}
