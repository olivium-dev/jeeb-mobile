// B-33 — the change-password submit must NEVER fake success.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_cubit.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_state.dart';
import 'package:jeeb_mobile/features/password_security/domain/change_password_policy.dart';

void main() {
  group('B-33 PasswordSecurityCubit.submit — no false success', () {
    test('a valid form reaches `unavailable`, never a fake success', () {
      final cubit = PasswordSecurityCubit();

      cubit.submit(
        current: 'OldPassword1',
        newPassword: 'NewPassword2',
        confirm: 'NewPassword2',
      );

      expect(cubit.state.status, PasswordSecurityStatus.unavailable);
      expect(cubit.state.validation, isNull);
      addTearDown(cubit.close);
    });

    test('a client-side validation miss still fails on-screen (unchanged)', () {
      final cubit = PasswordSecurityCubit();

      cubit.submit(
        current: 'OldPassword1',
        newPassword: 'NewPassword2',
        confirm: 'Mismatch3',
      );

      expect(cubit.state.status, PasswordSecurityStatus.failed);
      expect(cubit.state.validation, ChangePasswordValidation.mismatch);
      addTearDown(cubit.close);
    });
  });
}
