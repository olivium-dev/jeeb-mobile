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

  otpCodeRequired,
}

class ActiveDeliveryException implements Exception {
  const ActiveDeliveryException(
    this.failure, [
    this.message,
  ]) : typeSuffix = null,
       attemptsRemaining = null,
       escalationId = null,
       lockedAt = null;

  /// The typed form: everything the screen needs to pick copy, and nothing
  /// the gateway wrote in prose.
  const ActiveDeliveryException.typed(
    this.failure, {
    this.typeSuffix,
    this.attemptsRemaining,
    this.escalationId,
    this.lockedAt,
  }) : message = null;

  final ActiveDeliveryFailure failure;

  /// Legacy prose slot. Never fed from the wire and never rendered.
  final String? message;

  /// RFC 7807 `type` last segment, for a per-reason line.
  final String? typeSuffix;

  final int? attemptsRemaining;
  final String? escalationId;
  final DateTime? lockedAt;

  @override
  String toString() =>
      'ActiveDeliveryException(${failure.name}'
      '${typeSuffix == null ? '' : ', type: $typeSuffix'})';
}
