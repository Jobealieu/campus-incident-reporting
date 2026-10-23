/// Every route path in one place, so links can't drift from the router.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const reports = '/reports';
  static const profile = '/profile';
  static const newReport = '/report/new';
  static const manageUsers = '/admin/users';

  static String incident(String id) => '/incident/$id';
  static String editIncident(String id) => '/incident/$id/edit';
}
