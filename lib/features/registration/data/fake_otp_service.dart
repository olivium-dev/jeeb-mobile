import '../domain/otp_service.dart';

/// Dev-only [OtpService]. Accepts '1234' (matching live gateway seed); every send is "sent".
/// Swap for real Dio-backed client once auth-service /api/jeeb/auth/otp endpoints land.
class FakeOtpService implements OtpService, OtpSendResultService {
  const FakeOtpService({this.validCode = '1234', this.latency});

  final String validCode;

  final Duration? latency;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async {
    if (latency != null) await Future.delayed(latency!);
    return OtpSendOutcome.sent;
  }

  @override
  Future<OtpSendResult> requestCode(String e164Phone) async =>
      OtpSendResult(outcome: await sendCode(e164Phone));

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async {
    if (latency != null) await Future.delayed(latency!);
    if (code == validCode) return OtpVerifyOutcome.verified;
    return OtpVerifyOutcome.invalidCode;
  }
}
