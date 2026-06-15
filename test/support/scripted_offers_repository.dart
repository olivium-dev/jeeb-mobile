import 'dart:async';

import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

/// Test-only repository that lets each test queue the exact snapshots the
/// cubit will see across fetch calls. Once the queue is exhausted the most
/// recent snapshot is replayed — so the cubit polling forever doesn't blow
/// up the test.
class ScriptedOffersRepository implements OffersRepository {
  ScriptedOffersRepository({
    required List<OffersSnapshot> snapshots,
    OffersFailure? acceptFailure,
    OffersFailure? fetchFailure,
  })  : _snapshots = List<OffersSnapshot>.of(snapshots),
        _acceptFailure = acceptFailure,
        _fetchFailure = fetchFailure;

  final List<OffersSnapshot> _snapshots;
  OffersFailure? _acceptFailure;
  OffersFailure? _fetchFailure;

  /// Last (acceptOffer requestId/offerId) tuple — handy for asserting the
  /// cubit forwarded the right ids.
  String? lastAcceptedRequestId;
  String? lastAcceptedOfferId;
  int acceptCalls = 0;
  int fetchCalls = 0;

  void scriptAcceptFailure(OffersFailure failure) =>
      _acceptFailure = failure;
  void scriptFetchFailure(OffersFailure failure) =>
      _fetchFailure = failure;

  void pushSnapshot(OffersSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    fetchCalls++;
    if (_fetchFailure != null) {
      final failure = _fetchFailure!;
      _fetchFailure = null;
      throw OffersRepositoryException(failure);
    }
    if (_snapshots.isEmpty) {
      throw StateError(
        'ScriptedOffersRepository ran out of snapshots — script more.',
      );
    }
    if (_snapshots.length == 1) return _snapshots.first;
    return _snapshots.removeAt(0);
  }

  /// Delivery id the next successful accept returns. Null mirrors a gateway
  /// that does not surface one.
  String? acceptDeliveryId;

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    acceptCalls++;
    lastAcceptedRequestId = requestId;
    lastAcceptedOfferId = offerId;
    if (_acceptFailure != null) {
      final failure = _acceptFailure!;
      _acceptFailure = null;
      throw OffersRepositoryException(failure);
    }
    return OfferAcceptResult(deliveryId: acceptDeliveryId);
  }
}
