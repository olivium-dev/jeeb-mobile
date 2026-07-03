/// G4 (sprint-009): local persistence for the delivery handover code.
///
/// The offer-accept response is the ONLY wire moment the gateway hands the
/// client the `handoverCode` — the fallback `GET /v1/deliveries/{id}/otp` is an
/// SMS *trigger* that returns no code (run-23 wire evidence). If the app drops
/// the accept-time code it can never show it again, which is exactly the P0:
/// the customer reaches the door with nothing to hand over. This store keeps
/// the code on-device, keyed by delivery id, so it survives navigation AND app
/// restarts for the whole life of the delivery.
///
/// Privacy posture: the code is NOT a secret from its owner — it is the
/// customer's own hand-over credential, stored on the customer's device (same
/// trust class as the session token in SharedPreferences). It must still never
/// reach logs/diag output; `DiagRedaction` masks `handoverCode`-shaped keys.
abstract class HandoverCodeStore {
  /// Persists [code] for [deliveryId]. Overwrites any previous value. Blank
  /// codes are ignored (never stored).
  Future<void> save({required String deliveryId, required String code});

  /// Returns the stored code for [deliveryId], or null when none was ever
  /// saved (e.g. the app was reinstalled mid-delivery).
  Future<String?> read({required String deliveryId});

  /// Removes the stored code for [deliveryId] (handover completed — the code
  /// is single-use and keeping it around is pure liability).
  Future<void> clear({required String deliveryId});
}
