import 'package:equatable/equatable.dart';

import '../domain/change_password_policy.dart';

/// Status: idle (editing), submitting (in-flight, transient), unavailable (no endpoint), failed (validation).
enum PasswordSecurityStatus { idle, submitting, unavailable, failed }

/// Immutable state for [PasswordSecurityCubit]. Equatable + `copyWith` with clearValidation flag.
class PasswordSecurityState extends Equatable {
  const PasswordSecurityState({
    this.status = PasswordSecurityStatus.idle,
    this.currentObscured = true,
    this.newObscured = true,
    this.confirmObscured = true,
    this.validation,
  });

  final PasswordSecurityStatus status;

  final bool currentObscured;

  final bool newObscured;

  final bool confirmObscured;

  final ChangePasswordValidation? validation;

  bool get hasMismatchError =>
      status == PasswordSecurityStatus.failed &&
      validation == ChangePasswordValidation.mismatch;

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
