import 'package:campus_fix/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget pageFor(AsyncValue<int> value) => MaterialApp(
    home: AsyncPageView(
      value: value,
      title: 'Incident details',
      data: (n) => Text('data $n'),
    ),
  );

  testWidgets('loading and error states get a full page with a title', (
    tester,
  ) async {
    await tester.pumpWidget(pageFor(const AsyncLoading()));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Incident details'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      pageFor(AsyncError(Exception('unavailable'), StackTrace.empty)),
    );
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.pumpWidget(pageFor(const AsyncData(3)));
    expect(find.text('data 3'), findsOneWidget);
  });
}
