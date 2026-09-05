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
    this.unavailableNonce = 0,
  });

  final PasswordSecurityStatus status;

  final bool currentObscured;

  final bool newObscured;

  final bool confirmObscured;

  final ChangePasswordValidation? validation;

  /// PS-01: two identical `unavailable` emits are one state under Equatable, so
  /// `listenWhen` never fired again and the CTA read as inert. This bumps.
  final int unavailableNonce;

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
    int? unavailableNonce,
    bool clearValidation = false,
  }) {
    return PasswordSecurityState(
      status: status ?? this.status,
      currentObscured: currentObscured ?? this.currentObscured,
      newObscured: newObscured ?? this.newObscured,
      confirmObscured: confirmObscured ?? this.confirmObscured,
      validation: clearValidation ? null : (validation ?? this.validation),
      unavailableNonce: unavailableNonce ?? this.unavailableNonce,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentObscured,
        newObscured,
        confirmObscured,
        validation,
        unavailableNonce,
      ];
}
