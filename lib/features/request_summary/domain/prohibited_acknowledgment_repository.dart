class ProhibitedAcknowledgmentRepository {
  const ProhibitedAcknowledgmentRepository();

  Future<bool> hasAcknowledged(String requestId) async => false;
  Future<void> markAcknowledged(String requestId) async {}
}
