// PURE Dart state for the verify-recovery-code screen (JM-021). No Flutter / Dio
// imports (Clean Architecture, 40_GUARDRAILS_ARCH §1).

/// Why the verify step is in an error state. Mapped from [AuthFailure] by the
/// cubit; the screen renders localized copy under `verify_code_error`.
enum VerifyRecoveryCodeError {
  /// 401 `invalid_recovery_code` — the entered code is wrong or expired.
  /// (The W-1 FLOOR contract returns the same 401 for both; the copy is shared.)
  invalidOrExpired,

  /// Connection/timeout or any non-401 backend failure — surfaced as the same
  /// inline error node so QA can assert `verify_code_error` regardless of cause.
  network,
}

/// Immutable state machine for [VerifyRecoveryCodeCubit].
///
/// `verify-code` is **email-based** recovery — it carries [email], never a phone
/// number (JM-021 AC: must NOT anchor phone). The minted [resetToken] is handed
/// to `/set-password?mode=recovery` on success (JM-022 consumes it).
class VerifyRecoveryCodeState {
  const VerifyRecoveryCodeState({
    required this.email,
    this.code = '',
    this.isSubmitting = false,
    this.isResending = false,
    this.error,
    this.resetToken,
    this.codeLength = 6,
    this.resendGeneration = 0,
  });

  /// The recovery email the code was sent to (from the recover screen, via
  /// route `extra`). Empty when reached as a cold deep-link with no payload.
  final String email;

  /// The digits currently entered in `verify_code_input`.
  final String code;

  /// A verify request is in flight (disables the submit CTA, shows progress).
  final bool isSubmitting;

  /// A resend request is in flight (disables the resend CTA so it isn't double
  /// fired; the screen STAYS — JM-021 AC3).
  final bool isResending;

  /// Non-null when the last verify failed; drives `verify_code_error`.
  final VerifyRecoveryCodeError? error;

  /// The reset token minted on a successful verify. Non-null → the screen
  /// navigates to set-password (recovery mode).
  final String? resetToken;

  /// OTP length contract (6-digit per the W-1 FLOOR `RECOVERY=654321`).
  final int codeLength;

  /// Bumped each time the code is RESENT so the OTP widget can re-key (and thus
  /// clear its cells) on a fresh code WITHOUT re-keying on every typed digit.
  /// Keying on `code.isEmpty` instead would discard+rebuild the input the
  /// instant the first digit is entered, wiping the entry (RC-7 regression).
  final int resendGeneration;

  /// The code is fully entered and a submit is allowed.
  bool get isComplete => code.length == codeLength;

  /// A successful verify produced a reset token → time to navigate.
  bool get isVerified => resetToken != null && resetToken!.isNotEmpty;

  VerifyRecoveryCodeState copyWith({
    String? code,
    bool? isSubmitting,
    bool? isResending,
    VerifyRecoveryCodeError? error,
    bool clearError = false,
    String? resetToken,
    int? resendGeneration,
  }) {
    return VerifyRecoveryCodeState(
      email: email,
      code: code ?? this.code,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isResending: isResending ?? this.isResending,
      error: clearError ? null : (error ?? this.error),
      resetToken: resetToken ?? this.resetToken,
      codeLength: codeLength,
      resendGeneration: resendGeneration ?? this.resendGeneration,
    );
  }
}
