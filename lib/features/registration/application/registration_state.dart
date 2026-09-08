import 'package:equatable/equatable.dart';

import '../domain/international_phone.dart';
import '../domain/registration_country_metadata.dart';

enum RegistrationStep { phone, otp, lockedOut, verified }

enum RegistrationPhoneError { invalid, networkError, rateLimited, serverError }

enum RegistrationOtpError {
  invalid,
  expired,
  accountSuspended,

  /// The gateway refused a resend with 429; [RegistrationState.otpRetryAfterSeconds]
  /// carries its window.
  rateLimited,

  /// A 5xx on send/verify — never the user's connection.
  serverError,

  /// 502/503/504: sign-in is temporarily down.
  serviceUnavailable,

  networkError,
}

class RegistrationState extends Equatable {
  const RegistrationState({
    this.step = RegistrationStep.phone,
    this.phoneInput = '',
    this.selectedCountryCode = RegistrationCountryCatalog.defaultCountryCode,
    this.phoneError,
    this.isSendingCode = false,
    this.isVerifying = false,
    this.otpError,
    this.failedAttempts = 0,
    this.resendSecondsRemaining = 0,
    this.lockoutSecondsRemaining = 0,
    this.otpRetryAfterSeconds,
    this.lockoutFromRateLimit = false,
  });

  final RegistrationStep step;

  final String phoneInput;

  final String selectedCountryCode;

  final RegistrationPhoneError? phoneError;

  final bool isSendingCode;

  final bool isVerifying;

  final RegistrationOtpError? otpError;

  final int failedAttempts;

  final int resendSecondsRemaining;

  final int lockoutSecondsRemaining;

  /// The server's `Retry-After` window for a rate-limited resend, in seconds.
  final int? otpRetryAfterSeconds;

  /// True when the lockout came from a gateway 429 rather than spent attempts.
  final bool lockoutFromRateLimit;

  InternationalPhone? get parsedPhone => InternationalPhone.tryParse(
    countryCode: selectedCountryCode,
    raw: phoneInput,
  );

  bool get isPhoneReady => parsedPhone != null;

  /// True while the phone step is inside a server-declared 429 window, so the
  /// Send CTA is disabled for it instead of only claiming to be.
  bool get isRateLimitedNow =>
      phoneError == RegistrationPhoneError.rateLimited &&
      resendSecondsRemaining > 0;

  String get displayPhone => parsedPhone?.displayWithPrefix ?? phoneInput;

  RegistrationState copyWith({
    RegistrationStep? step,
    String? phoneInput,
    String? selectedCountryCode,
    Object? phoneError = _sentinel,
    bool? isSendingCode,
    bool? isVerifying,
    Object? otpError = _sentinel,
    int? failedAttempts,
    int? resendSecondsRemaining,
    int? lockoutSecondsRemaining,
    Object? otpRetryAfterSeconds = _sentinel,
    bool? lockoutFromRateLimit,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      phoneInput: phoneInput ?? this.phoneInput,
      selectedCountryCode: selectedCountryCode ?? this.selectedCountryCode,
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
      otpRetryAfterSeconds: identical(otpRetryAfterSeconds, _sentinel)
          ? this.otpRetryAfterSeconds
          : otpRetryAfterSeconds as int?,
      lockoutFromRateLimit: lockoutFromRateLimit ?? this.lockoutFromRateLimit,
    );
  }

  @override
  List<Object?> get props => [
    step,
    phoneInput,
    selectedCountryCode,
    phoneError,
    isSendingCode,
    isVerifying,
    otpError,
    failedAttempts,
    resendSecondsRemaining,
    lockoutSecondsRemaining,
    otpRetryAfterSeconds,
    lockoutFromRateLimit,
  ];
}

const Object _sentinel = Object();
