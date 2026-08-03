import 'dart:async';

class OfferLifecycleEvent {
  const OfferLifecycleEvent({required this.offerId, required this.accepted});

  final String offerId;

  final bool accepted;
}

class OfferLifecycleSignals {
  final _controller = StreamController<OfferLifecycleEvent>.broadcast();

  Stream<OfferLifecycleEvent> get stream => _controller.stream;

  void signal(OfferLifecycleEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
