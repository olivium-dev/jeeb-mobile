import 'offer.dart';

/// Classified failure surfaces the cubit translates into copy. Mirrors the
/// gateway's error envelope so the UI never has to introspect raw Dio types.
enum OffersFailure {
  network,
  requestNotOpen,
  offerNotPending,
  unknown,
}

/// Snapshot of the open offer set for a single request.
///
/// [windowExpiresAt] is the server-stamped deadline after which the request
/// auto-cancels if nothing has been accepted (T-mobile-035 hard expiry). The
/// cubit drives a local countdown from this value — no clock skew correction,
/// the server is authoritative.
class OffersSnapshot {
  const OffersSnapshot({
    required this.offers,
    required this.windowExpiresAt,
    required this.requestIsOpen,
  });

  final List<Offer> offers;
  final DateTime windowExpiresAt;
  final bool requestIsOpen;
}

/// Read-side contract for the offer cards screen. Implementations call the
/// gateway in production and an in-memory fake during tests.
abstract class OffersRepository {
  /// Pulls the current open offers + window deadline for [requestId].
  Future<OffersSnapshot> fetchOffers(String requestId);

  /// Accepts a single offer. Returns `unit` on success; throws an
  /// [OffersRepositoryException] tagged with the canonical [OffersFailure].
  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
  });
}

/// Typed exception the repository raises so the cubit can map cleanly without
/// peeking at the underlying transport.
class OffersRepositoryException implements Exception {
  const OffersRepositoryException(this.failure, [this.message]);
  final OffersFailure failure;
  final String? message;

  @override
  String toString() => 'OffersRepositoryException($failure, $message)';
}
