import 'package:equatable/equatable.dart';

import '../domain/auth_repository.dart';

/// Lifecycle of the email/password login submit (JM-007). [initial] is the
/// editable form; [submitting] disables the CTA + shows the inline spinner;
/// [succeeded] is the one-shot the screen listens for to refresh the session
/// and route to the Requests tab; [failed] surfaces a typed [AuthFailure] as
/// localized copy (40_GUARDRAILS_ARCH §3 — the UI never sees a DioException).
enum LoginStatus { initial, submitting, succeeded, failed }

/// Immutable login form state (40_GUARDRAILS_ARCH §2.1). `email`/`password` are
/// the live field values; `error` is the typed failure on [LoginStatus.failed];
/// `session` carries the minted session on [LoginStatus.succeeded].
class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.email = '',
    this.password = '',
    this.error,
    this.session,
  });

  final LoginStatus status;
  final String email;
  final String password;
  final AuthFailure? error;
  final AuthSession? session;

  /// The CTA is enabled only with non-empty credentials and no in-flight
  /// submit. (Server-side `invalid_credentials` is the real authority, D22; the
  /// client gate is just a non-empty guard, never a credential validator.)
  bool get canSubmit =>
      status != LoginStatus.submitting &&
      email.trim().isNotEmpty &&
      password.isNotEmpty;

  bool get isSubmitting => status == LoginStatus.submitting;

  LoginState copyWith({
    LoginStatus? status,
    String? email,
    String? password,
    AuthFailure? error,
    bool clearError = false,
    AuthSession? session,
    bool clearSession = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      email: email ?? this.email,
      password: password ?? this.password,
      error: clearError ? null : (error ?? this.error),
      session: clearSession ? null : (session ?? this.session),
    );
  }

  @override
  List<Object?> get props => [status, email, password, error, session?.userId];
}
