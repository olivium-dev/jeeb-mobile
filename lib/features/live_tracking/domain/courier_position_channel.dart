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

  final double? accuracy;

  final DateTime? timestamp;

  final String? jeeberId;

  @override
  String toString() => 'CourierPositionFix($lat, $lng)';
}

abstract class CourierPositionChannel {
  Future<Stream<CourierPositionFix>?> open({required String deliveryId});
}

/// Why a live-position stream could not be opened. `open()` collapses these
/// into one null, which is why the cubit asks for the outcome instead.
enum CourierPositionOpenFailure {
  /// No descriptor, no socket URL, or the delivery has no stream at all.
  unavailable,

  /// The mint was refused (401/403).
  authRejected,

  /// Transport: offline, or the descriptor read timed out.
  transport,

  /// The socket itself refused to connect.
  connectFailed,

  /// Phoenix rejected the delivery-channel join.
  joinRejected,

  /// Transport readiness or an acknowledged channel join exceeded its deadline.
  joinTimeout,
}

class CourierPositionOpenResult {
  const CourierPositionOpenResult.opened(this.positions) : failure = null;

  const CourierPositionOpenResult.failed(this.failure) : positions = null;

  final Stream<CourierPositionFix>? positions;
  final CourierPositionOpenFailure? failure;

  bool get isOpen => positions != null;
}

/// The additive half of [CourierPositionChannel]: same work, but the caller
/// learns WHY. Detected with `channel is CourierPositionChannelOutcome`.
abstract class CourierPositionChannelOutcome {
  Future<CourierPositionOpenResult> openWithOutcome({
    required String deliveryId,
  });
}

/// Each screen owns its attempt, even when the channel service is shared.
/// Cancelling must abort both a descriptor request and a pending socket join.
class CourierPositionOpenAttempt {
  const CourierPositionOpenAttempt({
    required this.result,
    required this.cancel,
  });

  final Future<CourierPositionOpenResult> result;
  final Future<void> Function() cancel;
}

abstract class CancellableCourierPositionChannel {
  CourierPositionOpenAttempt openAttempt({required String deliveryId});
}
