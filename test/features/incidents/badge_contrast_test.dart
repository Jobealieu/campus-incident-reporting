import 'dart:math';
import 'dart:ui';

import 'package:campus_fix/features/incidents/domain/incident_enums.dart';
import 'package:campus_fix/features/incidents/presentation/widgets/incident_badges.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  const surfaces = {
    Brightness.light: Color(0xFFFFFFFF),
    Brightness.dark: Color(0xFF141218),
  };

  for (final MapEntry(key: brightness, value: surface) in surfaces.entries) {
    test('status badge text meets WCAG AA in $brightness mode', () {
      for (final status in IncidentStatus.values) {
        // Badge background: 14% of the status colour over the surface.
        final background = Color.alphaBlend(
          status.color.withValues(alpha: 0.14),
          surface,
        );
        final text = TintedBadge.readableOn(status.color, brightness);
        expect(
          _contrast(text, background),
          greaterThanOrEqualTo(4.5),
          reason: '${status.label} in $brightness mode',
        );
      }
    });
  }
}
