import 'dart:async';
import 'dart:math' as math;

import 'request_feed_models.dart';




enum RequestActionOutcome {
  accepted,
  declined,
  alreadyTaken,
  expired,
  networkError,
}




enum FeedTransport {
  webSocket,

  
  
  polling,
}




class FeedTransportUpdate {
  const FeedTransportUpdate(this.transport);
  final FeedTransport transport;
}















abstract class RequestFeedRepository {
  
  
  
  Stream<DeliveryRequest> get requests;

  
  
  
  Stream<FeedTransportUpdate> get transport;

  
  
  
  Future<List<DeliveryRequest>> refresh();

  
  
  
  Future<RequestActionOutcome> accept(String id);

  
  
  Future<RequestActionOutcome> decline(String id);

  
  
  Future<void> dispose();
}






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
  final StreamController<FeedTransportUpdate> _transport =
      StreamController<FeedTransportUpdate>.broadcast();

  Timer? _emitter;
  int _counter = 0;

  @override
  Stream<DeliveryRequest> get requests => _requests.stream;

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






class SeededRequestFeedRepository implements RequestFeedRepository {
  SeededRequestFeedRepository(this._snapshot);

  final List<DeliveryRequest> _snapshot;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

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
