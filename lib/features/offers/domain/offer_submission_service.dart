/// Stub created by sanity-build pass (2026-05-17). Real impl is the POST
/// /api/offers RPC against jeeb-gateway.
class OfferSubmissionService {
  const OfferSubmissionService();

  Future<void> submit({
    required String requestId,
    required int amountCents,
    required Duration estimatedArrival,
  }) async {}
}
