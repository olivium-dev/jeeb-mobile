import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';

const String otpVerificationScreenPhoneInput = '71234567';

const String otpVerificationScreenDisplayPhone = '+961 71234567';

/// The production attempt policy, named so a fixture can be read against it:
/// 3 attempts, a 60 s resend cooldown, a 60 s lockout.
const RegistrationAttemptPolicy otpVerificationScreenPolicy =
    RegistrationAttemptPolicy();

/// A ticker that never ticks — see the note at the top of this file.
Stream<DateTime> _otpVerificationScreenNoTicks() =>
    const Stream<DateTime>.empty();

class OtpVerificationScreenSeededCubit extends RegistrationCubit {
  OtpVerificationScreenSeededCubit(RegistrationState seed)
      : super(
          otpService: const FakeOtpService(),
          policy: otpVerificationScreenPolicy,
          tickerFactory: _otpVerificationScreenNoTicks,
        ) {
    emit(seed);
  }
}

/// Base for every OTP-step fixture: the code is sent, nothing typed yet.
const RegistrationState _otpVerificationScreenOtpStep = RegistrationState(
  step: RegistrationStep.otp,
  phoneInput: otpVerificationScreenPhoneInput,
);

/// The state the user lands in the moment the code is sent: the four cells are
/// empty and the resend cooldown is at its full 60 s.
RegistrationCubit otpVerificationScreenCountingDownCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        resendSecondsRemaining: otpVerificationScreenPolicy
            .resendCooldown
            .inSeconds,
      ),
    );

RegistrationCubit otpVerificationScreenResendReadyCubit() =>
    OtpVerificationScreenSeededCubit(_otpVerificationScreenOtpStep);

RegistrationCubit otpVerificationScreenWrongCodeCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        failedAttempts: 1,
        otpError: RegistrationOtpError.invalid,
      ),
    );

/// Two wrong codes in: the next one locks the account out for a minute.
/// The state that renders `registrationOtpAttemptsRemaining(1)` — see the
RegistrationCubit otpVerificationScreenLastAttemptCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        failedAttempts: 2,
        otpError: RegistrationOtpError.invalid,
      ),
    );

RegistrationCubit otpVerificationScreenExpiredCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        otpError: RegistrationOtpError.expired,
      ),
    );

/// The verify never reached the gateway (`OtpVerifyOutcome.networkError`).
/// Costs no attempt either. What it renders is the point — see the preview.
RegistrationCubit otpVerificationScreenNetworkErrorCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        otpError: RegistrationOtpError.networkError,
      ),
    );

RegistrationCubit otpVerificationScreenVerifyingCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(isVerifying: true),
    );

RegistrationCubit otpVerificationScreenLockedOutCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        step: RegistrationStep.lockedOut,
        failedAttempts: otpVerificationScreenPolicy.maxAttempts,
        lockoutSecondsRemaining: 45,
      ),
    );

RegistrationCubit otpVerificationScreenRateLimitedCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        step: RegistrationStep.lockedOut,
        lockoutSecondsRemaining:
            otpVerificationScreenPolicy.lockoutDuration.inSeconds,
      ),
    );
