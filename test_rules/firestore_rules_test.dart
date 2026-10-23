// Security rules tests. They run against the Firestore emulator:
//
//   firebase emulators:exec --only firestore --project demo-campusfix \
//     "flutter test test_rules"
//
// Requests go through the emulator's REST API with unsigned ID tokens, which
// the emulator accepts, so each test can act as any user.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _project = 'demo-campusfix';
const _host = 'http://127.0.0.1:8080';
const _docs = 'projects/$_project/databases/(default)/documents';

class _User {
  const _User(this.uid, this.email, {this.verified = true});

  final String uid;
  final String email;
  final bool verified;

  String get token {
    String encode(Map<String, Object?> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({
      'iss': 'https://securetoken.google.com/$_project',
      'aud': _project,
      'sub': uid,
      'user_id': uid,
      'email': email,
      'email_verified': verified,
      'iat': now,
      'exp': now + 3600,
      'firebase': {'sign_in_provider': 'password'},
    })}.';
  }
}

const student = _User('student1', 'amina@alustudent.com');
const otherStudent = _User('student2', 'kofi@alustudent.com');
const staff = _User('staff1', 'facilities@alueducation.com');
const admin = _User('admin1', 'dean@alueducation.com');
const unverified = _User('student3', 'new@alustudent.com', verified: false);
const outsider = _User('outsider', 'someone@gmail.com');

final _client = HttpClient();

Future<int> _send(
  String method,
  String path, {
  String? token,
  Map<String, Object?>? body,
}) async {
  final request = await _client.openUrl(method, Uri.parse('$_host/$path'));
  request.headers.set('Authorization', 'Bearer ${token ?? 'owner'}');
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  await response.drain<void>();
  return response.statusCode;
}

Map<String, Object?> _value(Object? value) => switch (value) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int i => {'integerValue': '$i'},
  String s => {'stringValue': s},
  List<Object?> list => {
    'arrayValue': {'values': list.map(_value).toList()},
  },
  _ => throw ArgumentError(value),
};

Map<String, Object?> _fields(Map<String, Object?> data) => {
  for (final entry in data.entries) entry.key: _value(entry.value),
};

/// One write in a commit. [serverTime] fields are set to request.time.
Map<String, Object?> _write(
  String path,
  Map<String, Object?> data, {
  List<String> serverTime = const [],
  bool merge = false,
}) => {
  'update': {'name': '$_docs/$path', 'fields': _fields(data)},
  if (merge) 'updateMask': {'fieldPaths': data.keys.toList()},
  if (serverTime.isNotEmpty)
    'updateTransforms': [
      for (final field in serverTime)
        {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'},
    ],
};

/// 200 → allowed, 403 → denied by rules. Anything else means the test itself
/// sent a bad request, so fail loudly instead of passing as "denied".
bool _allowed(int status) => switch (status) {
  200 => true,
  403 => false,
  _ => throw StateError('Unexpected HTTP $status from emulator'),
};

/// Returns true when the rules allow the whole batch.
Future<bool> _commit(_User? user, List<Map<String, Object?>> writes) async =>
    _allowed(
      await _send(
        'POST',
        'v1/$_docs:commit',
        token: user?.token,
        body: {'writes': writes},
      ),
    );

Future<bool> _read(_User user, String path) async =>
    _allowed(await _send('GET', 'v1/$_docs/$path', token: user.token));

Future<bool> _delete(_User user, String path) => _commit(user, [
  {'delete': '$_docs/$path'},
]);

/// Seeds data as an admin of the emulator, bypassing rules.
Future<void> _seed(String path, Map<String, Object?> data) async {
  final ok = await _commit(null, [_write(path, data)]);
  if (!ok) throw StateError('Seeding $path failed');
}

Future<void> _seedUser(_User user, String role, {String? name}) => _seed(
  'users/${user.uid}',
  {'email': user.email, 'displayName': name ?? user.uid, 'role': role},
);

Map<String, Object?> _incident(
  _User reporter, {
  String category = 'water',
  bool isPrivate = false,
  bool isAnonymous = false,
  String? reporterName,
  String status = 'submitted',
}) => {
  'title': 'No water in residence',
  'description': 'Taps on the second floor have been dry since morning.',
  'category': category,
  'location': 'Student Residence',
  'status': status,
  'priority': null,
  'reporterId': reporter.uid,
  'reporterName': isAnonymous ? null : (reporterName ?? reporter.uid),
  'isAnonymous': isAnonymous,
  'isPrivate': isPrivate,
  'photoUrl': null,
  'photoPath': null,
  'upvoterIds': <String>[],
};

/// The same batch the app sends: the report plus the reporter's rate-limit
/// stamp.
Future<bool> _createIncident(
  _User user,
  String id,
  Map<String, Object?> data,
) => _commit(user, [
  _write('incidents/$id', data, serverTime: ['createdAt', 'updatedAt']),
  _write('users/${user.uid}', {}, serverTime: ['lastReportAt'], merge: true),
]);

void main() {
  setUp(() async {
    await _send(
      'DELETE',
      'emulator/v1/projects/$_project/databases/(default)/documents',
    );
    await _seedUser(student, 'student');
    await _seedUser(otherStudent, 'student');
    await _seedUser(staff, 'staff');
    await _seedUser(admin, 'admin');
  });

  tearDownAll(() => _client.close(force: true));

  group('users', () {
    test('a new ALU user can create a student profile', () async {
      expect(
        await _commit(unverified, [
          _write(
            'users/${unverified.uid}',
            {
              'email': unverified.email,
              'displayName': 'New Student',
              'role': 'student',
            },
            serverTime: ['createdAt'],
          ),
        ]),
        isTrue,
      );
    });

    test('nobody can sign up as staff', () async {
      expect(
        await _commit(unverified, [
          _write(
            'users/${unverified.uid}',
            {
              'email': unverified.email,
              'displayName': 'New Student',
              'role': 'staff',
            },
            serverTime: ['createdAt'],
          ),
        ]),
        isFalse,
      );
    });

    test('non-ALU emails cannot create a profile', () async {
      expect(
        await _commit(outsider, [
          _write(
            'users/${outsider.uid}',
            {
              'email': outsider.email,
              'displayName': 'Outsider',
              'role': 'student',
            },
            serverTime: ['createdAt'],
          ),
        ]),
        isFalse,
      );
    });

    test('students cannot promote themselves', () async {
      expect(
        await _commit(student, [
          _write('users/${student.uid}', {'role': 'admin'}, merge: true),
        ]),
        isFalse,
      );
    });

    test('admins can promote another user to staff', () async {
      expect(
        await _commit(admin, [
          _write('users/${student.uid}', {'role': 'staff'}, merge: true),
        ]),
        isTrue,
      );
    });

    test('staff cannot change roles', () async {
      expect(
        await _commit(staff, [
          _write('users/${student.uid}', {'role': 'staff'}, merge: true),
        ]),
        isFalse,
      );
    });

    test('students cannot read other profiles; staff can', () async {
      expect(await _read(student, 'users/${otherStudent.uid}'), isFalse);
      expect(await _read(staff, 'users/${student.uid}'), isTrue);
    });
  });

  group('creating incidents', () {
    test('a verified student can submit a report', () async {
      expect(await _createIncident(student, 'r1', _incident(student)), isTrue);
    });

    test('unverified accounts cannot submit', () async {
      await _seedUser(unverified, 'student');
      expect(
        await _createIncident(unverified, 'r1', _incident(unverified)),
        isFalse,
      );
    });

    test('a second report within a minute is rejected', () async {
      expect(await _createIncident(student, 'r1', _incident(student)), isTrue);
      expect(await _createIncident(student, 'r2', _incident(student)), isFalse);
    });

    test('reports cannot be filed in someone else\'s name', () async {
      expect(
        await _createIncident(
          student,
          'r1',
          _incident(otherStudent, reporterName: student.uid),
        ),
        isFalse,
      );
    });

    test('reporters cannot impersonate another display name', () async {
      expect(
        await _createIncident(
          student,
          'r1',
          _incident(student, reporterName: 'Campus Dean'),
        ),
        isFalse,
      );
    });

    test('anonymous reports must not carry a name', () async {
      final data = _incident(student, isAnonymous: true)
        ..['reporterName'] = student.uid;
      expect(await _createIncident(student, 'r1', data), isFalse);
    });

    test('safety reports must be private', () async {
      expect(
        await _createIncident(
          student,
          'r1',
          _incident(student, category: 'safety'),
        ),
        isFalse,
      );
      expect(
        await _createIncident(
          student,
          'r2',
          _incident(student, category: 'safety', isPrivate: true),
        ),
        isTrue,
      );
    });

    test('new reports cannot start as resolved', () async {
      expect(
        await _createIncident(
          student,
          'r1',
          _incident(student, status: 'resolved'),
        ),
        isFalse,
      );
    });
  });

  group('reading incidents', () {
    setUp(() async {
      await _seed('incidents/public', _incident(student));
      await _seed('incidents/private', _incident(student, isPrivate: true));
    });

    test('everyone verified can read public reports', () async {
      expect(await _read(otherStudent, 'incidents/public'), isTrue);
    });

    test('private reports are hidden from other students', () async {
      expect(await _read(otherStudent, 'incidents/private'), isFalse);
      expect(await _read(student, 'incidents/private'), isTrue);
      expect(await _read(staff, 'incidents/private'), isTrue);
    });

    test('non-ALU accounts read nothing', () async {
      expect(await _read(outsider, 'incidents/public'), isFalse);
    });
  });

  group('updating incidents', () {
    setUp(() => _seed('incidents/r1', _incident(student)));

    Map<String, Object?> statusChange(_User author, String status) => {
      'writes': [
        _write(
            'incidents/r1',
            {'status': status, 'priority': 'high'},
            serverTime: ['updatedAt'],
            merge: true,
          )
          ..['updateMask'] = {
            'fieldPaths': ['status', 'priority'],
          },
        _write(
          'incidents/r1/updates/u1',
          {
            'status': status,
            'note': 'Plumber booked for tomorrow',
            'authorId': author.uid,
            'authorName': author.uid,
          },
          serverTime: ['createdAt'],
        ),
      ],
    };

    test('staff can change status with a timeline entry', () async {
      final body = statusChange(staff, 'inProgress');
      expect(await _commit(staff, (body['writes']! as List).cast()), isTrue);
    });

    test('students cannot change status', () async {
      final body = statusChange(student, 'resolved');
      expect(await _commit(student, (body['writes']! as List).cast()), isFalse);
    });

    test('reporters can edit details while submitted', () async {
      expect(
        await _commit(student, [
          _write(
            'incidents/r1',
            {'title': 'No water on floor two'},
            serverTime: ['updatedAt'],
            merge: true,
          ),
        ]),
        isTrue,
      );
    });

    test('other students cannot edit a report', () async {
      expect(
        await _commit(otherStudent, [
          _write(
            'incidents/r1',
            {'title': 'Hijacked title'},
            serverTime: ['updatedAt'],
            merge: true,
          ),
        ]),
        isFalse,
      );
    });

    test('students can add their own "me too" vote', () async {
      expect(
        await _commit(otherStudent, [
          _write('incidents/r1', {
            'upvoterIds': [otherStudent.uid],
          }, merge: true),
        ]),
        isTrue,
      );
    });

    test('votes cannot be cast for someone else', () async {
      expect(
        await _commit(otherStudent, [
          _write('incidents/r1', {
            'upvoterIds': [staff.uid],
          }, merge: true),
        ]),
        isFalse,
      );
    });

    test('reporters cannot upvote their own report', () async {
      expect(
        await _commit(student, [
          _write('incidents/r1', {
            'upvoterIds': [student.uid],
          }, merge: true),
        ]),
        isFalse,
      );
    });
  });

  group('deleting incidents', () {
    test('reporters can withdraw a submitted report', () async {
      await _seed('incidents/r1', _incident(student));
      expect(await _delete(student, 'incidents/r1'), isTrue);
    });

    test('reporters cannot delete once staff are working on it', () async {
      await _seed('incidents/r1', _incident(student, status: 'inProgress'));
      expect(await _delete(student, 'incidents/r1'), isFalse);
    });

    test('other students cannot delete a report', () async {
      await _seed('incidents/r1', _incident(student));
      expect(await _delete(otherStudent, 'incidents/r1'), isFalse);
    });

    test('staff can remove any report', () async {
      await _seed('incidents/r1', _incident(student, status: 'inProgress'));
      expect(await _delete(staff, 'incidents/r1'), isTrue);
    });
  });
}
