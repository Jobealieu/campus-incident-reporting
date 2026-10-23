import 'package:campus_fix/features/auth/domain/app_user.dart';
import 'package:campus_fix/features/auth/domain/email_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailPolicy.isAluEmail', () {
    test('accepts student and staff domains, case-insensitively', () {
      expect(EmailPolicy.isAluEmail('a.jobe@alustudent.com'), isTrue);
      expect(EmailPolicy.isAluEmail('  Dean@ALUEducation.com '), isTrue);
    });

    test('rejects other domains and look-alikes', () {
      expect(EmailPolicy.isAluEmail('someone@gmail.com'), isFalse);
      expect(EmailPolicy.isAluEmail('x@alustudent.com.evil.io'), isFalse);
      expect(EmailPolicy.isAluEmail('x@fake-alustudent.com'), isFalse);
      expect(EmailPolicy.isAluEmail('@alustudent.com'), isFalse);
      expect(EmailPolicy.isAluEmail('a b@alustudent.com'), isFalse);
    });

    test('validate returns a helpful message', () {
      expect(EmailPolicy.validate(''), 'Email is required');
      expect(EmailPolicy.validate('me@gmail.com'), contains('ALU email'));
      expect(EmailPolicy.validate('me@alustudent.com'), isNull);
    });
  });

  group('AppUser', () {
    test('maps roles and defaults unknown roles to student', () {
      final staff = AppUser.fromMap('u1', {
        'email': 'x@alueducation.com',
        'displayName': 'Grace Uwase',
        'role': 'staff',
      });
      expect(staff.isStaff, isTrue);
      expect(staff.isAdmin, isFalse);
      expect(staff.firstName, 'Grace');

      final tampered = AppUser.fromMap('u2', {'role': 'superuser'});
      expect(tampered.role, UserRole.student);
      expect(tampered.isStaff, isFalse);
    });
  });
}
