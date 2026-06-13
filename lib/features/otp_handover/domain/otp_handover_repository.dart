import 'otp_handover_result.dart';

abstract class OtpHandoverRepository {
  /// Fetches the handover code for a delivery (Client mode).
  Future<String> fetchHandoverCode({required String deliveryId});

  /// Submits the OTP to transition the delivery to Delivered (Jeeber mode).
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  });
}

class OtpHandoverException implements Exception {
  const OtpHandoverException(this.kind, [this.cause]);

  final OtpHandoverErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'OtpHandoverException(${kind.name}${cause == null ? '' : ', $cause'})';
}

/// T-MOB-018 AC4: `locked` maps to HTTP 423 (3 attempts exhausted → escalate).
enum OtpHandoverErrorKind { network, server, invalidOtp, locked, parse }
