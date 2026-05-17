/// Stub created by sanity-build pass (2026-05-17). Real impl persists the
/// "user acknowledged the prohibited-items warning" flag per request.
class ProhibitedAcknowledgmentRepository {
  const ProhibitedAcknowledgmentRepository();

  Future<bool> hasAcknowledged(String requestId) async => false;
  Future<void> markAcknowledged(String requestId) async {}
}
