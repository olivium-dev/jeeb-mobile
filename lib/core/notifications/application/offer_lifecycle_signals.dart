import 'dart:async';

/// One offer-lifecycle transition delivered from an `offer_accepted` /
/// `offer_lost` foreground push (sprint-009 offer-lifecycle).
class OfferLifecycleEvent {
  const OfferLifecycleEvent({required this.offerId, required this.accepted});

  /// The offer whose customer decision just landed. Flat `offerId` from the
  /// push payload.
  final String offerId;

  /// True on `offer_accepted` (row flips to "Accepted"); false on `offer_lost`
  /// (row flips to "Not selected").
  final bool accepted;
}

/// Decoupled bus from the app-layer [PushNotificationHandler] to the
/// feature-layer `SubmittedOffersCubit` (mirrors [PushRefreshSignals]).
///
/// The handler and the pending-offers cubit live in different layers and do not
/// share a widget-tree reference, so a broadcast bus registered on the DI
/// container is the seam: on an `offer_accepted` / `offer_lost` push the handler
/// emits an [OfferLifecycleEvent]; the pending-offers list subscribes, flips the
/// affected row's badge in place, and re-pulls the authoritative list so a
/// stale/removed row reconciles even if the optimistic flip misses.
class OfferLifecycleSignals {
  final _controller = StreamController<OfferLifecycleEvent>.broadcast();

  /// Broadcast stream the pending-offers cubit subscribes to.
  Stream<OfferLifecycleEvent> get stream => _controller.stream;

  /// Emit a lifecycle transition. No-op after [dispose] so a late push during
  /// teardown can't throw.
  void signal(OfferLifecycleEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
