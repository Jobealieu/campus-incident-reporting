import 'package:flutter/material.dart';

import '../../domain/incident_enums.dart';
import 'incident_badges.dart';

/// Horizontal progress through Submitted → Under review → In progress →
/// Resolved. Rejected reports show a banner instead.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({required this.status, super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (status == IncidentStatus.rejected) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(status.icon, color: status.color),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Staff closed this report without action. See the activity '
                'below for the reason.',
              ),
            ),
          ],
        ),
      );
    }

    const steps = IncidentStatus.timeline;
    final current = steps.indexOf(status);

    return Semantics(
      label: 'Status: ${status.label}, step ${current + 1} of ${steps.length}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox()
                            : _Connector(done: i <= current),
                      ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: i <= current
                            ? steps[i].color
                            : scheme.surfaceContainerHighest,
                        child: Icon(
                          i < current ? Icons.check_rounded : steps[i].icon,
                          size: 16,
                          color: i <= current
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: i == steps.length - 1
                            ? const SizedBox()
                            : _Connector(done: i < current),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: i <= current
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 3,
      color: done ? scheme.primary : scheme.surfaceContainerHighest,
    );
  }
}
