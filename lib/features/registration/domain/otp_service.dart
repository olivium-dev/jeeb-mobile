const int kCustomerOtpLength = 4;

enum OtpSendOutcome {
  sent,
  rateLimited,
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
