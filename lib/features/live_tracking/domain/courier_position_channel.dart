/// One courier position, as it arrives on a subscription rather than as the
/// answer to a question we asked.
///
/// Deliberately NOT [DeliveryLivePosition]: that type is the shape of the
/// one-shot `GET /deliveries/{id}/tracking` snapshot and carries a polyline and
/// the gateway's own `stale` verdict, neither of which a single pushed fix has
/// or could have. Reusing it would force this transport to invent values for
/// two fields the wire never sent, and inventing a `stale: false` for a fix
/// whose age we did not measure is exactly the phantom-marker failure the
/// snapshot path's negative control exists to catch. A pushed fix IS fresh —
/// the gateway publishes it from the ingest of the courier's own upload — and
/// that is a property of the transport, stated once, where it is true.
class CourierPositionFix {
  const CourierPositionFix({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.timestamp,
    this.jeeberId,
  });

  final double lat;
  final double lng;

  /// Reported GPS accuracy in metres, when the courier's device supplied one.
  final double? accuracy;

  /// The courier device's own clock at the moment of the fix. Advisory: it is
  /// the DEVICE's time, so it may be skewed; nothing here is gated on it.
  final DateTime? timestamp;

  /// The courier the fix belongs to, stamped by the gateway from the bearer at
  /// ingest (never from the request body).
  final String? jeeberId;

  @override
  String toString() => 'CourierPositionFix($lat, $lng)';
}

/// A push transport for the courier-position axis.
///
/// ## Why this is a separate, OPTIONAL capability
///
/// Exactly the reasoning that keeps
/// `LivePositionSource` out of `LiveTrackingRepository`: the debug demo repo,
/// the devtool seams and the `:4010` mock have no realtime service behind them,
/// and a screen that requires one would break on all three. `LiveTrackingCubit`
/// takes a `CourierPositionChannel?` and does strictly less when it is null.
///
/// ## The contract [open] must honour, and why every clause is load-bearing
///
///  * **It returns `null` rather than throwing** for every "cannot subscribe"
///    outcome — the descriptor 403s (not a party), 404s (unknown delivery),
///    503s (the deployment has no realtime credential), the transport is
///    unreachable, or the descriptor came back with a `socketUrl` of `null`.
///    A tracking screen whose stepper and summary are healthy must never be
///    faulted by a position transport that is not there.
///  * **A `null` `socketUrl` is a first-class case, not an edge one.**
///    `Services:Realtime:PublicSocketUrl` is unset by default on the gateway,
///    and it deliberately yields `null` rather than a guess derived from the
///    gateway's own loopback `BaseUrl` — because handing a phone
///    `ws://127.0.0.1/...` fails silently and reads as a product bug. The
///    mobile half must therefore treat `null` as "this deployment has no
///    device-reachable socket" and degrade, not as data to repair.
///  * **The returned stream owns its socket.** Cancelling the subscription
///    closes the WebSocket. A transport whose teardown lives somewhere else is
///    one early `return` away from an open socket per screen entry.
abstract class CourierPositionChannel {
  /// Subscribe to [deliveryId]'s live courier position.
  ///
  /// Returns `null` when no subscription can be opened — see the class doc. The
  /// returned stream is single-subscription; cancelling it closes the socket.
  Future<Stream<CourierPositionFix>?> open({required String deliveryId});
}
