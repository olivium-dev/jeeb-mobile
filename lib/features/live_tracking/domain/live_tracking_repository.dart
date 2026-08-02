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

  notFound,
  parse,
}
