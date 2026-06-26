import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/lebanon_phone.dart';
import '../domain/otp_service.dart';
import '../domain/registration_attempt_policy.dart';
import 'registration_state.dart';

/// Owns the phone+OTP registration flow.
///
/// Three external collaborators:
///   - [OtpService] — talks to auth-service to send/verify codes.
///   - [RegistrationAttemptPolicy] — supplies the lockout/resend numbers.
///   - [Stream<DateTime>] tick (injected via [tickerFactory]) — drives the
///     resend countdown and the lockout countdown without [Future.delayed]
///     loops, so tests can swap in `fake_async`-style streams.
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

  /// Expose the policy for the screen layer (e.g. the lockout banner needs
  /// to format `lockoutDuration` on first render before the first tick).
  RegistrationAttemptPolicy get policy => _policy;

  /// Called on every keystroke in the phone field. Normalises and stores;
  /// clears any prior phone error so the user isn't yelled at while typing.
  void phoneChanged(String raw) {
    final normalised = LebanonPhone.normalise(raw);
    emit(state.copyWith(phoneInput: normalised, phoneError: null));
  }

  /// Tap on the "Send code" CTA. Validates, sends, transitions to
  /// [RegistrationStep.otp], starts the resend countdown.
  ///
  /// [renderedPhone] is the live text of the phone [TextEditingController] as
  /// the user actually sees it. The screen MUST pass it: the field — not the
  /// cubit — is the source of truth while typing (PR #45 stopped mirroring the
  /// normalised value back per-keystroke), so `state.phoneInput` can lag or
  /// diverge from the rendered text on any path that doesn't route through
  /// `phoneChanged` (programmatic seed, autofill, paste). Reading the rendered
  /// text here — and re-syncing it into `phoneInput` — means Send always
  /// validates and sends the number the user is looking at, instead of a stale
  /// cubit value that flipped the field red and emitted zero OTP requests
  /// (BUG-1, customer-spine blocker). Cubit-only callers (tests) may omit it.
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

  /// Tap on the "Resend code" link. No-op while the cooldown is running.
  Future<void> resendCode() async {
    if (state.resendSecondsRemaining > 0) return;
    final phone = LebanonPhone.tryParse(state.phoneInput);
    if (phone == null) return; // safety; UI can't reach here otherwise
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

  /// Tap on the "Verify" CTA. Counts wrong codes against the attempt
  /// budget; the [_policy.maxAttempts]-th wrong code locks out.
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
        // Gateway rate-limited the verify (429). Treat as a cooldown: enter the
        // lockout step with its countdown instead of burning an attempt.
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

  /// Tap on the "Change phone number" link on the OTP screen. Returns to
  /// phone entry without resetting the typed digits, in case the user
  /// just wants to edit a typo.
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
        // Lockout expired → reset attempt budget and bounce the user back
        // to phone entry so they can request a fresh code.
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
