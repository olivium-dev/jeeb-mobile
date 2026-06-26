import 'delivery_tracking_info.dart';

abstract class LiveTrackingRepository {
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  });
}

class LiveTrackingException implements Exception {
  const LiveTrackingException(this.kind, [this.cause]);

  final LiveTrackingErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'LiveTrackingException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum LiveTrackingErrorKind {
  network,
  server,

  /// The delivery row does not exist (HTTP 404). Distinct from a transient
  /// [server] error: it usually means the screen was opened with the wrong id
  /// (e.g. a request id instead of the server delivery id) OR the accept-minted
  /// delivery has not propagated yet. Surfaced as a dedicated empty/error
  /// state with a retry, never a crash.
  notFound,
  parse,
}
