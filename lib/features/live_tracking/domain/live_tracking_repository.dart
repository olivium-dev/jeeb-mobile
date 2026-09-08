import '../../../core/network/app_failure.dart';
import 'delivery_tracking_info.dart';

abstract class LiveTrackingRepository {
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  });
}

abstract class LivePositionSource {
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  });
}

class DeliveryLivePosition {
  const DeliveryLivePosition({
    this.jeeberPosition,
    this.polyline = const [],
    this.stale = false,
    this.secondsSinceUpdate,
    this.status,
  });

  final GpsPoint? jeeberPosition;
  final List<GpsPoint> polyline;

  final bool stale;

  final double? secondsSinceUpdate;

  final PositionFreshness? status;

  bool get isEmpty => jeeberPosition == null && polyline.isEmpty;

  bool get isNothingToSay => isEmpty && !(status?.isLost ?? false);
}

class LiveTrackingException implements Exception {
  const LiveTrackingException(this.kind, [this.cause, this.appFailure]);

  final LiveTrackingErrorKind kind;
  final Object? cause;

  /// The classified failure, so the cubit renders shared copy without
  /// re-deriving it from [kind].
  final AppFailure? appFailure;

  @override
  String toString() => 'LiveTrackingException(${kind.name})';
}

enum LiveTrackingErrorKind {
  network,
  server,

  notFound,
  parse,

  unauthorized,
  forbidden,
  rateLimited,
}
