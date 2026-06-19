// Unit tests for ChangePasswordPolicy (JM-061 domain). Pure Dart — no Flutter
// binding. Locks the validation order (empty → weak → same-as-current →
// mismatch) and the strength floor (shared with the JM-022 SetPasswordPolicy).

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/password_security/domain/change_password_policy.dart';

void main() {
  const policy = ChangePasswordPolicy();

  group('isStrong', () {
    test('requires >= 8 chars with a letter and a digit', () {
      expect(policy.isStrong('NewPassword123'), isTrue);
      expect(policy.isStrong('short1'), isFalse); // too short
      expect(policy.isStrong('alllettersonly'), isFalse); // no digit
      expect(policy.isStrong('12345678'), isFalse); // no letter
    });
  });

  group('validate', () {
    test('valid when all present, new strong, new != current, new == confirm',
        () {
      expect(
        policy.validate(
          current: 'OldPassword1',
          newPassword: 'NewPassword2',
          confirm: 'NewPassword2',
        ),
        ChangePasswordValidation.valid,
      );
    });

    test('empty wins first (any field blank)', () {
      expect(
        policy.validate(current: '', newPassword: 'NewPassword2', confirm: 'NewPassword2'),
        ChangePasswordValidation.empty,
      );
      expect(
        policy.validate(current: 'OldPassword1', newPassword: '', confirm: 'x'),
        ChangePasswordValidation.empty,
      );
      expect(
        policy.validate(current: 'OldPassword1', newPassword: 'NewPassword2', confirm: ''),
        ChangePasswordValidation.empty,
      );
    });

    test('weak new password → weak (before mismatch)', () {
      expect(
        policy.validate(
          current: 'OldPassword1',
          newPassword: 'weak',
          confirm: 'different',
        ),
        ChangePasswordValidation.weak,
      );
    });

    test('new equals current → sameAsCurrent (before mismatch)', () {
      expect(
        policy.validate(
          current: 'SamePass123',
          newPassword: 'SamePass123',
          confirm: 'SamePass123',
        ),
        ChangePasswordValidation.sameAsCurrent,
      );
    });

    test('new != confirm → mismatch', () {
      expect(
        policy.validate(
          current: 'OldPassword1',
          newPassword: 'NewPassword2',
          confirm: 'NewPassword3',
        ),
        ChangePasswordValidation.mismatch,
      );
    });
  });
}
