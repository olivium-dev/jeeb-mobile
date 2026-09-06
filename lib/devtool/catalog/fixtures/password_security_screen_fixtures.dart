// Shared dev-only fixtures for `PasswordSecurityScreen` (JM-061).

import 'package:jeeb_mobile/features/password_security/application/password_security_cubit.dart';
import 'package:jeeb_mobile/features/password_security/domain/change_password_policy.dart';

/// The account's existing password, as typed into `password_current_field`.
/// Eight characters with a letter and a digit, so it clears
const String passwordSecurityScreenCurrentPassword = 'OldPass1';

/// A replacement that clears the strength floor and differs from the current
/// one — the only input that reaches `valid`.
const String passwordSecurityScreenNewPassword = 'NewPass123';

/// A confirmation that does not match [passwordSecurityScreenNewPassword].
const String passwordSecurityScreenConfirmMismatch = 'Mismatch123';

/// Below the floor: four characters, no digit.
const String passwordSecurityScreenWeakPassword = 'weak';

/// The state every user lands in: three blank masked fields, no error, a live
/// "Save password". Catalog: `Change Form — Idle`.
PasswordSecurityCubit passwordSecurityScreenIdleCubit() =>
    PasswordSecurityCubit();

/// `ChangePasswordValidation.weak` — the new password is below the floor
/// ([ChangePasswordPolicy]: 8 characters, a letter and a digit) while the two
PasswordSecurityCubit passwordSecurityScreenWeakCubit() =>
    PasswordSecurityCubit()..submit(
      current: passwordSecurityScreenCurrentPassword,
      newPassword: passwordSecurityScreenWeakPassword,
      confirm: passwordSecurityScreenWeakPassword,
    );

/// `ChangePasswordValidation.mismatch` — new and confirm differ, and the new
/// password is otherwise fine. Catalog: `Mismatch Error`.
PasswordSecurityCubit passwordSecurityScreenMismatchCubit() =>
    PasswordSecurityCubit()..submit(
      current: passwordSecurityScreenCurrentPassword,
      newPassword: passwordSecurityScreenNewPassword,
      confirm: passwordSecurityScreenConfirmMismatch,
    );

/// `ChangePasswordValidation.empty` — the CTA was tapped on an untouched form.
/// [ChangePasswordPolicy.validate] tests emptiness FIRST, and the CTA's only
PasswordSecurityCubit passwordSecurityScreenEmptyFieldsCubit() =>
    PasswordSecurityCubit()..submit(current: '', newPassword: '', confirm: '');

/// `ChangePasswordValidation.sameAsCurrent` — the "new" password is the one the
/// account already has, typed identically into all three boxes.
PasswordSecurityCubit passwordSecurityScreenSameAsCurrentCubit() =>
    PasswordSecurityCubit()..submit(
      current: passwordSecurityScreenCurrentPassword,
      newPassword: passwordSecurityScreenCurrentPassword,
      confirm: passwordSecurityScreenCurrentPassword,
    );

/// `PasswordSecurityStatus.unavailable` — a perfectly valid change, submitted.
/// B-33: there is no `POST` behind this form, so `submit` records `unavailable`
PasswordSecurityCubit passwordSecurityScreenUnavailableCubit() =>
    PasswordSecurityCubit()..submit(
      current: passwordSecurityScreenCurrentPassword,
      newPassword: passwordSecurityScreenNewPassword,
      confirm: passwordSecurityScreenNewPassword,
    );

/// All three obscure flags flipped to "shown", through the cubit's own public
/// toggles.
PasswordSecurityCubit passwordSecurityScreenRevealedCubit() =>
    PasswordSecurityCubit()
      ..toggleCurrentObscured()
      ..toggleNewObscured()
      ..toggleConfirmObscured();
