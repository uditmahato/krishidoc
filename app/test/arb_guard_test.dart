import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A re-introduction guard, and stated honestly as one.
///
/// This does not discover a coming-soon string; it stops one coming back. The
/// tiles that promised features this build cannot perform were deleted along
/// with their strings, and deleting the strings is the part that makes the
/// tiles hard to re-add: a new tile now has nothing to label itself with, and
/// a new promise has to pass through here first.
void main() {
  const banned = <String>['coming soon', 'चाँडै', 'जल्द'];
  const locales = <String>['en', 'ne', 'hi'];

  /// Keys retired in Module 13. A stale value left in one ARB and not the
  /// others is how two locales come to disagree about what the app claims.
  const retired = <String>[
    'homeTagline',
    'tileDiagnose',
    'tileAsk',
    'tileSettings',
    'comingSoon',
    'historyEmpty',
    'aboutNotReadyBody',
  ];

  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('no locale promises a feature by date or by "soon"', () {
    for (final locale in locales) {
      final arb = load(locale);
      for (final entry in arb.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final value = (entry.value as String).toLowerCase();
        for (final phrase in banned) {
          expect(
            value.contains(phrase),
            isFalse,
            reason:
                '$locale/${entry.key} contains "$phrase". A promise the build '
                'cannot keep is the defect this module deleted, not a string '
                'to reword.',
          );
        }
      }
    }
  });

  test('the retired keys are gone from every locale', () {
    for (final locale in locales) {
      final arb = load(locale);
      for (final key in retired) {
        expect(
          arb.containsKey(key),
          isFalse,
          reason: '$locale still carries $key, retired in Module 13',
        );
      }
    }
  });

  test('every locale carries exactly the template keys', () {
    // Catches the other direction: a key added to en and forgotten in ne or
    // hi renders as English inside a Nepali screen, which reads as a bug in
    // the app rather than a gap in the translation.
    final template = load('en').keys.where((k) => !k.startsWith('@')).toSet();
    for (final locale in <String>['ne', 'hi']) {
      final keys = load(locale).keys.where((k) => !k.startsWith('@')).toSet();
      expect(
        keys.difference(template),
        isEmpty,
        reason: '$locale has keys the template does not',
      );
      expect(
        template.difference(keys),
        isEmpty,
        reason: '$locale is missing keys the template has',
      );
    }
  });
}
