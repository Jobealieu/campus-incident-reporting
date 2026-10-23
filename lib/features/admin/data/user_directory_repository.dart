import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/app_user.dart';

/// Lists users and changes roles. Security rules allow role changes by
/// admins only, and never on their own account.
class UserDirectoryRepository {
  UserDirectoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  // ponytail: one page of 500 users; add pagination for larger campuses.
  static const _limit = 500;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<AppUser>> watchAll() => _users
      .orderBy('displayName')
      .limit(_limit)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => AppUser.fromMap(doc.id, doc.data()))
            .toList(),
      );

  Future<void> setRole(String uid, UserRole role) =>
      _users.doc(uid).update({'role': role.name});
}
