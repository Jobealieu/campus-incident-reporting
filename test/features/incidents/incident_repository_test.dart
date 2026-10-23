import 'dart:typed_data';

import 'package:campus_fix/features/auth/domain/app_user.dart';
import 'package:campus_fix/features/incidents/data/incident_repository.dart';
import 'package:campus_fix/features/incidents/data/photo_storage.dart';
import 'package:campus_fix/features/incidents/domain/incident.dart';
import 'package:campus_fix/features/incidents/domain/incident_enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePhotoStorage implements PhotoStorage {
  final deleted = <String>[];

  @override
  Future<UploadedPhoto> upload({
    required String ownerId,
    required String incidentId,
    required Uint8List bytes,
  }) async => UploadedPhoto(
    url: 'https://example.test/$incidentId.jpg',
    path: 'incidents/$ownerId/$incidentId.jpg',
  );

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

const _student = AppUser(
  uid: 'student1',
  email: 'amina@alustudent.com',
  displayName: 'Amina Hassan',
  role: UserRole.student,
);

const _staff = AppUser(
  uid: 'staff1',
  email: 'grace@alueducation.com',
  displayName: 'Grace Uwase',
  role: UserRole.staff,
);

IncidentDraft _draft({
  IncidentCategory category = IncidentCategory.water,
  bool isAnonymous = false,
  bool isPrivate = false,
}) => IncidentDraft(
  title: '  No water in residence  ',
  description: 'Taps on the second floor have been dry since morning.',
  category: category,
  location: 'Student Residence',
  isAnonymous: isAnonymous,
  isPrivate: isPrivate,
);

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakePhotoStorage photos;
  late IncidentRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    photos = _FakePhotoStorage();
    repository = IncidentRepository(firestore, photos);
    await firestore.doc('users/${_student.uid}').set({'role': 'student'});
  });

  Future<Map<String, dynamic>> readIncident(String id) async =>
      (await firestore.doc('incidents/$id').get()).data()!;

  group('create', () {
    test(
      'writes a trimmed, submitted report and stamps the reporter',
      () async {
        final id = await repository.create(draft: _draft(), reporter: _student);

        final data = await readIncident(id);
        expect(data['title'], 'No water in residence');
        expect(data['status'], 'submitted');
        expect(data['reporterId'], _student.uid);
        expect(data['reporterName'], 'Amina Hassan');
        expect(data['isPrivate'], isFalse);
        expect(data['photoUrl'], isNull);
        expect(data['upvoterIds'], isEmpty);

        final user = await firestore.doc('users/${_student.uid}').get();
        expect(user.data()!['lastReportAt'], isNotNull);
      },
    );

    test('hides the name of anonymous reporters', () async {
      final id = await repository.create(
        draft: _draft(isAnonymous: true),
        reporter: _student,
      );
      final data = await readIncident(id);
      expect(data['reporterName'], isNull);
      expect(data['isAnonymous'], isTrue);
    });

    test('forces safety reports to be private', () async {
      final id = await repository.create(
        draft: _draft(category: IncidentCategory.safety),
        reporter: _student,
      );
      expect((await readIncident(id))['isPrivate'], isTrue);
    });

    test('stores the uploaded photo location', () async {
      final id = await repository.create(
        draft: _draft(),
        reporter: _student,
        photo: Uint8List.fromList([1, 2, 3]),
      );
      final data = await readIncident(id);
      expect(data['photoPath'], 'incidents/student1/$id.jpg');
      expect(data['photoUrl'], contains(id));
    });
  });

  test(
    'watchPublic excludes private reports; watchReportedBy includes them',
    () async {
      await repository.create(draft: _draft(), reporter: _student);
      await repository.create(
        draft: _draft(isPrivate: true),
        reporter: _student,
      );

      expect(await repository.watchPublic().first, hasLength(1));
      expect(
        await repository.watchReportedBy(_student.uid).first,
        hasLength(2),
      );
    },
  );

  test('setUpvote adds and removes the voter', () async {
    final id = await repository.create(draft: _draft(), reporter: _student);

    await repository.setUpvote(incidentId: id, uid: 'student2', upvoted: true);
    var incident = (await repository.watchIncident(id).first)!;
    expect(incident.upvoterIds, ['student2']);

    await repository.setUpvote(incidentId: id, uid: 'student2', upvoted: false);
    incident = (await repository.watchIncident(id).first)!;
    expect(incident.upvoteCount, 0);
  });

  test('updateStatus changes the report and appends to the timeline', () async {
    final id = await repository.create(draft: _draft(), reporter: _student);

    await repository.updateStatus(
      incidentId: id,
      status: IncidentStatus.inProgress,
      priority: IncidentPriority.high,
      staff: _staff,
      note: '  Plumber booked for tomorrow  ',
    );

    final incident = (await repository.watchIncident(id).first)!;
    expect(incident.status, IncidentStatus.inProgress);
    expect(incident.priority, IncidentPriority.high);

    final updates = await repository.watchUpdates(id).first;
    expect(updates, hasLength(1));
    expect(updates.single.note, 'Plumber booked for tomorrow');
    expect(updates.single.authorName, 'Grace Uwase');
  });

  test('an empty note is stored as null', () async {
    final id = await repository.create(draft: _draft(), reporter: _student);
    await repository.updateStatus(
      incidentId: id,
      status: IncidentStatus.underReview,
      priority: null,
      staff: _staff,
      note: '   ',
    );
    final updates = await repository.watchUpdates(id).first;
    expect(updates.single.note, isNull);
  });

  test('delete removes the report, its timeline and its photo', () async {
    final id = await repository.create(
      draft: _draft(),
      reporter: _student,
      photo: Uint8List.fromList([1]),
    );
    await repository.updateStatus(
      incidentId: id,
      status: IncidentStatus.underReview,
      priority: null,
      staff: _staff,
    );
    final incident = (await repository.watchIncident(id).first)!;

    await repository.delete(incident);

    expect(await repository.watchIncident(id).first, isNull);
    expect(
      (await firestore.collection('incidents/$id/updates').get()).docs,
      isEmpty,
    );
    expect(photos.deleted, ['incidents/student1/$id.jpg']);
  });
}
