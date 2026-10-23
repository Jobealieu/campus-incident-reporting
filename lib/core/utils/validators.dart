/// Form field validators. Each returns an error message, or null when valid.
abstract final class Validators {
  static String? Function(String?) requiredText(
    String fieldName, {
    int min = 1,
    int max = 1000,
  }) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return '$fieldName is required';
      if (text.length < min) {
        return '$fieldName must be at least $min characters';
      }
      if (text.length > max) {
        return '$fieldName must be at most $max characters';
      }
      return null;
    };
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Use at least 8 characters';
    if (!text.contains(RegExp('[A-Za-z]')) || !text.contains(RegExp('[0-9]'))) {
      return 'Use a mix of letters and numbers';
    }
    return null;
  }
}
