import 'package:equatable/equatable.dart';

import '../domain/change_password_policy.dart';

/// Submission lifecycle for the change-password form (JM-061).
///   * [idle]      — editing; nothing submitted.
///   * [submitting]— a change submit is in flight (transient; the JM-061 change
///                   path is local-validation only per the AC `Mock: —`, so this
///                   resolves immediately, but the state exists so the CTA can
///                   disable and a future server-backed change can slot in).
///   * [unavailable]— validation passed, but there is NO change-password
///                   endpoint in the client's data layer (the gateway exposes
///                   only `POST /v1/auth/set-password` for the social-only
///                   "set a password" leg — no current-password verify / change-
///                   by-bearer contract exists, 42_GUARDRAILS_MOCK). B-33: the
///                   form must NOT fake success; the screen surfaces an honest
///                   "not available yet" notice and stays put.
///   * [failed]    — client-side validation failed. Surfaces through the
///                   `password_strength_error` (weak / same-as-current) or
///                   `password_mismatch_error` (new≠confirm) node.
enum PasswordSecurityStatus { idle, submitting, unavailable, failed }

/// Immutable state for [PasswordSecurityCubit]. Equatable + `copyWith` with
/// explicit `clear<X>` flags for the nullable validation field
/// (40_GUARDRAILS_ARCH §2.1).
class PasswordSecurityState extends Equatable {
  const PasswordSecurityState({
    this.status = PasswordSecurityStatus.idle,
    this.currentObscured = true,
    this.newObscured = true,
    this.confirmObscured = true,
    this.validation,
  });

  final PasswordSecurityStatus status;

  /// Whether the current-password field masks its text (default obscured).
  final bool currentObscured;

  /// Whether the new-password field masks its text (default obscured).
  final bool newObscured;

  /// Whether the confirm-password field masks its text (default obscured).
  final bool confirmObscured;

  /// The last client-side validation result. Non-null + non-[valid] when an
  /// error node should render.
  final ChangePasswordValidation? validation;

  /// True when the mismatch node (`password_mismatch_error`) should render.
  bool get hasMismatchError =>
      status == PasswordSecurityStatus.failed &&
      validation == ChangePasswordValidation.mismatch;

  /// True when the strength node (`password_strength_error`) should render —
  /// covers the weak password, the empty case, and the same-as-current no-op
  /// (all "choose a stronger / different password" guidance).
  bool get hasStrengthError =>
      status == PasswordSecurityStatus.failed &&
      (validation == ChangePasswordValidation.weak ||
          validation == ChangePasswordValidation.empty ||
          validation == ChangePasswordValidation.sameAsCurrent);

  PasswordSecurityState copyWith({
    PasswordSecurityStatus? status,
    bool? currentObscured,
    bool? newObscured,
    bool? confirmObscured,
    ChangePasswordValidation? validation,
    bool clearValidation = false,
  }) {
    return PasswordSecurityState(
      status: status ?? this.status,
      currentObscured: currentObscured ?? this.currentObscured,
      newObscured: newObscured ?? this.newObscured,
      confirmObscured: confirmObscured ?? this.confirmObscured,
      validation: clearValidation ? null : (validation ?? this.validation),
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentObscured,
        newObscured,
        confirmObscured,
        validation,
      ];
}
