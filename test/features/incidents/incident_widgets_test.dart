import 'package:campus_fix/features/incidents/domain/incident_enums.dart';
import 'package:campus_fix/features/incidents/presentation/widgets/incident_badges.dart';
import 'package:campus_fix/features/incidents/presentation/widgets/incident_card.dart';
import 'package:campus_fix/features/incidents/presentation/widgets/status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'incident_test_data.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('IncidentCard shows title, location, status and votes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        IncidentCard(
          incident: buildIncident(
            status: IncidentStatus.inProgress,
            upvoterIds: ['a', 'b'],
            isPrivate: true,
          ),
        ),
      ),
    );

    expect(find.text('Broken projector'), findsOneWidget);
    expect(find.text('Lecture Hall'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('StatusTimeline exposes progress to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(const StatusTimeline(status: IncidentStatus.inProgress)),
    );

    expect(
      find.bySemanticsLabel('Status: In progress, step 3 of 4'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('StatusTimeline explains rejected reports', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusTimeline(status: IncidentStatus.rejected)),
    );
    expect(find.textContaining('closed this report'), findsOneWidget);
  });

  testWidgets('StatusBadge renders every status label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            for (final status in IncidentStatus.values) StatusBadge(status),
          ],
        ),
      ),
    );
    for (final status in IncidentStatus.values) {
      expect(find.text(status.label), findsOneWidget);
    }
  });
}
