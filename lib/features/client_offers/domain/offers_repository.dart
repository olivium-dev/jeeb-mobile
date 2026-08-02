import 'offer.dart';

enum OffersFailure {
  network,
  requestNotOpen,
  offerNotPending,

  jeeberAtCapacity,

  rateLimited,
  unknown,
}

class OfferAcceptResult {
  const OfferAcceptResult({
    this.deliveryId,
    this.conversationId,
    this.handoverCode,
  });

  final String? deliveryId;

  final String? conversationId;

  final String? handoverCode;

  static const OfferAcceptResult empty = OfferAcceptResult();
}

String? acceptResponseDeliveryId(Map<dynamic, dynamic> body) {
  String? clean(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  final explicit = clean(body['deliveryId']) ?? clean(body['delivery_id']);
  if (explicit != null) return explicit;
  final isDeliveryProjection =
      body.containsKey('clientId') || body.containsKey('client_id');
  return isDeliveryProjection ? clean(body['id']) : null;
}

class OffersSnapshot {
  const OffersSnapshot({
    required this.offers,
    required this.windowExpiresAt,
    required this.requestIsOpen,
    this.requestIsExpired = false,
  });

  final List<Offer> offers;
  final DateTime? windowExpiresAt;
  final bool requestIsOpen;
  final bool requestIsExpired;
}

abstract class OffersRepository {
  Future<OffersSnapshot> fetchOffers(String requestId);

  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  });
}

class OffersRepositoryException implements Exception {
  const OffersRepositoryException(
    this.failure, [
    this.message,
    this.retryAfter,
  ]);
  final OffersFailure failure;
  final String? message;

  final Duration? retryAfter;

  @override
  String toString() =>
      'OffersRepositoryException($failure, $message, retryAfter: $retryAfter)';
}
