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

  /// The gateway answered with a fault (5xx other than 502/503/504, an
  /// unusable 2xx body, or an unclassifiable status). Never the connection.
  serverError,

  /// 502/503/504 — sign-in is down, not broken. Worth another try shortly.
  serviceUnavailable,

  networkError,
}

/// What a send attempt produced, with the two things the outcome alone cannot
/// carry: the server's back-off window and the code's own lifetime.
class OtpSendResult {
  const OtpSendResult({required this.outcome, this.retryAfter, this.ttlSeconds});

  final OtpSendOutcome outcome;

  /// `Retry-After` from a 429, so the resend CTA is disabled for the server's
  /// window rather than the local policy's guess.
  final Duration? retryAfter;

  /// How long the sent code stays valid, when the gateway says.
  final int? ttlSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpSendResult &&
          other.outcome == outcome &&
          other.retryAfter == retryAfter &&
          other.ttlSeconds == ttlSeconds;

  @override
  int get hashCode => Object.hash(outcome, retryAfter, ttlSeconds);

  @override
  String toString() =>
      'OtpSendResult(${outcome.name}, retryAfterSeconds: ${retryAfter?.inSeconds}, '
      'ttlSeconds: $ttlSeconds)';
}

abstract class OtpService {
  Future<OtpSendOutcome> sendCode(String e164Phone);

  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  });
}

/// The richer send channel, kept OFF [OtpService] so its eight implementors
/// keep compiling; call sites feature-test with `is OtpSendResultService`.
abstract class OtpSendResultService {
  Future<OtpSendResult> requestCode(String e164Phone);
}
