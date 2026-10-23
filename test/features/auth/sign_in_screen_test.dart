import 'package:campus_fix/core/errors/app_exception.dart';
import 'package:campus_fix/features/auth/application/auth_providers.dart';
import 'package:campus_fix/features/auth/data/auth_repository.dart';
import 'package:campus_fix/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.error});

  final Object? error;
  final signInCalls = <(String, String)>[];

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add((email, password));
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeAuthRepository> _pumpSignIn(
  WidgetTester tester, {
  Object? error,
}) async {
  final repository = _FakeAuthRepository(error: error);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: SignInScreen()),
    ),
  );
  return repository;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('shows validation errors and does not call Firebase', (
    tester,
  ) async {
    final repository = await _pumpSignIn(tester);

    await tester.enterText(_field('ALU email'), 'someone@gmail.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.textContaining('Use your ALU email'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repository.signInCalls, isEmpty);
  });

  testWidgets('signs in with valid ALU credentials', (tester) async {
    final repository = await _pumpSignIn(tester);

    await tester.enterText(_field('ALU email'), 'a.jobe@alustudent.com');
    await tester.enterText(_field('Password'), 'campus2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(repository.signInCalls, [('a.jobe@alustudent.com', 'campus2026')]);
  });

  testWidgets('shows a friendly error when sign-in fails', (tester) async {
    await _pumpSignIn(
      tester,
      error: const AppException('Incorrect email or password.'),
    );

    await tester.enterText(_field('ALU email'), 'a.jobe@alustudent.com');
    await tester.enterText(_field('Password'), 'wrongpass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });
}
