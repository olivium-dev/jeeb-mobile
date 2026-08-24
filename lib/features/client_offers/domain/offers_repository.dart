import 'offer.dart';

enum OffersFailure {
  network,
  requestNotOpen,
  offerNotPending,

  jeeberAtCapacity,

  /// Wallet-guard accept-path failures (CONTRACT E3/E4/E5). The guard could not
  /// resolve a holder, the offer fee, or the jeeber's outstanding exposure.
  holderUnresolved,
  feeUnresolvable,
  exposureUnresolvable,

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
    this.requestTitle,
  });

  final List<Offer> offers;
  final DateTime? windowExpiresAt;
  final bool requestIsOpen;
  final bool requestIsExpired;

  /// The request's own item title, read off the `/v1/requests/:id` row the
  /// snapshot already fetches. Drives the top bar's subtitle line on the
  /// offer-review screen. Nullable and OPTIONAL by contract: the endpoint does
  /// not carry a destination address, and a gateway that omits the title must
  /// leave the subtitle unrendered rather than get a placeholder.
  final String? requestTitle;
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
