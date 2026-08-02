import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/welcome/welcome_about_screen.dart';

import 'helpers/pump_app.dart';

const _timeout = Timeout(Duration(minutes: 1));

/// Home has two tap targets and both of them go somewhere.
///
/// The useful-choice ratio moves from one live destination in five tap
/// targets to two in two, and no tap on Home produces a snackbar. That is the
/// trade this module makes: Home is visibly emptier, and everything left on
/// it is true.
void main() {
  testWidgets('the not-ready row opens the explanation', timeout: _timeout, (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeNotReadyKey));
    await tester.pumpAndSettle();

    // Not inert, and not a snackbar. A block that swallows the tap at the
    // biggest tap magnet on the screen cannot be told from a frozen phone.
    expect(find.byType(WelcomeAboutScreen), findsOneWidget);
  });

  testWidgets('the history row opens history', timeout: _timeout, (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeHistoryKey));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsWidgets);
  });

  testWidgets(
    'both rows are buttons a screen reader can press',
    timeout: _timeout,
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, locale: const Locale('en'));

      for (final key in [homeNotReadyKey, homeHistoryKey]) {
        final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
        expect(data.hasFlag(SemanticsFlag.isButton), isTrue, reason: '$key');
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason: '$key announces as a button but carries no tap action',
        );
      }
      handle.dispose();
    },
  );

  testWidgets(
    'the not-ready row speaks its reason, and is not disabled',
    timeout: _timeout,
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, locale: const Locale('en'));

      final data = tester
          .getSemantics(find.byKey(homeNotReadyKey))
          .getSemanticsData();
      expect(
        data.label,
        'Check a leaf. This is not ready yet.',
        reason: 'the reason must arrive in the same breath as the name',
      );
      // It navigates, so it must never be ANNOUNCED as disabled. Note this is
      // not `isEnabled == true`: leaving `enabled` unset gives the node no
      // enabled state at all, which is the correct and intended shape. The
      // defect being guarded against is the other one, a node that carries an
      // enabled state and reports itself off while the control still works.
      final marksDisabled =
          data.hasFlag(SemanticsFlag.hasEnabledState) &&
          !data.hasFlag(SemanticsFlag.isEnabled);
      expect(
        marksDisabled,
        isFalse,
        reason: 'TalkBack would announce a disabled control that then works',
      );
      handle.dispose();
    },
  );

  test('home_screen.dart raises no snackbar', () {
    // A source guard, scoped to this one file rather than repo wide. A
    // blanket ban would foreclose a success acknowledgement elsewhere that
    // has not been decided against; what is settled is that no tap on Home
    // may end in a message that evaporates after four seconds.
    final source = File('lib/src/home_screen.dart').readAsStringSync();
    expect(
      source.contains('showSnackBar'),
      isFalse,
      reason: 'a tap on Home must reach a destination, not a snackbar',
    );
    expect(
      source.contains('ScaffoldMessenger'),
      isFalse,
      reason: 'the messenger was only ever here to carry the coming-soon lie',
    );
  });
}
