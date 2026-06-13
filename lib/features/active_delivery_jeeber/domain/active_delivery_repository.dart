import 'jeeber_delivery.dart';
import 'jeeber_delivery_status.dart';

/// Domain contract for the Jeeber active-delivery data layer (T-MOB-031).
///
/// Endpoints verified against Mockoon :3055 (useMockPrefixes=false):
///   GET  /v1/deliveries/{id}              → JeeberDelivery snapshot
///   POST /v1/deliveries/{id}/transition   → {status} on 200, 422 on bad transition
abstract class ActiveDeliveryRepository {
  /// Fetch the current snapshot for [deliveryId].
  Future<JeeberDelivery> fetchDelivery(String deliveryId);

  /// Advance the delivery status from [from] to [to].
  ///
  /// Returns the updated [JeeberDeliveryStatus] on success.
  /// Throws [ActiveDeliveryException] on failure.
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  });
}

/// Typed failures for the active-delivery repository.
enum ActiveDeliveryFailure { network, invalidTransition, server, notFound }

class ActiveDeliveryException implements Exception {
  const ActiveDeliveryException(this.failure, [this.message]);

  final ActiveDeliveryFailure failure;
  final String? message;

  @override
  String toString() =>
      'ActiveDeliveryException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}
