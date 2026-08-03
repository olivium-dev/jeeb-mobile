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
