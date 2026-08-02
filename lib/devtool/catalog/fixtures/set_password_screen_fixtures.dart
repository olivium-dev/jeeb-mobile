// Shared dev-only fixtures for `SetPasswordScreen`.

import 'package:jeeb_mobile/features/auth/application/set_password_cubit.dart';
import 'package:jeeb_mobile/features/auth/application/set_password_state.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';
import 'package:jeeb_mobile/features/auth/domain/set_password_policy.dart';

/// The account every seeded state is setting a password for.
/// Never rendered — the screen shows neither the email nor the mode — but the
const String setPasswordScreenEmail = 'jeeber@example.com';

/// The optional reset token. In-app-social does not require one (the user is
/// already authenticated, D90); it is carried so the fixture matches the
const String setPasswordScreenResetToken = 'demo-reset-token';

/// An [AuthRepository] that cannot reach anything.
/// Every method throws, and none is ever called: the seeded states are already
/// terminal. It exists so the cubit can be constructed without DI.
class SetPasswordScreenInertAuthRepository implements AuthRepository {
  /// Const so the fixtures can share one instance.
  const SetPasswordScreenInertAuthRepository();

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<RecoveryRequestResult> requestRecovery({required String email}) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);
}

/// A [SetPasswordCubit] that starts in [seed] instead of the default idle
/// state. DEV-ONLY — see the note at the top of this file.
class SetPasswordScreenSeededCubit extends SetPasswordCubit {
  /// Emits [seed] immediately, before any surface has subscribed.
  SetPasswordScreenSeededCubit(SetPasswordState seed)
      : super(
          repository: const SetPasswordScreenInertAuthRepository(),
          email: setPasswordScreenEmail,
          resetToken: setPasswordScreenResetToken,
        ) {
    emit(seed);
  }
}

/// The state every user lands in: both fields empty and masked, no error, the
/// CTA live. Also the catalog's `Idle`.
const SetPasswordState setPasswordScreenIdleState = SetPasswordState();

/// `POST /v1/auth/set-password` in flight. Also the catalog's `Submitting`.
const SetPasswordState setPasswordScreenSubmittingState = SetPasswordState(
  status: SetPasswordStatus.submitting,
);

/// New and confirm differ. Also the catalog's `Validation error — mismatch`.
const SetPasswordState setPasswordScreenMismatchState = SetPasswordState(
  status: SetPasswordStatus.failed,
  validation: SetPasswordValidation.mismatch,
);

/// The password is below the strength floor ([SetPasswordPolicy]: 8 chars, a
/// letter and a digit). A different cause from the mismatch above, and — see
const SetPasswordState setPasswordScreenWeakState = SetPasswordState(
  status: SetPasswordStatus.failed,
  validation: SetPasswordValidation.weak,
);

/// One or both fields are blank — what the idle screen emits when the CTA is
/// tapped before anything is typed. `SetPasswordPolicy.validate` checks
const SetPasswordState setPasswordScreenEmptyFieldsState = SetPasswordState(
  status: SetPasswordStatus.failed,
  validation: SetPasswordValidation.empty,
);

/// The request never reached the gateway (`AuthFailure.network`).
/// `validation` is null here — `SetPasswordCubit.submit` clears it on the
const SetPasswordState setPasswordScreenNetworkFailureState = SetPasswordState(
  status: SetPasswordStatus.failed,
  failure: AuthFailure.network,
);

/// 401 `invalid_token` — the reset token was rejected. Retrying cannot fix it;
/// only leaving the screen can.
const SetPasswordState setPasswordScreenInvalidTokenState = SetPasswordState(
  status: SetPasswordStatus.failed,
  failure: AuthFailure.invalidToken,
);

/// Both eye toggles flipped: the only cubit-driven visual on this screen other
/// than the error node.
const SetPasswordState setPasswordScreenRevealedState = SetPasswordState(
  newObscured: false,
  confirmObscured: false,
);

/// Both fields empty and masked, nothing submitted. Catalog: `Idle`.
SetPasswordCubit setPasswordScreenIdleCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenIdleState);

/// The submit is in flight. Catalog: `Submitting`.
SetPasswordCubit setPasswordScreenSubmittingCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenSubmittingState);

/// New != confirm. Catalog: `Validation error — mismatch`.
SetPasswordCubit setPasswordScreenMismatchCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenMismatchState);

/// Below the strength floor.
SetPasswordCubit setPasswordScreenWeakCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenWeakState);

/// Submitted with a blank field.
SetPasswordCubit setPasswordScreenEmptyFieldsCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenEmptyFieldsState);

/// The gateway was never reached.
SetPasswordCubit setPasswordScreenNetworkFailureCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenNetworkFailureState);

/// The reset token was rejected (401).
SetPasswordCubit setPasswordScreenInvalidTokenCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenInvalidTokenState);

/// Both visibility toggles flipped to "shown".
SetPasswordCubit setPasswordScreenRevealedCubit() =>
    SetPasswordScreenSeededCubit(setPasswordScreenRevealedState);
