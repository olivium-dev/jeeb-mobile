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
  const OtpHandoverException(this.kind, [this.cause, this.attemptsRemaining]);

  final OtpHandoverErrorKind kind;
  final Object? cause;

  /// Server-reported attempts left before lockout; null when the gateway
  /// said nothing and the screen must fall back to its own count.
  final int? attemptsRemaining;

  @override
  String toString() => 'OtpHandoverException(${kind.name})';
}

/// A 423 carries the case the gateway already opened, so the screen routes to
/// it instead of offering to open a second one.
final class OtpHandoverLocked extends OtpHandoverException {
  const OtpHandoverLocked({
    this.escalationId,
    this.lockedAt,
    int? attemptsRemaining,
    Object? cause,
  }) : super(OtpHandoverErrorKind.locked, cause, attemptsRemaining);

  final String? escalationId;
  final DateTime? lockedAt;

  @override
  String toString() => 'OtpHandoverLocked(escalationId: $escalationId)';
}

enum OtpHandoverErrorKind {
  network,
  server,
  invalidOtp,
  locked,
  parse,
  notAtDoor,
  wrongParty,
  notFound,

  /// The session expired on the READ leg — a sign-in exit, not a wrong code.
  unauthorized,
}
