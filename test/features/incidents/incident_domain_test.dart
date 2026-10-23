import 'package:campus_fix/features/incidents/domain/incident_enums.dart';
import 'package:campus_fix/features/incidents/domain/incident_filter.dart';
import 'package:campus_fix/features/incidents/domain/incident_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'incident_test_data.dart';

void main() {
  final water = buildIncident(
    id: 'water',
    title: 'No water',
    description: 'Taps are dry',
    location: 'Student Residence',
    category: IncidentCategory.water,
    status: IncidentStatus.inProgress,
  );
  final projector = buildIncident(id: 'projector');
  final light = buildIncident(
    id: 'light',
    title: 'Flickering light',
    description: 'The ceiling light keeps flickering.',
    location: 'Library',
    category: IncidentCategory.electricity,
    status: IncidentStatus.resolved,
  );
  final all = [water, projector, light];

  group('IncidentFilter', () {
    test('an empty filter matches everything', () {
      const filter = IncidentFilter();
      expect(filter.isActive, isFalse);
      expect(filter.apply(all), all);
    });

    test('searches title, description and location case-insensitively', () {
      expect(const IncidentFilter(query: 'LIBRARY').apply(all), [light]);
      expect(const IncidentFilter(query: 'dry').apply(all), [water]);
      expect(const IncidentFilter(query: 'projector').apply(all), [projector]);
    });

    test('combines status, category and search', () {
      const filter = IncidentFilter(
        query: 'no',
        status: IncidentStatus.inProgress,
        category: IncidentCategory.water,
      );
      expect(filter.apply(all), [water]);
    });

    test('copyWith can clear a field back to null', () {
      const filter = IncidentFilter(status: IncidentStatus.resolved);
      expect(filter.copyWith(status: () => null).status, isNull);
      expect(filter.copyWith(query: 'x').status, IncidentStatus.resolved);
    });
  });

  group('IncidentSummary', () {
    test('counts each stage', () {
      final summary = IncidentSummary.of([
        ...all,
        buildIncident(id: 'review', status: IncidentStatus.underReview),
        buildIncident(id: 'rejected', status: IncidentStatus.rejected),
      ]);
      expect(summary.total, 5);
      expect(summary.submitted, 1);
      expect(summary.active, 2);
      expect(summary.resolved, 1);
    });
  });

  group('Incident rules', () {
    test('reporters can change a report only while it is submitted', () {
      expect(projector.canBeChangedByReporter('student1'), isTrue);
      expect(projector.canBeChangedByReporter('someone-else'), isFalse);
      expect(water.canBeChangedByReporter('student1'), isFalse);
    });

    test('safety reports are always private', () {
      expect(IncidentCategory.safety.isAlwaysPrivate, isTrue);
      expect(IncidentCategory.water.isAlwaysPrivate, isFalse);
    });

    test('unknown enum values fall back safely', () {
      expect(IncidentStatus.fromName('bogus'), IncidentStatus.submitted);
      expect(IncidentCategory.fromName(null), IncidentCategory.other);
      expect(IncidentPriority.fromName('bogus'), isNull);
    });
  });
}
