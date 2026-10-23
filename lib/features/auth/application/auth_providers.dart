import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

/// The signed-in user's Firestore profile (role, name), or null when signed out.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider.select((user) => user.value?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});

/// Any user's profile. Security rules allow this for the user and staff only,
/// so staff can see who filed an anonymous report.
final userProfileProvider = StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) => ref.watch(authRepositoryProvider).watchProfile(uid),
);

/// Runs auth actions and exposes their loading/error state to the UI.
class AuthController extends AsyncNotifier<void> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  FutureOr<void> build() {}

  Future<bool> signIn(String email, String password) =>
      _run(() => _repository.signIn(email: email, password: password));

  Future<bool> signUp(String name, String email, String password) => _run(
    () => _repository.signUp(name: name, email: email, password: password),
  );

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repository.sendPasswordReset(email));

  Future<bool> resendVerificationEmail() =>
      _run(_repository.resendVerificationEmail);

  Future<void> signOut() => _run(_repository.signOut);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
