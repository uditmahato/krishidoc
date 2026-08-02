import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/router.dart';
import 'package:krishidoc_app/src/welcome/first_run.dart';

/// The boot decision, over its whole truth table.
///
/// No widget is pumped. The decision is a pure function precisely so that the
/// one branch a farmer cannot recover from without a reinstall can be checked
/// exhaustively rather than sampled through a screen.
void main() {
  group('initialLocationFor', () {
    test('nothing stored sends a first-time reader to the chooser', () {
      expect(initialLocationFor(null), AppRoutes.welcomeLanguage);
    });

    test('a stored language goes straight home', () {
      expect(initialLocationFor('ne'), AppRoutes.home);
      expect(initialLocationFor('hi'), AppRoutes.home);
      expect(initialLocationFor('en'), AppRoutes.home);
    });

    test('a language we do not ship degrades to the chooser', () {
      // A 'bn' written by a future build that shipped Bengali and was then
      // rolled back. Asking again is the only honest answer: we cannot render
      // what was chosen, and silently substituting English would be a
      // decision made on the reader's behalf.
      expect(initialLocationFor('bn'), AppRoutes.welcomeLanguage);
    });

    test('an empty string is not a choice', () {
      expect(initialLocationFor(''), AppRoutes.welcomeLanguage);
      expect(initialLocationFor('   '), AppRoutes.welcomeLanguage);
    });

    test('case and surrounding space do not lose a real choice', () {
      // fromCode trims and lowercases. Asserted here because the cost of
      // being wrong is asymmetric: re-asking a reader who already answered is
      // a visible bug, and it would only appear on devices whose stored value
      // came from somewhere other than our own writer.
      expect(initialLocationFor('NE'), AppRoutes.home);
      expect(initialLocationFor(' hi '), AppRoutes.home);
    });
  });
}
