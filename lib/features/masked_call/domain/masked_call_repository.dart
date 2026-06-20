/// Masked / anonymised call session (orders-masked-call).
///
/// COD coordination: a Jeeber and client need to call each other without
/// exposing real phone numbers. The gateway brokers a masked telephony session
/// and returns a proxy number both parties dial; the carrier bridge connects
/// the two real numbers behind the proxy.
///
/// **Gateway contract (backend built in parallel — jeeb-backend-feature-services).**
/// The mobile client speaks the expected gateway `/v1` shape; until the backend
/// route shape is finalised this is the documented contract built against:
///
///   POST /v1/deliveries/{orderId}/masked-call
///     body: { }   (caller resolved from bearer)
///     → 200 { sessionId, proxyNumber, expiresAt? }
///
/// `proxyNumber` is the E.164 number the device then dials via the native
/// dialer (`tel:` URL). See `DioMaskedCallRepository` for the live impl.
library;

/// Result of brokering a masked-call session.
class MaskedCallSession {
  const MaskedCallSession({
    required this.sessionId,
    required this.proxyNumber,
    this.expiresAt,
  });

  /// Server-issued session id (audit / teardown).
  final String sessionId;

  /// The masked proxy number the device dials (E.164). The carrier bridge maps
  /// it to the counterpart's real number for the session's lifetime.
  final String proxyNumber;

  /// Optional server-provided session expiry.
  final DateTime? expiresAt;
}

/// Typed failure surfaced to the cubit (the UI never sees a `DioException`).
enum MaskedCallFailure {
  /// Connection / timeout — no session was brokered.
  network,

  /// Server declined (4xx/5xx) or returned no proxy number.
  unavailable,

  /// The device could not launch the native dialer for the proxy number.
  dialerUnavailable,
}

/// Thrown by the data layer; the cubit maps [failure] to localized copy.
class MaskedCallException implements Exception {
  const MaskedCallException(this.failure, [this.message]);

  final MaskedCallFailure failure;
  final String? message;

  @override
  String toString() => 'MaskedCallException($failure, $message)';
}

/// Domain port for brokering a masked-call session. The cubit + tests depend on
/// this abstraction; DI binds the Dio-backed impl in production.
abstract class MaskedCallRepository {
  const MaskedCallRepository();

  /// Requests a masked-call session for [orderId].
  ///
  /// Throws [MaskedCallException] on failure.
  Future<MaskedCallSession> requestSession({required String orderId});
}
