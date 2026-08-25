import 'clarity_consent.dart';

abstract interface class ClarityConsentStore {
  Future<ClarityConsent> read();

  Future<bool> write(ClarityConsent consent);

  /// Removes any consent grant when the authenticated principal changes.
  Future<bool> clear();
}
