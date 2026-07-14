import 'delivery_tracking_info.dart';

abstract class LiveTrackingRepository {
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  });
}

/// JEBV4-269: optional capability a [LiveTrackingRepository] MAY also implement
/// to supply the live Jeeber GPS position + straight-line route the customer's
/// map renders, read from the gateway's `GET /deliveries/{id}/tracking`
/// snapshot (the same store the jeeber's uploader writes to).
///
/// Kept OUT of the core [LiveTrackingRepository] interface so the debug demo
/// repo, devtool seams, and existing tests need no change — the cubit
/// feature-detects it with `repo is LivePositionSource` and simply skips the
/// position overlay when a repo doesn't provide one.
abstract class LivePositionSource {
  /// Best-effort read of the latest Jeeber position + route polyline. Returns
  /// null when unavailable (no fix recorded yet, the caller is not a party, or
  /// a transport error) — callers MUST degrade gracefully and never fault the
  /// tracking screen on a missing position.
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  });
}

/// The live-tracking overlay: the Jeeber's latest position and the straight-line
/// route to the dropoff. Both may be empty/null before the first GPS fix.
class DeliveryLivePosition {
  const DeliveryLivePosition({this.jeeberPosition, this.polyline = const []});

  final GpsPoint? jeeberPosition;
  final List<GpsPoint> polyline;

  /// True when there is nothing new to overlay (no fix and no route yet).
  bool get isEmpty => jeeberPosition == null && polyline.isEmpty;
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
