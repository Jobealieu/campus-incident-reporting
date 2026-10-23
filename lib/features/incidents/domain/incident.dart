import 'package:cloud_firestore/cloud_firestore.dart';

import 'incident_enums.dart';

/// A report stored at `incidents/{id}`.
class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.status,
    required this.reporterId,
    required this.isAnonymous,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
    this.priority,
    this.photoUrl,
    this.photoPath,
    this.upvoterIds = const [],
  });

  factory Incident.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    // Pending server timestamps read as null; _toDate falls back to now.
    final data = doc.data()!;
    return Incident(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: IncidentCategory.fromName(data['category'] as String?),
      location: data['location'] as String? ?? '',
      status: IncidentStatus.fromName(data['status'] as String?),
      priority: IncidentPriority.fromName(data['priority'] as String?),
      reporterId: data['reporterId'] as String? ?? '',
      reporterName: data['reporterName'] as String?,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      isPrivate: data['isPrivate'] as bool? ?? false,
      photoUrl: data['photoUrl'] as String?,
      photoPath: data['photoPath'] as String?,
      upvoterIds: List<String>.from(
        data['upvoterIds'] as List<dynamic>? ?? const <String>[],
      ),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  final String id;
  final String title;
  final String description;
  final IncidentCategory category;
  final String location;
  final IncidentStatus status;
  final IncidentPriority? priority;
  final String reporterId;

  /// Null when the report is anonymous.
  final String? reporterName;
  final bool isAnonymous;

  /// Private reports are visible only to the reporter and staff.
  final bool isPrivate;
  final String? photoUrl;
  final String? photoPath;
  final List<String> upvoterIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get upvoteCount => upvoterIds.length;

  bool get hasPhoto => photoUrl != null || photoPath != null;

  bool isReportedBy(String uid) => reporterId == uid;

  bool hasUpvoted(String uid) => upvoterIds.contains(uid);

  /// Reporters may edit or withdraw a report until staff start handling it.
  bool canBeChangedByReporter(String uid) =>
      isReportedBy(uid) && status == IncidentStatus.submitted;

  static DateTime _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
}

/// The fields a student fills in when creating a report.
class IncidentDraft {
  const IncidentDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.isAnonymous,
    required this.isPrivate,
  });

  final String title;
  final String description;
  final IncidentCategory category;
  final String location;
  final bool isAnonymous;
  final bool isPrivate;
}

/// One staff action on an incident, stored at `incidents/{id}/updates/{id}`.
/// Together these form the status timeline.
class StatusUpdate {
  const StatusUpdate({
    required this.id,
    required this.status,
    required this.authorName,
    required this.createdAt,
    this.note,
  });

  factory StatusUpdate.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final createdAt = data['createdAt'];
    return StatusUpdate(
      id: doc.id,
      status: IncidentStatus.fromName(data['status'] as String?),
      authorName: data['authorName'] as String? ?? 'Campus staff',
      note: data['note'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  final String id;
  final IncidentStatus status;
  final String authorName;
  final String? note;
  final DateTime createdAt;
}
