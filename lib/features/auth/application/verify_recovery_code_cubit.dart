import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import 'verify_recovery_code_state.dart';

/// Owns the email-based recovery-code verification step (JM-021).
///
/// Collaborators:
///   - [AuthRepository] — `POST /v1/auth/recovery/verify` (submit) and
///     `POST /v1/auth/recovery/request` (resend). Both speak the VERIFIED W-1
///     FLOOR contract; the repo already maps `DioException` → [AuthFailure].
///
/// This screen is **email-anchored** (carries the recovery email, never a
/// phone number — JM-021 AC). A successful verify mints a `resetToken` that the
/// screen forwards to `/set-password?mode=recovery` (JM-022).
class VerifyRecoveryCodeCubit extends Cubit<VerifyRecoveryCodeState> {
  VerifyRecoveryCodeCubit({
    required AuthRepository authRepository,
    required String email,
  })  : _authRepository = authRepository,
        super(VerifyRecoveryCodeState(email: email));

  final AuthRepository _authRepository;

  /// Mirrors the digits in `verify_code_input`. Clears any stale error so the
  /// inline `verify_code_error` node disappears as the user re-types.
  void codeChanged(String code) {
    emit(state.copyWith(code: code, clearError: true));
  }

  /// Submits the entered code (`verify_code_submit_cta`). On 200 the minted
  /// `resetToken` lands in state and the screen navigates; on 401
  /// `invalid_recovery_code` (wrong/expired) or any other failure the inline
  /// `verify_code_error` shows and the screen STAYS.
  Future<void> submit() async {
    if (state.isSubmitting || !state.isComplete) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final result = await _authRepository.verifyRecovery(
        email: state.email,
        code: state.code,
      );
      emit(state.copyWith(
        isSubmitting: false,
        resetToken: result.resetToken,
      ));
    } on AuthRepositoryException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: _mapError(e.failure),
      ));
    }
  }

  /// Re-requests the recovery code (`verify_code_resend_cta`). The screen STAYS
  /// on verify (JM-021 AC3); the input is cleared so the user re-enters the
  /// freshly emailed code. Non-enumerating request → always succeeds for a
  /// well-formed email; a network failure surfaces the same inline error.
  Future<void> resend() async {
    if (state.isResending) return;
    emit(state.copyWith(isResending: true, clearError: true));
    try {
      await _authRepository.requestRecovery(email: state.email);
      // Clear the entered digits for the new code; stay on screen. Bump the
      // resend generation so the OTP widget re-keys (clears its cells) — keying
      // on this counter, not on `code.isEmpty`, avoids wiping the cells on the
      // first typed digit (RC-7).
      emit(state.copyWith(
        isResending: false,
        code: '',
        resendGeneration: state.resendGeneration + 1,
      ));
    } on AuthRepositoryException catch (e) {
      emit(state.copyWith(
        isResending: false,
        error: _mapError(e.failure),
      ));
    }
  }

  static VerifyRecoveryCodeError _mapError(AuthFailure failure) {
    switch (failure) {
      case AuthFailure.invalidRecoveryCode:
        return VerifyRecoveryCodeError.invalidOrExpired;
      case AuthFailure.network:
        return VerifyRecoveryCodeError.network;
      // 400/invalidToken/invalidCredentials/emailCollision/unknown all collapse
      // to the same inline node — the verify screen has a single error
      // affordance. (emailCollision is a signup-only failure that can never
      // reach this leg, but the switch must be exhaustive.)
      case AuthFailure.invalidToken:
      case AuthFailure.invalidCredentials:
      case AuthFailure.emailCollision:
      case AuthFailure.badRequest:
      case AuthFailure.unknown:
        return VerifyRecoveryCodeError.invalidOrExpired;
    }
  }
}
