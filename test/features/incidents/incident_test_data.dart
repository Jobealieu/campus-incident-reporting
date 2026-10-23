import 'package:campus_fix/features/incidents/domain/incident.dart';
import 'package:campus_fix/features/incidents/domain/incident_enums.dart';

Incident buildIncident({
  String id = 'i1',
  String title = 'Broken projector',
  String description = 'The projector in the lecture hall will not turn on.',
  String location = 'Lecture Hall',
  IncidentCategory category = IncidentCategory.facilities,
  IncidentStatus status = IncidentStatus.submitted,
  String reporterId = 'student1',
  bool isPrivate = false,
  List<String> upvoterIds = const [],
  DateTime? createdAt,
}) {
  final time = createdAt ?? DateTime(2026, 10, 20);
  return Incident(
    id: id,
    title: title,
    description: description,
    category: category,
    location: location,
    status: status,
    reporterId: reporterId,
    reporterName: 'Amina Hassan',
    isAnonymous: false,
    isPrivate: isPrivate,
    upvoterIds: upvoterIds,
    createdAt: time,
    updatedAt: time,
  );
}
