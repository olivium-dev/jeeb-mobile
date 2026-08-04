import 'otp_handover_result.dart';

class OtpFetchResult {
  const OtpFetchResult({this.code, this.smsTriggered = false});

  final String? code;

  /// True when the gateway reported it sent (or re-sent) the code by SMS to
  /// the delivery recipient (`triggered: true`). The UI must then say exactly
  final bool smsTriggered;
}

abstract class OtpHandoverRepository {
  /// Fetches the handover code for a delivery (Client mode). On the live
  /// gateway this call TRIGGERS an SMS to the recipient — callers must treat
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId});

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

enum OtpHandoverErrorKind { network, server, invalidOtp, locked, parse }
