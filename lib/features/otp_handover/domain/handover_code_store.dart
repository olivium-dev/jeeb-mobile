/// G4 (sprint-009): local persistence for the delivery handover code.
abstract class HandoverCodeStore {
  Future<void> save({required String deliveryId, required String code});

  Future<String?> read({required String deliveryId});

  Future<void> clear({required String deliveryId});
}
