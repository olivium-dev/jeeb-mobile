import 'package:equatable/equatable.dart';

import '../domain/auth_repository.dart';
import '../domain/set_password_policy.dart';

/// Submission lifecycle for the set-password screen (JM-022).
///   * [idle]       — editing; no submit in flight.
///   * [submitting] — POST `/v1/auth/set-password` in flight.
///   * [succeeded]  — 200; tokens persisted. The screen's `listener` navigates
///                    on this edge (recovery → `/login`; in-app-social →
///                    customer-profile, D90).
///   * [failed]     — client-side validation failed OR the server rejected the
///                    request. Both surface through the single
///                    `setpw_validation_error` node (60_W0_TEST_PLAN §2.11).
enum SetPasswordStatus { idle, submitting, succeeded, failed }

/// Immutable state for [SetPasswordCubit]. Equatable + `copyWith` with explicit
/// `clear<X>` flags for the nullable fields (40_GUARDRAILS_ARCH §2.1).
class SetPasswordState extends Equatable {
  const SetPasswordState({
    this.status = SetPasswordStatus.idle,
    this.newObscured = true,
    this.confirmObscured = true,
    this.validation,
    this.failure,
    this.session,
  });

  final SetPasswordStatus status;

  /// Whether the new-password field masks its text (default obscured).
  final bool newObscured;

  /// Whether the confirm-password field masks its text (default obscured).
  final bool confirmObscured;

  /// The last client-side validation result. Non-null + non-[valid] when the
  /// `setpw_validation_error` node should render for a mismatch/weak password.
  final SetPasswordValidation? validation;

  /// A server-side failure (network / invalid reset token), surfaced through
  /// the same error node. Null when the failure was purely client-side.
  final AuthFailure? failure;

  /// The minted session, present only after [SetPasswordStatus.succeeded].
  final AuthSession? session;

  /// True when the screen should show the `setpw_validation_error` node — for a
  /// failed client validation OR a server failure.
  bool get hasError =>
      status == SetPasswordStatus.failed &&
      ((validation != null && validation != SetPasswordValidation.valid) ||
          failure != null);

  SetPasswordState copyWith({
    SetPasswordStatus? status,
    bool? newObscured,
    bool? confirmObscured,
    SetPasswordValidation? validation,
    AuthFailure? failure,
    AuthSession? session,
    bool clearValidation = false,
    bool clearFailure = false,
    bool clearSession = false,
  }) {
    return SetPasswordState(
      status: status ?? this.status,
      newObscured: newObscured ?? this.newObscured,
      confirmObscured: confirmObscured ?? this.confirmObscured,
      validation: clearValidation ? null : (validation ?? this.validation),
      failure: clearFailure ? null : (failure ?? this.failure),
      session: clearSession ? null : (session ?? this.session),
    );
  }

  @override
  List<Object?> get props => [
        status,
        newObscured,
        confirmObscured,
        validation,
        failure,
        session,
      ];
}
