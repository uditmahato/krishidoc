import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/notebook/notebook_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('work can be added and completed locally', (tester) async {
    final services = await pumpApp(tester, locale: const Locale('en'));

    await tester.scrollUntilVisible(
      find.byKey(homeAddWorkKey),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(homeAddWorkKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Check irrigation line');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    var stored = await services.farmTaskStore.recent();
    expect(stored, hasLength(1));
    expect(stored.single.title, 'Check irrigation line');
    expect(stored.single.kind, FarmTaskKind.work);
    expect(find.text('Check irrigation line'), findsOneWidget);

    // Let the save confirmation clear before interacting with the row beneath
    // it, then make the checkbox explicitly visible on compact screens.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    stored = await services.farmTaskStore.recent();
    expect(stored.single.isCompleted, isTrue);
  });

  testWidgets('a question is saved honestly, not sent', (tester) async {
    final services = await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeAskTabKey));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Questions are saved here for you. They are not sent to an expert yet.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(homeSaveQuestionKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Why are the lower leaves yellow?',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = await services.farmTaskStore.recent();
    expect(stored.single.kind, FarmTaskKind.question);
    expect(stored.single.title, 'Why are the lower leaves yellow?');
  });

  testWidgets('Profile opens the real photo notebook', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeProfileTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(homeViewAllPhotosKey));
    await tester.pumpAndSettle();

    expect(find.byType(NotebookScreen), findsOneWidget);
  });
}
