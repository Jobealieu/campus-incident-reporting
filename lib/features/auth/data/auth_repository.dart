import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/app_user.dart';
import '../domain/email_policy.dart';

class AuthRepository {
  AuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Emits on sign-in, sign-out, profile changes and token refreshes.
  Stream<User?> userChanges() => _auth.userChanges();

  Stream<AppUser?> watchProfile(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null);

  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        final normalized = _requireAluEmail(email);
        final credential = await _auth.signInWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        await _ensureProfile(credential.user!);
      });

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _guard(() async {
    final normalized = _requireAluEmail(email);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalized,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(name.trim());
    await _ensureProfile(user, displayName: name.trim());
    await user.sendEmailVerification();
  });

  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.sendPasswordResetEmail(email: _requireAluEmail(email)),
  );

  Future<void> resendVerificationEmail() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  /// Reloads the user and, once verified, refreshes the ID token so
  /// security rules see `email_verified == true` immediately.
  Future<bool> refreshVerificationStatus() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return false;
    await refreshed.getIdToken(true);
    return true;
  });

  Future<void> signOut() => _auth.signOut();

  /// Creates the profile if sign-up was interrupted before it was written.
  /// New accounts are always students; only an admin can promote them.
  Future<void> _ensureProfile(User user, {String? displayName}) async {
    final doc = _users.doc(user.uid);
    if ((await doc.get()).exists) return;
    await doc.set({
      'email': user.email,
      'displayName': displayName ?? user.displayName ?? 'ALU member',
      'role': UserRole.student.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _requireAluEmail(String email) {
    if (!EmailPolicy.isAluEmail(email)) {
      throw const AppException('Only ALU email addresses can use CampusFix.');
    }
    return EmailPolicy.normalize(email);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AppException(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Incorrect email or password.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password.',
    'invalid-email' => 'That email address is not valid.',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' => 'Check your internet connection.',
    'user-disabled' => 'This account has been disabled.',
    _ => 'Authentication failed. Please try again.',
  };
}
