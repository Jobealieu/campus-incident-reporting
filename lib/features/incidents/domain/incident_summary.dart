import 'incident.dart';
import 'incident_enums.dart';

/// Counts shown on the home dashboard.
class IncidentSummary {
  const IncidentSummary({
    required this.total,
    required this.submitted,
    required this.active,
    required this.resolved,
  });

  factory IncidentSummary.of(List<Incident> incidents) {
    int count(bool Function(IncidentStatus) test) =>
        incidents.where((incident) => test(incident.status)).length;
    return IncidentSummary(
      total: incidents.length,
      submitted: count((s) => s == IncidentStatus.submitted),
      active: count(
        (s) =>
            s == IncidentStatus.underReview || s == IncidentStatus.inProgress,
      ),
      resolved: count((s) => s == IncidentStatus.resolved),
    );
  }

  final int total;

  /// New reports nobody has picked up yet.
  final int submitted;

  /// Under review or in progress.
  final int active;
  final int resolved;
}
