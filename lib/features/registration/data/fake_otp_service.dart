import '../domain/otp_service.dart';

/// Development-only [OtpService] that pretends to talk to the auth-service.
///
/// Accepts `123456` as the only valid code. Every send is "sent". This
/// lets the registration flow be developed and demoed end-to-end before
/// the auth-service /api/jeeb/auth/otp endpoints land — once they do, swap
/// this implementation in the DI container for the real Dio-backed client.
class FakeOtpService implements OtpService {
  const FakeOtpService({this.validCode = '123456', this.latency});

  final String validCode;

  /// Optional artificial delay so the "Sending…" pending state is visible
  /// in manual QA. Tests pass `Duration.zero` to keep them fast.
  final Duration? latency;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async {
    if (latency != null) await Future.delayed(latency!);
    return OtpSendOutcome.sent;
  }

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
