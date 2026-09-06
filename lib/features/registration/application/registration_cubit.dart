import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/international_phone.dart';
import '../domain/otp_service.dart';
import '../domain/registration_attempt_policy.dart';
import '../domain/registration_country_metadata.dart';
import 'registration_state.dart';

/// Phone+OTP registration flow.
class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit({
    required OtpService otpService,
    RegistrationAttemptPolicy policy = const RegistrationAttemptPolicy(),
    Stream<DateTime> Function()? tickerFactory,
  }) : _otpService = otpService,
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
    final normalised = InternationalPhone.normaliseForEditing(
      countryCode: state.selectedCountryCode,
      raw: raw,
    );
    emit(state.copyWith(phoneInput: normalised, phoneError: null));
  }

  void countryChanged(String countryCode) {
    if (RegistrationCountryCatalog.byCode(countryCode) == null) return;
    final normalised = InternationalPhone.normaliseForEditing(
      countryCode: countryCode,
      raw: state.phoneInput,
    );
    emit(
      state.copyWith(
        selectedCountryCode: countryCode,
        phoneInput: normalised,
        phoneError: null,
      ),
    );
  }

  /// TRAP: must re-sync rendered phone (field can lag via autofill/paste).
  Future<void> sendCode({String? renderedPhone}) async {
    final source = renderedPhone ?? state.phoneInput;
    final normalised = InternationalPhone.normaliseForEditing(
      countryCode: state.selectedCountryCode,
      raw: source,
    );
    if (normalised != state.phoneInput) {
      emit(state.copyWith(phoneInput: normalised));
    }
    final phone = InternationalPhone.tryParse(
      countryCode: state.selectedCountryCode,
      raw: normalised,
    );
    if (phone == null) {
      emit(state.copyWith(phoneError: RegistrationPhoneError.invalid));
      return;
    }
    if (state.isSendingCode) return;
    // AE-17: a 429 window the CTA advertises must actually hold the request.
    if (state.isRateLimitedNow) return;
    emit(state.copyWith(isSendingCode: true, phoneError: null));
    final result = await _requestCode(phone.e164);
    switch (result.outcome) {
      case OtpSendOutcome.sent:
        emit(
          state.copyWith(
            step: RegistrationStep.otp,
            isSendingCode: false,
            otpError: null,
            failedAttempts: 0,
            resendSecondsRemaining: _resendWindow(result),
            otpRetryAfterSeconds: null,
          ),
        );
        _startResendCountdown();
      case OtpSendOutcome.invalidPhone:
        emit(
          state.copyWith(
            isSendingCode: false,
            phoneError: RegistrationPhoneError.invalid,
          ),
        );
      case OtpSendOutcome.rateLimited:
        // AE-17: the CTA must be dead for the SERVER's window, not our guess.
        emit(
          state.copyWith(
            isSendingCode: false,
            phoneError: RegistrationPhoneError.rateLimited,
            resendSecondsRemaining: _resendWindow(result),
            otpRetryAfterSeconds: _resendWindow(result),
          ),
        );
        _startResendCountdown();
      case OtpSendOutcome.serverError:
        emit(
          state.copyWith(
            isSendingCode: false,
            phoneError: RegistrationPhoneError.serverError,
          ),
        );
      case OtpSendOutcome.networkError:
        emit(
          state.copyWith(
            isSendingCode: false,
            phoneError: RegistrationPhoneError.networkError,
          ),
        );
    }
  }

  /// X1/R3: [OtpSendResultService] is a separate one-method interface, so the
  /// eight `implements OtpService` sites keep compiling.
  Future<OtpSendResult> _requestCode(String e164) async {
    // `Object` so the `is` test can promote: OtpSendResultService is a sibling
    // interface, not a subtype of OtpService.
    final Object service = _otpService;
    if (service is OtpSendResultService) return service.requestCode(e164);
    return OtpSendResult(outcome: await _otpService.sendCode(e164));
  }

  int _resendWindow(OtpSendResult result) =>
      result.retryAfter?.inSeconds ?? _policy.resendCooldown.inSeconds;

  Future<void> resendCode() async {
    if (state.resendSecondsRemaining > 0 || state.isSendingCode) return;
    final phone = state.parsedPhone;
    if (phone == null) return;
    emit(state.copyWith(isSendingCode: true, otpError: null));
    final result = await _requestCode(phone.e164);
    switch (result.outcome) {
      case OtpSendOutcome.sent:
        emit(
          state.copyWith(
            isSendingCode: false,
            otpError: null,
            resendSecondsRemaining: _resendWindow(result),
            otpRetryAfterSeconds: null,
          ),
        );
        _startResendCountdown();
      case OtpSendOutcome.rateLimited:
        emit(
          state.copyWith(
            isSendingCode: false,
            otpError: RegistrationOtpError.rateLimited,
            // The copy and the CTA must name the SAME window: a header-less 429
            // otherwise reads "request a new code now" while Resend is dead.
            resendSecondsRemaining: _resendWindow(result),
            otpRetryAfterSeconds: _resendWindow(result),
          ),
        );
        _startResendCountdown();
      case OtpSendOutcome.serverError:
        emit(
          state.copyWith(
            isSendingCode: false,
            otpError: RegistrationOtpError.serverError,
          ),
        );
      case OtpSendOutcome.networkError:
        emit(
          state.copyWith(
            isSendingCode: false,
            otpError: RegistrationOtpError.networkError,
          ),
        );
      case OtpSendOutcome.invalidPhone:
        // The number itself is the problem, so the OTP step cannot fix it.
        _stopResendCountdown();
        emit(
          state.copyWith(
            isSendingCode: false,
            step: RegistrationStep.phone,
            otpError: null,
            phoneError: RegistrationPhoneError.invalid,
          ),
        );
    }
  }

  /// Count against attempt budget (max attempt locks out).
  Future<void> verifyCode(String code) async {
    if (state.isVerifying) return;
    final phone = state.parsedPhone;
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
        emit(
          state.copyWith(
            isVerifying: false,
            step: RegistrationStep.verified,
            otpError: null,
          ),
        );
      case OtpVerifyOutcome.invalidCode:
        final next = state.failedAttempts + 1;
        if (next >= _policy.maxAttempts) {
          _stopResendCountdown();
          emit(
            state.copyWith(
              isVerifying: false,
              failedAttempts: next,
              otpError: null,
              step: RegistrationStep.lockedOut,
              lockoutSecondsRemaining: _policy.lockoutDuration.inSeconds,
              otpRetryAfterSeconds: null,
              lockoutFromRateLimit: false,
            ),
          );
          _startLockoutCountdown();
        } else {
          emit(
            state.copyWith(
              isVerifying: false,
              failedAttempts: next,
              otpError: RegistrationOtpError.invalid,
            ),
          );
        }
      case OtpVerifyOutcome.rateLimited:

        /// Gateway 429; enter lockout (don't burn attempt). The verify outcome
        /// carries no window, so the local policy duration is what we enforce.
        _stopResendCountdown();
        emit(
          state.copyWith(
            isVerifying: false,
            otpError: null,
            step: RegistrationStep.lockedOut,
            lockoutSecondsRemaining: _policy.lockoutDuration.inSeconds,
            otpRetryAfterSeconds: _policy.lockoutDuration.inSeconds,
            lockoutFromRateLimit: true,
          ),
        );
        _startLockoutCountdown();
      case OtpVerifyOutcome.expired:
        emit(
          state.copyWith(
            isVerifying: false,
            otpError: RegistrationOtpError.expired,
          ),
        );
      case OtpVerifyOutcome.accountSuspended:
        // Never counts as a failed attempt: the code was accepted, the account
        // was refused. Burning attempts here would lock out a user who did
        // nothing wrong, on top of showing them the wrong reason.
        _stopResendCountdown();
        emit(
          state.copyWith(
            isVerifying: false,
            otpError: RegistrationOtpError.accountSuspended,
          ),
        );
      case OtpVerifyOutcome.serverError:
        emit(
          state.copyWith(
            isVerifying: false,
            otpError: RegistrationOtpError.serverError,
          ),
        );
      case OtpVerifyOutcome.serviceUnavailable:
        emit(
          state.copyWith(
            isVerifying: false,
            otpError: RegistrationOtpError.serviceUnavailable,
          ),
        );
      case OtpVerifyOutcome.networkError:
        emit(
          state.copyWith(
            isVerifying: false,
            otpError: RegistrationOtpError.networkError,
          ),
        );
    }
  }

  void changePhone() {
    _stopResendCountdown();
    _stopLockoutCountdown();
    emit(
      state.copyWith(
        step: RegistrationStep.phone,
        otpError: null,
        isSendingCode: false,
        isVerifying: false,
        otpRetryAfterSeconds: null,
        lockoutFromRateLimit: false,
      ),
    );
  }

  void _startResendCountdown() {
    _stopResendCountdown();
    _resendTicker = _tickerFactory().listen((_) {
      if (state.resendSecondsRemaining <= 0) {
        _stopResendCountdown();
        return;
      }
      final next = state.resendSecondsRemaining - 1;
      // The 429 copy names a window; once it elapses the message is a lie.
      final expired = next == 0;
      emit(
        state.copyWith(
          resendSecondsRemaining: next,
          otpError: expired && state.otpError == RegistrationOtpError.rateLimited
              ? null
              : state.otpError,
          phoneError:
              expired && state.phoneError == RegistrationPhoneError.rateLimited
              ? null
              : state.phoneError,
          otpRetryAfterSeconds: expired ? null : state.otpRetryAfterSeconds,
        ),
      );
      if (expired) _stopResendCountdown();
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
        emit(
          state.copyWith(
            step: RegistrationStep.phone,
            failedAttempts: 0,
            lockoutSecondsRemaining: 0,
            otpError: null,
            otpRetryAfterSeconds: null,
            lockoutFromRateLimit: false,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          lockoutSecondsRemaining: state.lockoutSecondsRemaining - 1,
        ),
      );
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
