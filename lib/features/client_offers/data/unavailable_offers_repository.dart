import '../domain/offers_repository.dart';

/// Missing wiring cannot accept an offer or manufacture an offers snapshot.
class UnavailableOffersRepository extends OffersRepository {
  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async =>
      throw const OffersRepositoryException(OffersFailure.unknown);

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async => throw const OffersRepositoryException(OffersFailure.unknown);
}
