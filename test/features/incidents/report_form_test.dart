import 'package:campus_fix/features/incidents/presentation/report_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validates every field, even ones scrolled off screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportFormScreen())),
    );

    // Scroll to the bottom so the title field is far off screen, then submit.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);
    expect(find.text('Location is required'), findsOneWidget);
    expect(
      find.text('Choose the category that best fits the issue'),
      findsOneWidget,
    );

    // Fixing a field clears its error straight away.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Briefly describe the issue'),
      'Projector not working',
    );
    await tester.pump();
    expect(find.text('Title is required'), findsNothing);
  });
}
