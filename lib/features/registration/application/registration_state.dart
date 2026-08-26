import 'package:equatable/equatable.dart';

import '../domain/international_phone.dart';
import '../domain/registration_country_metadata.dart';

enum RegistrationStep { phone, otp, lockedOut, verified }

enum RegistrationPhoneError { invalid, networkError, rateLimited }

enum RegistrationOtpError { invalid, expired, accountSuspended, networkError }

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

  InternationalPhone? get parsedPhone => InternationalPhone.tryParse(
    countryCode: selectedCountryCode,
    raw: phoneInput,
  );

  bool get isPhoneReady => parsedPhone != null;

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
  ];
}

const Object _sentinel = Object();
