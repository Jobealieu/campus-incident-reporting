import 'package:campus_fix/core/utils/date_format.dart';
import 'package:campus_fix/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.requiredText', () {
    final validate = Validators.requiredText('Title', min: 5, max: 10);

    test('rejects empty and whitespace-only input', () {
      expect(validate(null), 'Title is required');
      expect(validate('   '), 'Title is required');
    });

    test('enforces length after trimming', () {
      expect(validate('  abc  '), 'Title must be at least 5 characters');
      expect(validate('a' * 11), 'Title must be at most 10 characters');
      expect(validate('  hello  '), isNull);
    });
  });

  group('Validators.password', () {
    test('requires 8+ characters with letters and numbers', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('campus2026'), isNull);
    });
  });

  group('formatRelative', () {
    final now = DateTime(2026, 10, 23, 12);

    test('describes recent times in words', () {
      expect(formatRelative(now, now: now), 'just now');
      expect(
        formatRelative(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        formatRelative(now.subtract(const Duration(hours: 1)), now: now),
        '1 hour ago',
      );
      expect(
        formatRelative(now.subtract(const Duration(days: 3)), now: now),
        '3 days ago',
      );
    });

    test('falls back to a date after a week', () {
      expect(formatRelative(DateTime(2026, 10, 1), now: now), 'Oct 1, 2026');
    });
  });
}
