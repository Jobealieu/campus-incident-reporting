import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/manage_users_screen.dart';
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
import 'routes.dart';
import 'splash_screen.dart';

const _publicRoutes = {
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.forgotPassword,
};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever auth state or the user's profile changes.
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, _) => const VerifyEmailScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (_, _) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.newReport,
        builder: (_, _) => const ReportFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.manageUsers,
        builder: (_, _) => const ManageUsersScreen(),
      ),
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
  if (!auth.hasValue) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final user = auth.value;
  if (user == null) {
    return _publicRoutes.contains(location) ? null : AppRoutes.signIn;
  }
  if (!user.emailVerified) {
    return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
  }

  final profile = ref.read(currentUserProvider).value;
  if (profile == null) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (location.startsWith('/admin') && !profile.isAdmin) return AppRoutes.home;

  final onEntryRoute =
      _publicRoutes.contains(location) ||
      location == AppRoutes.verifyEmail ||
      location == AppRoutes.splash;
  return onEntryRoute ? AppRoutes.home : null;
}
