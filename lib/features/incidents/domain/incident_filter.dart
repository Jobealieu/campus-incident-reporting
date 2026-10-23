import 'incident.dart';
import 'incident_enums.dart';

/// Search text plus optional status and category filters.
class IncidentFilter {
  const IncidentFilter({this.query = '', this.status, this.category});

  final String query;
  final IncidentStatus? status;
  final IncidentCategory? category;

  bool get isActive => query.isNotEmpty || status != null || category != null;

  IncidentFilter copyWith({
    String? query,
    IncidentStatus? Function()? status,
    IncidentCategory? Function()? category,
  }) => IncidentFilter(
    query: query ?? this.query,
    status: status != null ? status() : this.status,
    category: category != null ? category() : this.category,
  );

  bool matches(Incident incident) {
    if (status != null && incident.status != status) return false;
    if (category != null && incident.category != category) return false;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return incident.title.toLowerCase().contains(needle) ||
        incident.description.toLowerCase().contains(needle) ||
        incident.location.toLowerCase().contains(needle);
  }

  List<Incident> apply(List<Incident> incidents) =>
      incidents.where(matches).toList();
}
