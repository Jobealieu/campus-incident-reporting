/// Only ALU community members may use the app. The same domains are enforced
/// server-side in `firestore.rules` and `storage.rules`.
abstract final class EmailPolicy {
  static const allowedDomains = ['alustudent.com', 'alueducation.com'];

  static final _localPart = RegExp(r'^[a-z0-9._%+-]+$');

  static String normalize(String email) => email.trim().toLowerCase();

  static bool isAluEmail(String email) {
    final normalized = normalize(email);
    final at = normalized.lastIndexOf('@');
    if (at <= 0) return false;
    return _localPart.hasMatch(normalized.substring(0, at)) &&
        allowedDomains.contains(normalized.substring(at + 1));
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!isAluEmail(value)) {
      return 'Use your ALU email (@alustudent.com or @alueducation.com)';
    }
    return null;
  }
}
