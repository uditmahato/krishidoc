import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ResultState', () {
    test('only confident allows advisory (D-21)', () {
      expect(ResultState.confident.allowsAdvisory, isTrue);
      expect(ResultState.uncertain.allowsAdvisory, isFalse);
      expect(ResultState.outOfScope.allowsAdvisory, isFalse);
    });

    test('uncertain and out-of-scope require escalation (D-17)', () {
      expect(ResultState.confident.requiresEscalation, isFalse);
      expect(ResultState.uncertain.requiresEscalation, isTrue);
      expect(ResultState.outOfScope.requiresEscalation, isTrue);
    });

    test(
      'advisory and escalation are mutually exclusive across all states',
      () {
        for (final state in ResultState.values) {
          expect(state.allowsAdvisory, isNot(state.requiresEscalation));
        }
      },
    );
  });
}
