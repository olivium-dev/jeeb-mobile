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
  networkError,
}

abstract class OtpService {
  Future<OtpSendOutcome> sendCode(String e164Phone);

  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  });
}
