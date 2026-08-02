import 'dart:typed_data';

import 'jeeber_delivery.dart';
import 'jeeber_delivery_status.dart';

abstract class ActiveDeliveryRepository {
  Future<JeeberDelivery> fetchDelivery(String deliveryId);

  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  });

  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  });

  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });
}

enum ActiveDeliveryFailure {
  network,
  invalidTransition,

  otpRequired,

  invalidOtp,

  otpLocked,

  badRequest,
  server,
  notFound,
}

class ActiveDeliveryException implements Exception {
  const ActiveDeliveryException(this.failure, [this.message]);

  final ActiveDeliveryFailure failure;
  final String? message;

  @override
  String toString() =>
      'ActiveDeliveryException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}
