import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/lebanon_phone.dart';
import '../domain/otp_service.dart';
import '../domain/registration_attempt_policy.dart';
import 'registration_state.dart';

/// Phone+OTP registration flow.
class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit({
    required OtpService otpService,
    RegistrationAttemptPolicy policy = const RegistrationAttemptPolicy(),
    Stream<DateTime> Function()? tickerFactory,
  })  : _otpService = otpService,
        _policy = policy,
        _tickerFactory = tickerFactory ?? _defaultTickerFactory,
        super(const RegistrationState());

  final OtpService _otpService;
  final RegistrationAttemptPolicy _policy;
  final Stream<DateTime> Function() _tickerFactory;

  StreamSubscription<DateTime>? _resendTicker;
  StreamSubscription<DateTime>? _lockoutTicker;

  static Stream<DateTime> _defaultTickerFactory() =>
      Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());

  RegistrationAttemptPolicy get policy => _policy;

  void phoneChanged(String raw) {
    final normalised = LebanonPhone.normalise(raw);
    emit(state.copyWith(phoneInput: normalised, phoneError: null));
  }

  /// TRAP: must re-sync rendered phone (field can lag via autofill/paste).
  Future<void> sendCode({String? renderedPhone}) async {
    final source = renderedPhone ?? state.phoneInput;
    final normalised = LebanonPhone.normalise(source);
    if (normalised != state.phoneInput) {
      emit(state.copyWith(phoneInput: normalised));
    }
    final phone = LebanonPhone.tryParse(normalised);
    if (phone == null) {
      emit(state.copyWith(phoneError: RegistrationPhoneError.invalid));
      return;
    }
    if (state.isSendingCode) return;
    emit(state.copyWith(isSendingCode: true, phoneError: null));
    final outcome = await _otpService.sendCode(phone.e164);
    switch (outcome) {
      case OtpSendOutcome.sent:
        emit(state.copyWith(
          step: RegistrationStep.otp,
          isSendingCode: false,
          otpError: null,
          failedAttempts: 0,
          resendSecondsRemaining: _policy.resendCooldown.inSeconds,
        ));
        _startResendCountdown();
      case OtpSendOutcome.rateLimited:
        emit(state.copyWith(
          isSendingCode: false,
          phoneError: RegistrationPhoneError.rateLimited,
        ));
      case OtpSendOutcome.networkError:
        emit(state.copyWith(
          isSendingCode: false,
          phoneError: RegistrationPhoneError.networkError,
        ));
    }
  }

  Future<void> resendCode() async {
    if (state.resendSecondsRemaining > 0) return;
    final phone = LebanonPhone.tryParse(state.phoneInput);
    if (phone == null) return;
    final outcome = await _otpService.sendCode(phone.e164);
    switch (outcome) {
      case OtpSendOutcome.sent:
        emit(state.copyWith(
          otpError: null,
          resendSecondsRemaining: _policy.resendCooldown.inSeconds,
        ));
        _startResendCountdown();
      case OtpSendOutcome.rateLimited:
      case OtpSendOutcome.networkError:
        emit(state.copyWith(otpError: RegistrationOtpError.networkError));
    }
  }

  /// Count against attempt budget (max attempt locks out).
  Future<void> verifyCode(String code) async {
    if (state.isVerifying) return;
    final phone = LebanonPhone.tryParse(state.phoneInput);
    if (phone == null) return;
    emit(state.copyWith(isVerifying: true, otpError: null));
    final outcome = await _otpService.verifyCode(
      e164Phone: phone.e164,
      code: code,
    );
    switch (outcome) {
      case OtpVerifyOutcome.verified:
        _stopResendCountdown();
        _stopLockoutCountdown();
        emit(state.copyWith(
          isVerifying: false,
          step: RegistrationStep.verified,
          otpError: null,
        ));
      case OtpVerifyOutcome.invalidCode:
        final next = state.failedAttempts + 1;
        if (next >= _policy.maxAttempts) {
          _stopResendCountdown();
          emit(state.copyWith(
            isVerifying: false,
            failedAttempts: next,
            otpError: null,
            step: RegistrationStep.lockedOut,
            lockoutSecondsRemaining: _policy.lockoutDuration.inSeconds,
          ));
          _startLockoutCountdown();
        } else {
          emit(state.copyWith(
            isVerifying: false,
            failedAttempts: next,
            otpError: RegistrationOtpError.invalid,
          ));
        }
      case OtpVerifyOutcome.rateLimited:
        /// Gateway 429; enter lockout (don't burn attempt).
        _stopResendCountdown();
        emit(state.copyWith(
          isVerifying: false,
          otpError: null,
          step: RegistrationStep.lockedOut,
          lockoutSecondsRemaining: _policy.lockoutDuration.inSeconds,
        ));
        _startLockoutCountdown();
      case OtpVerifyOutcome.expired:
        emit(state.copyWith(
          isVerifying: false,
          otpError: RegistrationOtpError.expired,
        ));
      case OtpVerifyOutcome.networkError:
        emit(state.copyWith(
          isVerifying: false,
          otpError: RegistrationOtpError.networkError,
        ));
    }
  }

  void changePhone() {
    _stopResendCountdown();
    _stopLockoutCountdown();
    emit(state.copyWith(
      step: RegistrationStep.phone,
      otpError: null,
      isSendingCode: false,
      isVerifying: false,
    ));
  }

  void _startResendCountdown() {
    _stopResendCountdown();
    _resendTicker = _tickerFactory().listen((_) {
      if (state.resendSecondsRemaining <= 0) {
        _stopResendCountdown();
        return;
      }
      emit(state.copyWith(
        resendSecondsRemaining: state.resendSecondsRemaining - 1,
      ));
    });
  }

  void _stopResendCountdown() {
    _resendTicker?.cancel();
    _resendTicker = null;
  }

  void _startLockoutCountdown() {
    _stopLockoutCountdown();
    _lockoutTicker = _tickerFactory().listen((_) {
      if (state.lockoutSecondsRemaining <= 1) {
        _stopLockoutCountdown();
        /// Lockout expired: reset attempt budget, bounce to phone entry.
        emit(state.copyWith(
          step: RegistrationStep.phone,
          failedAttempts: 0,
          lockoutSecondsRemaining: 0,
          otpError: null,
        ));
        return;
      }
      emit(state.copyWith(
        lockoutSecondsRemaining: state.lockoutSecondsRemaining - 1,
      ));
    });
  }

  void _stopLockoutCountdown() {
    _lockoutTicker?.cancel();
    _lockoutTicker = null;
  }

  @override
  Future<void> close() {
    _stopResendCountdown();
    _stopLockoutCountdown();
    return super.close();
  }
}
