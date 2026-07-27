import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: kdLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('confident shows disease and certainty, no escalation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DiagnosisResultView(
          presentation: ConfidentDiagnosis(
            diseaseName: 'Late blight',
            certaintyLabel: 'Very likely',
          ),
        ),
      ),
    );
    expect(find.text('Late blight'), findsOneWidget);
    expect(find.text('Very likely'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('uncertain shows every alternative and escalation triggers', (
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

  testWidgets('out-of-scope shows guidance and retry triggers', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        DiagnosisResultView(
          presentation: OutOfScopeDiagnosis(
            guidance: 'We could not assess this photo.',
            retryLabel: 'Take another photo',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('We could not assess this photo.'), findsOneWidget);
    await tester.tap(find.text('Take another photo'));
    expect(retried, isTrue);
  });

  test('presentation states preserve core escalation semantics (D-17)', () {
    const confident = ConfidentDiagnosis(diseaseName: 'x', certaintyLabel: 'y');
    final uncertain = UncertainDiagnosis(
      title: 't',
      alternatives: const ['a'],
      escalationLabel: 'e',
      onEscalate: () {},
    );
    final outOfScope = OutOfScopeDiagnosis(
      guidance: 'g',
      retryLabel: 'r',
      onRetry: () {},
    );
    expect(confident.state.requiresEscalation, isFalse);
    expect(uncertain.state.requiresEscalation, isTrue);
    expect(outOfScope.state.requiresEscalation, isTrue);
    expect(confident.state.allowsAdvisory, isTrue);
    expect(uncertain.state.allowsAdvisory, isFalse);
  });
}
