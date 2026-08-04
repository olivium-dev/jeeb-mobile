abstract class RoleSwitchRepository {
  Future<RoleSwitchResult> switchRole(String role);
}

enum RoleSwitchResult {
  success,

  kycGated,
}

class RoleSwitchException implements Exception {
  const RoleSwitchException(this.message);
  final String message;

  @override
  String toString() => 'RoleSwitchException: $message';
}
