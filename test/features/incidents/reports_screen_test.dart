import 'package:campus_fix/features/incidents/application/incident_providers.dart';
import 'package:campus_fix/features/incidents/presentation/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closing the category sheet does not reopen the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleIncidentsProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );

    await tester.tap(find.byType(SearchBar));
    await tester.enterText(find.byType(SearchBar), 'wi-fi');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    expect(find.text('Water'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
