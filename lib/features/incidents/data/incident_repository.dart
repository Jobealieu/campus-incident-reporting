import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/domain/app_user.dart';
import '../domain/incident.dart';
import '../domain/incident_enums.dart';
import 'photo_storage.dart';

/// All Firestore reads and writes for incidents and their status updates.
class IncidentRepository {
  IncidentRepository(this._firestore, this._photos);

  final FirebaseFirestore _firestore;
  final PhotoStore _photos;

  // ponytail: newest 200 per feed, searched client-side. Add cursor
  // pagination (startAfterDocument) when a feed regularly exceeds this.
  static const feedLimit = 200;

  CollectionReference<Map<String, dynamic>> get _incidents =>
      _firestore.collection('incidents');

  CollectionReference<Map<String, dynamic>> _updates(String incidentId) =>
      _incidents.doc(incidentId).collection('updates');

  Stream<List<Incident>> watchPublic() =>
      _watchList(_incidents.where('isPrivate', isEqualTo: false));

  /// Every report, including private ones. Security rules allow this for
  /// staff only.
  Stream<List<Incident>> watchAll() => _watchList(_incidents);

  Stream<List<Incident>> watchReportedBy(String uid) =>
      _watchList(_incidents.where('reporterId', isEqualTo: uid));

  Stream<Incident?> watchIncident(String id) => _incidents
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Incident.fromFirestore(doc) : null);

  Stream<List<StatusUpdate>> watchUpdates(String incidentId) =>
      _updates(incidentId)
          .orderBy('createdAt')
          .snapshots()
          .map((snap) => snap.docs.map(StatusUpdate.fromFirestore).toList());

  /// Uploads the optional photo, then writes the report and the reporter's
  /// `lastReportAt` in one batch so the rate limit in the rules can check it.
  Future<String> create({
    required IncidentDraft draft,
    required AppUser reporter,
    Uint8List? photo,
  }) async {
    final doc = _incidents.doc();
    final uploaded = photo == null
        ? null
        : await _photos.upload(
            ownerId: reporter.uid,
            incidentId: doc.id,
            bytes: photo,
          );

    final batch = _firestore.batch()
      ..set(doc, {
        'title': draft.title.trim(),
        'description': draft.description.trim(),
        'category': draft.category.name,
        'location': draft.location.trim(),
        'status': IncidentStatus.submitted.name,
        'priority': null,
        'reporterId': reporter.uid,
        'reporterName': draft.isAnonymous ? null : reporter.displayName,
        'isAnonymous': draft.isAnonymous,
        'isPrivate': draft.isPrivate || draft.category.isAlwaysPrivate,
        'photoUrl': uploaded?.url,
        'photoPath': uploaded?.path,
        'upvoterIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..update(_firestore.collection('users').doc(reporter.uid), {
        'lastReportAt': FieldValue.serverTimestamp(),
      });

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (uploaded != null) await _photos.delete(uploaded.path);
      if (e.code == 'permission-denied') {
        throw const AppException(
          'You can submit one report per minute. Please wait and try again.',
        );
      }
      rethrow;
    }
    return doc.id;
  }

  Future<void> updateDetails({
    required String incidentId,
    required String title,
    required String description,
    required String location,
  }) => _incidents.doc(incidentId).update({
    'title': title.trim(),
    'description': description.trim(),
    'location': location.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// "Me too": lets students confirm an issue instead of filing duplicates.
  Future<void> setUpvote({
    required String incidentId,
    required String uid,
    required bool upvoted,
  }) => _incidents.doc(incidentId).update({
    'upvoterIds': upvoted
        ? FieldValue.arrayUnion([uid])
        : FieldValue.arrayRemove([uid]),
  });

  /// Changes status/priority and appends a timeline entry atomically.
  Future<void> updateStatus({
    required String incidentId,
    required IncidentStatus status,
    required IncidentPriority? priority,
    required AppUser staff,
    String? note,
  }) {
    final trimmedNote = note?.trim();
    return (_firestore.batch()
          ..update(_incidents.doc(incidentId), {
            'status': status.name,
            'priority': priority?.name,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(_updates(incidentId).doc(), {
            'status': status.name,
            'note': (trimmedNote?.isEmpty ?? true) ? null : trimmedNote,
            'authorId': staff.uid,
            'authorName': staff.displayName,
            'createdAt': FieldValue.serverTimestamp(),
          }))
        .commit();
  }

  /// Deletes the report, its timeline and its photo.
  Future<void> delete(Incident incident) async {
    final updates = await _updates(incident.id).get();
    final batch = _firestore.batch();
    for (final doc in updates.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_incidents.doc(incident.id));
    await batch.commit();
    if (incident.photoPath != null) await _photos.delete(incident.photoPath!);
  }

  Stream<List<Incident>> _watchList(Query<Map<String, dynamic>> query) => query
      .orderBy('createdAt', descending: true)
      .limit(feedLimit)
      .snapshots()
      .map((snap) => snap.docs.map(Incident.fromFirestore).toList());
}
