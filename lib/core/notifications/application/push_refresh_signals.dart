import 'dart:async';

/// App-wide broadcast bus for "a push says an order's status changed — refetch".
///
/// Decouples the push stack (app layer — [PushNotificationHandler]) from the
/// surfaces that must re-pull on a status change (customer home / live
/// tracking), which live in the feature layer and must never import the push
/// stack. The handler is the sole publisher; interested cubits subscribe.
///
/// Registered as a lazy singleton in the DI container so both sides resolve the
/// SAME instance without a widget-tree provider dependency.
class PushRefreshSignals {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Fires (payload-less) whenever a foreground push indicates a delivery/order
  /// status change. Subscribers just re-pull their own snapshot — the signal
  /// carries no id because each subscriber already knows what it renders.
  Stream<void> get stream => _controller.stream;

  /// Publish a status-change signal. No-op after [dispose].
  void signalStatusChange() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
