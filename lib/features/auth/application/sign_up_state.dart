import 'package:equatable/equatable.dart';

import '../domain/auth_repository.dart';

/// Lifecycle of the sign-up submission (JM-008).
enum SignUpStatus {
  /// Editing the form; not yet submitted.
  idle,

  /// `POST /v1/auth/signup` in flight.
  submitting,

  /// 201 — account created (phone NOT yet verified, D21). The screen routes to
  /// phone-OTP verification (G8).
  succeeded,

  /// 409 `email_collision` (D22) — the screen routes to the social-collision
  /// prompt (JM-019), then returns to [idle] once acknowledged.
  collision,

  /// Non-collision failure (network / bad request / unknown) — surfaced inline.
  failed,
}

/// Coarse password-strength bucket reflected by `signup_password_strength_hint`.
/// Not a security control — a hint only (the server is authoritative on policy).
enum PasswordStrength { empty, weak, medium, strong }

/// State for the email-first sign-up screen (JM-008, CTO-D1). Immutable +
/// [Equatable]; `copyWith` carries a `clear<X>` flag for every nullable field
/// (40_GUARDRAILS_ARCH §2.1).
class SignUpState extends Equatable {
  const SignUpState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.passwordVisible = false,
    this.status = SignUpStatus.idle,
    this.error,
  });

  final String name;
  final String email;
  final String password;

  /// Whether `signup_password_field` shows plaintext (toggled by
  /// `signup_password_visibility_toggle`).
  final bool passwordVisible;

  final SignUpStatus status;

  /// Non-collision failure cause; null otherwise. The cubit maps it to copy.
  final AuthFailure? error;

  /// Derived strength bucket for `signup_password_strength_hint`. Heuristic:
  /// length + character-class variety (least-surprising, R-F). Server policy
  /// remains authoritative; this is presentational only.
  PasswordStrength get passwordStrength {
    final value = password;
    if (value.isEmpty) return PasswordStrength.empty;
    var classes = 0;
    if (value.contains(RegExp(r'[a-z]'))) classes++;
    if (value.contains(RegExp(r'[A-Z]'))) classes++;
    if (value.contains(RegExp(r'\d'))) classes++;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) classes++;
    if (value.length >= 10 && classes >= 3) return PasswordStrength.strong;
    if (value.length >= 8 && classes >= 2) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  /// All three fields populated with a plausibly-valid email — gates
  /// `signup_submit_cta`. Email validity is intentionally lenient (server is
  /// authoritative); a bare `a@b` shape is enough to enable submit.
  bool get isSubmittable =>
      name.trim().isNotEmpty &&
      _looksLikeEmail(email) &&
      password.isNotEmpty &&
      status != SignUpStatus.submitting;

  bool get isSubmitting => status == SignUpStatus.submitting;

  static bool _looksLikeEmail(String value) {
    final v = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  SignUpState copyWith({
    String? name,
    String? email,
    String? password,
    bool? passwordVisible,
    SignUpStatus? status,
    AuthFailure? error,
    bool clearError = false,
  }) {
    return SignUpState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      passwordVisible: passwordVisible ?? this.passwordVisible,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        name,
        email,
        password,
        passwordVisible,
        status,
        error,
      ];
}
