/// An error whose [message] is written for end users and safe to display.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
