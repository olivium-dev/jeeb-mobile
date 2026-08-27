const int kCustomerOtpLength = 4;

enum OtpSendOutcome {
  sent,

  /// The gateway itself rejected the phone as malformed/unsupported (HTTP 400).
  /// Distinct from [networkError]/[serverError]: the request reached the
  /// gateway and was evaluated, and the number really is the problem.
  invalidPhone,

  rateLimited,

  /// The gateway responded, but with a fault status other than 429/400
  /// (5xx, or any other unexpected non-success code). The number is not
  /// the problem; the request never got a chance to succeed.
  serverError,

  /// No response reached the gateway at all: offline, DNS failure,
  /// connection/receive timeout, or the request was cancelled.
  networkError,
}

enum OtpVerifyOutcome {
  verified,
  invalidCode,

  rateLimited,
  expired,

  /// Gateway 403 account_suspended. Distinct from [invalidCode]: the code was
  /// fine, the account is not. Telling the user "wrong code" sends them to
  /// re-enter a correct code forever.
  accountSuspended,
  networkError,
}

abstract class OtpService {
  Future<OtpSendOutcome> sendCode(String e164Phone);

  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  });
}
