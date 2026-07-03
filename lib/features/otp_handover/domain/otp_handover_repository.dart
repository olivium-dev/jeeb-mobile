import 'otp_handover_result.dart';

/// Outcome of `GET /v1/deliveries/{id}/otp` (client mode).
///
/// G4 (sprint-009): the LIVE gateway's endpoint is an SMS *trigger* — it
/// returns `{deliveryId, triggered, message}` and NO `code` (run-23 wire
/// evidence), while the mock/wave-11 contract can include `code`. Both are
/// legitimate shapes, so the fetch surfaces WHICH one happened instead of
/// throwing `parse` on the live body (the pre-fix behavior, which flipped the
/// customer screen into a code-ENTRY grid for a code they were never shown).
class OtpFetchResult {
  const OtpFetchResult({this.code, this.smsTriggered = false});

  /// The 4-digit handover code, when the gateway returned one for in-app
  /// display. Null on the live SMS-trigger shape.
  final String? code;

  /// True when the gateway reported it sent (or re-sent) the code by SMS to
  /// the delivery recipient (`triggered: true`). The UI must then say exactly
  /// that — never pretend a code is available in-app.
  final bool smsTriggered;
}

abstract class OtpHandoverRepository {
  /// Fetches the handover code for a delivery (Client mode). On the live
  /// gateway this call TRIGGERS an SMS to the recipient — callers must treat
  /// it as a side-effectful "send me the code" action, not a passive read
  /// (the passive source is the accept-time `HandoverCodeStore`).
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId});

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
