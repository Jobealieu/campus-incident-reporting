import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/incidents/presentation/home_screen.dart';
import '../../features/incidents/presentation/incident_detail_screen.dart';
import '../../features/incidents/presentation/report_form_screen.dart';
import '../../features/incidents/presentation/reports_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';
import 'splash_screen.dart';

const _publicRoutes = {'/sign-in', '/sign-up', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever auth state or the user's profile changes.
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (_, _) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/report/new', builder: (_, _) => const ReportFormScreen()),
      GoRoute(
        path: '/incident/:id',
        builder: (_, state) =>
            IncidentDetailScreen(incidentId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                ReportFormScreen(incidentId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Signed out → sign-in; unverified → verify email; waiting for the profile
/// → splash; admin pages → admins only.
String? _redirect(Ref ref, String location) {
  final auth = ref.read(authStateProvider);
  if (!auth.hasValue) return location == '/splash' ? null : '/splash';

  final user = auth.value;
  if (user == null) {
    return _publicRoutes.contains(location) ? null : '/sign-in';
  }
  if (!user.emailVerified) {
    return location == '/verify-email' ? null : '/verify-email';
  }

  final profile = ref.read(currentUserProvider).value;
  if (profile == null) return location == '/splash' ? null : '/splash';
  if (location.startsWith('/admin') && !profile.isAdmin) return '/home';

  final onEntryRoute =
      _publicRoutes.contains(location) ||
      location == '/verify-email' ||
      location == '/splash';
  return onEntryRoute ? '/home' : null;
}
