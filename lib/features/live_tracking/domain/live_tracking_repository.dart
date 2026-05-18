import 'delivery_tracking_info.dart';

abstract class LiveTrackingRepository {
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  });
}

class LiveTrackingException implements Exception {
  const LiveTrackingException(this.kind, [this.cause]);

  final LiveTrackingErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'LiveTrackingException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum LiveTrackingErrorKind { network, server, parse }
