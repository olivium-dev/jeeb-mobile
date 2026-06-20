import 'dart:typed_data';

import 'jeeber_delivery.dart';
import 'jeeber_delivery_status.dart';

/// Domain contract for the Jeeber active-delivery data layer (T-MOB-031,
/// extended by JM-051).
///
/// Endpoints (real mock gateway contract; `MockGatewayClient` rewrites `/v1/...`
/// to the `:4010` service prefix):
///   GET  /v1/delivery/{id}              → JeeberDelivery snapshot
///   POST /v1/delivery/status/transition → updated delivery; 422 on bad transition
///   POST /v1/delivery/proof-photo       → { url, evidenceUrl, deliveryId } (D1m)
abstract class ActiveDeliveryRepository {
  /// Fetch the current snapshot for [deliveryId].
  Future<JeeberDelivery> fetchDelivery(String deliveryId);

  /// Advance the delivery status from [from] to [to], optionally stamping the
  /// proof-of-delivery [evidenceUrl] (carried on the `AtDoor → Done`
  /// transition, JM-051 / D3).
  ///
  /// Returns the updated [JeeberDeliveryStatus] on success.
  /// Throws [ActiveDeliveryException] on failure.
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  });

  /// Upload a proof-of-delivery photo (D3) to the cdn-service via the gateway
  /// and return the stable evidence URL the service minted.
  ///
  /// [bytes] are the real captured image bytes (camera/gallery via
  /// `PhotoPickerService`); [filename] names the multipart part. When [bytes]
  /// is `null` the repository degrades to the legacy filename-only JSON post
  /// (the in-memory mock seam that does not store bytes). Throws
  /// [ActiveDeliveryException] on failure.
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
    Uint8List? bytes,
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
