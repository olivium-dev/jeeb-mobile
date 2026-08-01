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
///
/// ## This is the ONLY courier-position surface the gateway still serves
///
/// There used to be a second one: an SSE stream capability, with a client class
/// implementing it against a `geo` alias route. Both are **deleted**, because
/// the route they depended on is deleted: `jeeb-gateway` #333 (`b6fe888`)
/// removed the alias along with the 5 s server-side re-read loop it existed to
/// open, and pinned the removal with
/// `tests/JeebGateway.IntegrationTests/Tracking/NoBackendPollOrFirestoreListenerGuardTests.cs:143`
/// (`Sse_Alias_Route_Is_Gone` — a party to the delivery must get **404**).
/// That PR's own consumer note says it plainly: *"a client that calls the alias
/// path gets 404 and must move to /deliveries/{id}/tracking."* The mobile half
/// of that migration never happened, which is why the customer's map showed no
/// courier for four days while the jeeber's uploads were 200-ing.
///
/// Neither the alias path nor the two deleted Dart type names is spelled out
/// anywhere in this repo any more. That is MB1's V-1 contract: it greps the
/// whole tree, and to `grep` a doc comment and a live call site are the same
/// thing. `Sse_Alias_Route_Is_Gone` is the durable handle to the full story.
///
/// The same guard bans both the event-stream content type and the alias path
/// from the shipped gateway assembly, so the alias cannot be restored
/// server-side without deliberately breaking a merged gate.
/// `GET /deliveries/{id}/tracking`
/// reads the SAME `ILocationStore` the ingest writes (`LocationController.cs:170`
/// writes, `:297` reads) — the write and read paths were never disconnected;
/// only the client's URL was wrong.
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
  const DeliveryLivePosition({
    this.jeeberPosition,
    this.polyline = const [],
    this.stale = false,
    this.secondsSinceUpdate,
  });

  final GpsPoint? jeeberPosition;
  final List<GpsPoint> polyline;

  /// The gateway's own verdict that the newest fix it holds is older than
  /// `Tracking:StaleThreshold` (default 2 min) — `stale` on `TrackingPolylineDto`
  /// (`jeeb-gateway/src/JeebGateway/Controllers/LocationController.cs:316`).
  ///
  /// Load-bearing for the NEGATIVE control: the map must not draw a courier
  /// marker at a position the courier left ten minutes ago. A stale overlay is
  /// still carried (so the screen can say *when* the jeeber was last seen)
  /// rather than dropped, but it must not be rendered as a live marker.
  final bool stale;

  /// Age of the newest fix in seconds — `secondsSinceUpdate` on the same DTO
  /// (`LocationController.cs:317`). Null when the gateway holds no fix at all.
  final double? secondsSinceUpdate;

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
