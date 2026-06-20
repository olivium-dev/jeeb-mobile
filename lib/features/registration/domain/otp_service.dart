/// Number of digits in the customer sign-in OTP code.
///
/// Single source of truth: the live gateway (`/v1/auth/otp/verify`) issues a
/// 4-digit code (e.g. seed `1234`). The phone-OTP input and any "code is
/// complete" gate read from here so the canonical code is enterable.
const int kCustomerOtpLength = 4;

/// Outcome of an OTP send request. The cubit maps each value to a state
/// transition; the screen layer renders snackbars/inline errors off the
/// resulting state, not off this enum directly.
enum OtpSendOutcome {
  sent,
  rateLimited,
  networkError,
}

/// Outcome of an OTP verify request. `expired` is distinct from
/// `invalidCode` because the screen surfaces a different copy (resend
/// prompt vs. wrong-code error) and only `invalidCode` counts against the
/// attempt budget.
enum OtpVerifyOutcome {
  verified,
  invalidCode,
  expired,
  networkError,
}

/// Auth-service contract for the phone+OTP flow.
///
/// The production implementation lives in the auth-service Elixir backend
/// (see master-build-prompt.md §auth). T-mobile-002 ships with a fake
/// implementation so the mobile flow can be developed and tested end-to-end
/// before the backend exists. Wire the real client in via DI when ready.
abstract class OtpService {
  Future<OtpSendOutcome> sendCode(String e164Phone);

  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  });
}
