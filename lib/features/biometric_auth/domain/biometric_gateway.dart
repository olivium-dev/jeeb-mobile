/// Stub created by sanity-build pass (2026-05-17).
///
/// Real implementation lives behind T-mobile-005. Sanity build needs only the
/// type shape so [BiometricLockCubit] and [JeebApp] can wire a const default.
abstract class BiometricGateway {
  Future<bool> isAvailable();
  Future<bool> authenticate({required String reason});
}

class UnavailableBiometricGateway implements BiometricGateway {
  const UnavailableBiometricGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
