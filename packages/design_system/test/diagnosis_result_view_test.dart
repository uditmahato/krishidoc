import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: kdLightTheme(locale: locale),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

ConfidentDiagnosis _confident({
  CertaintyLevel certainty = CertaintyLevel.high,
  VoidCallback? onCorrect,
  VoidCallback? onEscalate,
}) => ConfidentDiagnosis(
  diseaseName: 'Late blight',
  certainty: certainty,
  certaintyLabel: 'This looks like Late blight.',
  caveat: 'A phone photo cannot be certain.',
  correctionLabel: 'This is not what my leaf has',
  onCorrect: onCorrect ?? () {},
  escalationLabel: 'See crop experts near you',
  onEscalate: onEscalate ?? () {},
);

void main() {
  testWidgets('confident states the whole sentence, not a label and a name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(DiagnosisResultView(presentation: _confident())),
    );
    expect(find.text('This looks like Late blight.'), findsOneWidget);
    expect(find.text('A phone photo cannot be certain.'), findsOneWidget);
  });

  testWidgets('confident offers a correction path', (tester) async {
    // This assertion is the inverse of the one it replaces, which asserted
    // that NO buttons existed on the confident card. That test pinned the
    // single worst gap in the product: confident-and-wrong is the case that
    // costs money and puts chemicals on a healthy crop, and it was the only
    // state a farmer could not argue with.
    var corrected = false;
    await tester.pumpWidget(
      _host(
        DiagnosisResultView(
          presentation: _confident(onCorrect: () => corrected = true),
        ),
      ),
    );
    await tester.tap(find.text('This is not what my leaf has'));
    expect(corrected, isTrue);
  });

  testWidgets('every state routes to a person', (tester) async {
    // Escalation lives on the sealed base class, so a state without it is
    // unconstructible. This checks that the RENDERING honours what the type
    // system already guarantees.
    final states = <DiagnosisPresentation>[
      _confident(),
      UncertainDiagnosis(
        title: 'We are not sure',
        alternatives: const ['Late blight', 'Early blight'],
        escalationLabel: 'See crop experts near you',
        onEscalate: () {},
      ),
      OutOfScopeDiagnosis(
        guidance: 'I do not know this one.',
        cause: OutOfScopeCause.notCovered,
        retryLabel: 'Take another photo',
        onRetry: () {},
        escalationLabel: 'See crop experts near you',
        onEscalate: () {},
      ),
    ];

    for (final state in states) {
      await tester.pumpWidget(_host(DiagnosisResultView(presentation: state)));
      expect(
        find.text('See crop experts near you'),
        findsOneWidget,
        reason: '${state.state} must offer a human',
      );
    }
  });

  testWidgets('the three certainty bands do not speak identically', (
    tester,
  ) async {
    // The defect this replaces: one certainty string served every confident
    // result, so a calibrated 0.62 and a calibrated 0.98 read the same and
    // Module 8's calibration was discarded at the last inch.
    final headings = <String>[];
    final icons = <IconData>[];
    for (final (level, label) in const [
      (CertaintyLevel.high, 'This looks like Late blight.'),
      (CertaintyLevel.moderate, 'This is probably Late blight.'),
      (CertaintyLevel.low, 'This might be Late blight.'),
    ]) {
      await tester.pumpWidget(
        _host(
          DiagnosisResultView(
            presentation: ConfidentDiagnosis(
              diseaseName: 'Late blight',
              certainty: level,
              certaintyLabel: label,
              caveat: 'c',
              correctionLabel: 'x',
              onCorrect: () {},
              escalationLabel: 'e',
              onEscalate: () {},
            ),
          ),
        ),
      );
      headings.add(label);
      icons.add(tester.widget<Icon>(find.byType(Icon).first).icon!);
    }

    expect(headings.toSet(), hasLength(3));
    expect(
      icons.toSet(),
      hasLength(3),
      reason:
          'the level must be legible as a shape too, for a reader who cannot '
          'read the sentence beside it',
    );
  });

  testWidgets('out of scope offers a retake only when a retake could help', (
    tester,
  ) async {
    // The resolver reaches this state when nothing cleared the rejection
    // floor, which is a coverage gap. Offering "take another photo" for a
    // coverage gap sends the farmer into a loop that cannot succeed, and that
    // is exactly what the single old string did.
    await tester.pumpWidget(
      _host(
        DiagnosisResultView(
          presentation: OutOfScopeDiagnosis(
            guidance: 'I do not know this one.',
            cause: OutOfScopeCause.notCovered,
            retryLabel: 'Take another photo',
            onRetry: () {},
            escalationLabel: 'See crop experts near you',
            onEscalate: () {},
          ),
        ),
      ),
    );
    expect(find.text('Take another photo'), findsNothing);

    var retried = false;
    await tester.pumpWidget(
      _host(
        DiagnosisResultView(
          presentation: OutOfScopeDiagnosis(
            guidance: 'I could not read this photo.',
            cause: OutOfScopeCause.unreadablePhoto,
            retryLabel: 'Take another photo',
            onRetry: () => retried = true,
            escalationLabel: 'See crop experts near you',
            onEscalate: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Take another photo'));
    expect(retried, isTrue);
  });

  testWidgets('uncertain lists every alternative and escalation fires', (
    tester,
  ) async {
    var escalated = false;
    await tester.pumpWidget(
      _host(
        DiagnosisResultView(
          presentation: UncertainDiagnosis(
            title: 'We are not sure',
            alternatives: const ['Late blight', 'Early blight', 'Leaf mold'],
            escalationLabel: 'Ask an expert',
            onEscalate: () => escalated = true,
          ),
        ),
      ),
    );
    expect(find.textContaining('Late blight'), findsOneWidget);
    expect(find.textContaining('Early blight'), findsOneWidget);
    expect(find.textContaining('Leaf mold'), findsOneWidget);
    await tester.tap(find.text('Ask an expert'));
    expect(escalated, isTrue);
  });

  testWidgets('every state fits a small screen at double scale in Nepali', (
    tester,
  ) async {
    // Nepali runs 1.4x to 1.7x longer than English, and every string on these
    // cards is now a full sentence rather than a fragment, so this is where
    // they would break first.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final states = <DiagnosisPresentation>[
      ConfidentDiagnosis(
        diseaseName: 'ढिलो डढुवा',
        certainty: CertaintyLevel.moderate,
        certaintyLabel: 'यो सम्भवतः ढिलो डढुवा हो।',
        caveat:
            'मोबाइलको फोटोबाट पक्का भन्न सकिँदैन। यो बाली तपाईंलाई '
            'महत्त्वपूर्ण छ भने विषादी छर्कनुअघि कृषि प्राविधिकलाई देखाउनुहोस्।',
        correctionLabel: 'मेरो पातमा यो समस्या होइन',
        onCorrect: () {},
        escalationLabel: 'नजिकका कृषि प्राविधिक हेर्नुहोस्',
        onEscalate: () {},
      ),
      UncertainDiagnosis(
        title: 'हामी पक्का छैनौं',
        alternatives: const ['ढिलो डढुवा', 'चाँडो डढुवा', 'पातको ढुसी'],
        escalationLabel: 'नजिकका कृषि प्राविधिक हेर्नुहोस्',
        onEscalate: () {},
      ),
      OutOfScopeDiagnosis(
        guidance:
            'मैले यो चिन्न सकिनँ। यो एपले अहिलेसम्म गोलभेँडा, आलु र '
            'मकैको पात मात्र हेर्न सक्छ।',
        cause: OutOfScopeCause.notCovered,
        retryLabel: 'अर्को फोटो खिच्नुहोस्',
        onRetry: () {},
        escalationLabel: 'नजिकका कृषि प्राविधिक हेर्नुहोस्',
        onEscalate: () {},
      ),
    ];

    for (final state in states) {
      await tester.pumpWidget(
        _host(
          DiagnosisResultView(presentation: state),
          locale: const Locale('ne'),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${state.state} overflowed at 320x640 scale 2.0 in Nepali',
      );
    }
  });

  test('presentation states preserve core escalation semantics (D-17)', () {
    final confident = _confident();
    final uncertain = UncertainDiagnosis(
      title: 't',
      alternatives: const ['a'],
      escalationLabel: 'e',
      onEscalate: () {},
    );
    final outOfScope = OutOfScopeDiagnosis(
      guidance: 'g',
      cause: OutOfScopeCause.notCovered,
      retryLabel: 'r',
      onRetry: () {},
      escalationLabel: 'e',
      onEscalate: () {},
    );
    expect(confident.state.requiresEscalation, isFalse);
    expect(uncertain.state.requiresEscalation, isTrue);
    expect(outOfScope.state.requiresEscalation, isTrue);
    expect(confident.state.allowsAdvisory, isTrue);
    expect(uncertain.state.allowsAdvisory, isFalse);
  });
}
