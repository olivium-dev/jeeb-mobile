import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/set_password_policy.dart';

/// Status: idle (editing), submitting (POST /v1/auth/set-password in-flight), succeeded (200; tokens persisted), failed (validation or server).
enum SetPasswordStatus { idle, submitting, succeeded, failed }

class SetPasswordState extends Equatable {
  const SetPasswordState({
    this.status = SetPasswordStatus.idle,
    this.newObscured = true,
    this.confirmObscured = true,
    this.validation,
    this.failure,
    this.appFailure,
    this.session,
  });

  final SetPasswordStatus status;

  final bool newObscured;

  final bool confirmObscured;

  final SetPasswordValidation? validation;

  final AuthFailure? failure;

  /// The transport classification, for kinds [AuthFailure] cannot express.
  final AppFailure? appFailure;

  final AuthSession? session;

  /// Editing a password cannot repair a rejected authorization token.
  bool get requiresExit => switch (failure) {
    AuthFailure.invalidToken ||
    AuthFailure.invalidRecoveryCode ||
    AuthFailure.invalidCredentials => true,
    _ => false,
  };

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
    AppFailure? appFailure,
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
      appFailure: clearFailure ? null : (appFailure ?? this.appFailure),
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
    appFailure,
    session,
  ];
}
