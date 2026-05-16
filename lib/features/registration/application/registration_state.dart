import 'package:equatable/equatable.dart';

import '../domain/lebanon_phone.dart';

/// High-level UI step. The screen layer picks which view to render off this
/// (phone entry vs OTP entry vs lockout vs verified).
enum RegistrationStep {
  phone,
  otp,
  lockedOut,
  verified,
}

/// Inline error surfaced under the phone field.
enum RegistrationPhoneError { invalid, networkError, rateLimited }

/// Inline error surfaced under the OTP boxes.
enum RegistrationOtpError { invalid, expired, networkError }

class RegistrationState extends Equatable {
  const RegistrationState({
    this.step = RegistrationStep.phone,
    this.phoneInput = '',
    this.phoneError,
    this.isSendingCode = false,
    this.isVerifying = false,
    this.otpError,
    this.failedAttempts = 0,
    this.resendSecondsRemaining = 0,
    this.lockoutSecondsRemaining = 0,
  });

  /// Active step the screen layer should render.
  final RegistrationStep step;

  /// Raw user-typed input from the phone field. Always already normalised
  /// (8 national digits, no prefix, no separators) by the cubit before it
  /// lands here.
  final String phoneInput;

  /// Error to surface inline under the phone field.
  final RegistrationPhoneError? phoneError;

  /// Pending state for the "Send code" CTA.
  final bool isSendingCode;

  /// Pending state for the "Verify" CTA.
  final bool isVerifying;

  /// Error to surface under the OTP input.
  final RegistrationOtpError? otpError;

  /// Count of consecutive wrong-code attempts. On reaching
  /// [RegistrationAttemptPolicy.maxAttempts] the cubit transitions to
  /// [RegistrationStep.lockedOut] and resets this on lockout expiry.
  final int failedAttempts;

  /// Seconds left on the resend cooldown. `0` means the resend button is
  /// tappable.
  final int resendSecondsRemaining;

  /// Seconds left on the lockout banner.
  final int lockoutSecondsRemaining;

  /// Convenience: is the phone input long enough to be a valid Lebanese
  /// national number? Used to enable/disable the send-code CTA.
  bool get isPhoneReady => LebanonPhone.tryParse(phoneInput) != null;

  /// Convenience: full E.164 number to display on the OTP step's subtitle.
  String get displayPhone =>
      LebanonPhone.tryParse(phoneInput)?.displayWithPrefix ?? phoneInput;

  RegistrationState copyWith({
    RegistrationStep? step,
    String? phoneInput,
    Object? phoneError = _sentinel,
    bool? isSendingCode,
    bool? isVerifying,
    Object? otpError = _sentinel,
    int? failedAttempts,
    int? resendSecondsRemaining,
    int? lockoutSecondsRemaining,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      phoneInput: phoneInput ?? this.phoneInput,
      phoneError: identical(phoneError, _sentinel)
          ? this.phoneError
          : phoneError as RegistrationPhoneError?,
      isSendingCode: isSendingCode ?? this.isSendingCode,
      isVerifying: isVerifying ?? this.isVerifying,
      otpError: identical(otpError, _sentinel)
          ? this.otpError
          : otpError as RegistrationOtpError?,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      resendSecondsRemaining:
          resendSecondsRemaining ?? this.resendSecondsRemaining,
      lockoutSecondsRemaining:
          lockoutSecondsRemaining ?? this.lockoutSecondsRemaining,
    );
  }

  @override
  List<Object?> get props => [
        step,
        phoneInput,
        phoneError,
        isSendingCode,
        isVerifying,
        otpError,
        failedAttempts,
        resendSecondsRemaining,
        lockoutSecondsRemaining,
      ];
}

const Object _sentinel = Object();
