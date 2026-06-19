import 'package:equatable/equatable.dart';

import '../domain/auth_repository.dart';

/// Lifecycle of the recover-password request (JM-020). This is a single-action
/// screen (no cold load), so the machine is: `idle` → `submitting` →
/// `succeeded` | `failed`. On `succeeded` the screen navigates to
/// `/recover/verify` carrying the entered email (40_GUARDRAILS_ARCH §5.3).
enum RecoverPasswordStatus { idle, submitting, succeeded, failed }

/// Immutable state for [RecoverPasswordCubit].
///
/// Holds the live email text (so the cubit, not the widget, owns the submitted
/// value handed to the verify screen) plus the typed failure. Per the W-1 FLOOR
/// contract the recovery request is **non-enumerating** (always 200 for any
/// email), so the only reachable failure is a transport/`unknown` error — the
/// UX must never reveal whether the email exists.
class RecoverPasswordState extends Equatable {
  const RecoverPasswordState({
    this.status = RecoverPasswordStatus.idle,
    this.email = '',
    this.error,
  });

  final RecoverPasswordStatus status;

  /// The email currently typed into `recover_email_field`. Carried to
  /// `/recover/verify` on success so JM-021 can call `verifyRecovery`.
  final String email;

  /// Typed failure (mapped to localized copy by the screen). Never a raw
  /// exception/string (40_GUARDRAILS_ARCH §4).
  final AuthFailure? error;

  /// Submit is enabled only for a syntactically plausible email and when no
  /// request is already in flight. Validation is intentionally light — the
  /// backend is the authority and the flow is non-enumerating.
  bool get canSubmit =>
      status != RecoverPasswordStatus.submitting && _looksLikeEmail(email);

  bool get isSubmitting => status == RecoverPasswordStatus.submitting;

  static bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final at = trimmed.indexOf('@');
    if (at <= 0) return false;
    final dot = trimmed.indexOf('.', at);
    return dot > at + 1 && dot < trimmed.length - 1;
  }

  RecoverPasswordState copyWith({
    RecoverPasswordStatus? status,
    String? email,
    AuthFailure? error,
    bool clearError = false,
  }) =>
      RecoverPasswordState(
        status: status ?? this.status,
        email: email ?? this.email,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, email, error];
}
