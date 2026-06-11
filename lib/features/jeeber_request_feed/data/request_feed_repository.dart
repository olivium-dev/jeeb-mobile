import 'dart:async';
import 'dart:math' as math;

import 'request_feed_models.dart';

/// Outcome of an accept/decline call back to jeeb-gateway. Kept narrow on
/// purpose — the cubit only needs to know whether the seat was taken,
/// whether the request had already closed, or whether the network blew up.
enum RequestActionOutcome {
  accepted,
  declined,
  alreadyTaken,
  expired,
  networkError,
}

/// Transport the repository negotiated with jeeb-gateway. Drives the badge
/// the screen shows in the app bar so the Jeeber knows when they're on the
/// degraded polling path versus the real-time WebSocket feed.
enum FeedTransport {
  webSocket,

  /// jeeb-gateway is reachable but the WS upgrade failed (or fell over).
  /// The repository fires polling ticks instead.
  polling,
}

/// One-shot connectivity update emitted by [RequestFeedRepository.transport].
/// The cubit forwards the latest value into its state so the screen layer
/// can render a "reconnecting…" banner when polling kicks in.
class FeedTransportUpdate {
  const FeedTransportUpdate(this.transport);
  final FeedTransport transport;
}

/// The repository the cubit talks to. Owns:
///
///   1. The realtime feed stream — emits new [DeliveryRequest]s and, in
///      WebSocket mode, may also emit "cancelled" notifications via
///      [cancellations]. The polling fallback path only emits the snapshot
///      and lets the per-request `expiresAt` retire stale entries.
///   2. The transport status stream — flips between [FeedTransport.webSocket]
///      and [FeedTransport.polling] so the UI can surface the degraded state.
///   3. Accept/decline RPCs.
///
/// jeeb-gateway is the only backend the implementation talks to (per
/// JEEB-BOUNDARIES.md §4); the WebSocket fanout is brokered by jeeb-gateway
/// via realtime-comunication-service per REUSE-MAP.md.
abstract class RequestFeedRepository {
  /// Stream of new [DeliveryRequest] payloads. The cubit dedupes by id so
  /// re-pushes of the same request (which can happen across a WS reconnect)
  /// don't multiply on screen.
  Stream<DeliveryRequest> get requests;

  /// Stream of request ids the backend has cancelled (sender pulled the
  /// request, another Jeeber accepted it, gateway expired it). The cubit
  /// removes any matching card from the feed.
  Stream<String> get cancellations;

  /// Current transport (and changes thereto). Always emits the current
  /// value on subscribe so the cubit doesn't need a separate initial fetch.
  Stream<FeedTransportUpdate> get transport;

  /// Pull a fresh snapshot of pending requests. Triggered by pull-to-refresh
  /// and on screen open. Returning a snapshot here doesn't preclude further
  /// pushes via [requests]; the cubit merges both streams.
  Future<List<DeliveryRequest>> refresh();

  /// Accept the request with [id]. The repository's responsibility is to
  /// surface the outcome; it's the cubit's job to take the card off the feed
  /// and route the Jeeber into the active-delivery flow on `accepted`.
  Future<RequestActionOutcome> accept(String id);

  /// Decline (mark "not interested") the request with [id]. The card
  /// disappears either way; the outcome only matters for telemetry.
  Future<RequestActionOutcome> decline(String id);

  /// Tear down any open sockets / timers. The cubit calls this on close.
  Future<void> dispose();
}

/// Dev/double implementation used until the real jeeb-gateway client lands.
/// Generates a tiny synthetic feed so the screen layer renders during
/// development without needing the backend up. The class is deliberately
/// self-contained — no platform calls — so widget tests can substitute it
/// without extra mocking.
class FakeRequestFeedRepository implements RequestFeedRepository {
  FakeRequestFeedRepository({
    Duration emitInterval = const Duration(seconds: 12),
    Duration requestTtl = const Duration(seconds: 60),
    math.Random? random,
  })  : _emitInterval = emitInterval,
        _requestTtl = requestTtl,
        _random = random ?? math.Random();

  final Duration _emitInterval;
  final Duration _requestTtl;
  final math.Random _random;

  final StreamController<DeliveryRequest> _requests =
      StreamController<DeliveryRequest>.broadcast();
  final StreamController<String> _cancellations =
      StreamController<String>.broadcast();
  final StreamController<FeedTransportUpdate> _transport =
      StreamController<FeedTransportUpdate>.broadcast();

  Timer? _emitter;
  int _counter = 0;

  @override
  Stream<DeliveryRequest> get requests => _requests.stream;

  @override
  Stream<String> get cancellations => _cancellations.stream;

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
    yield* _transport.stream;
  }

  @override
  Future<List<DeliveryRequest>> refresh() async {
    _emitter ??= Timer.periodic(_emitInterval, (_) {
      if (_requests.isClosed) return;
      _requests.add(_synthesise());
    });
    return List.generate(2, (_) => _synthesise());
  }

  @override
  Future<RequestActionOutcome> accept(String id) async {
    return RequestActionOutcome.accepted;
  }

  @override
  Future<RequestActionOutcome> decline(String id) async {
    return RequestActionOutcome.declined;
  }

  @override
  Future<void> dispose() async {
    _emitter?.cancel();
    _emitter = null;
    await _requests.close();
    await _cancellations.close();
    await _transport.close();
  }

  DeliveryRequest _synthesise() {
    _counter += 1;
    final tier = JeeberRequestTier.values[_random.nextInt(3)];
    final distance = 1 + _random.nextDouble() * 8;
    final ratePerKm = switch (tier) {
      JeeberRequestTier.light => 0.6,
      JeeberRequestTier.standard => 0.9,
      JeeberRequestTier.bulk => 1.4,
      JeeberRequestTier.flash => 1.6,
    };
    return DeliveryRequest(
      id: 'fake-$_counter',
      pickup: RequestLocation(
        label: 'Pickup #$_counter — Hamra St',
        latitude: 33.8959 + _random.nextDouble() * 0.01,
        longitude: 35.4825 + _random.nextDouble() * 0.01,
      ),
      dropoff: RequestLocation(
        label: 'Dropoff #$_counter — Verdun',
        latitude: 33.8689 + _random.nextDouble() * 0.01,
        longitude: 35.4825 + _random.nextDouble() * 0.01,
      ),
      tier: tier,
      estimatedDistanceKm: distance,
      potentialEarnings: 2 + distance * ratePerKm,
      currency: 'USD',
      expiresAt: DateTime.now().add(_requestTtl),
      senderName: 'Test sender',
    );
  }
}

/// Static-snapshot repository that returns a fixed list of [DeliveryRequest]s
/// and never emits live pushes. Used by the `jeeb.feed` dev seam so the
/// deliveryman feed renders deterministic fixtures (screens 24-26) for capture
/// without a backend or random churn. Accept/decline are no-ops so the cards
/// stay on screen for screenshots.
class SeededRequestFeedRepository implements RequestFeedRepository {
  SeededRequestFeedRepository(this._snapshot);

  final List<DeliveryRequest> _snapshot;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<String> get cancellations => const Stream<String>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async =>
      List<DeliveryRequest>.unmodifiable(_snapshot);

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}
