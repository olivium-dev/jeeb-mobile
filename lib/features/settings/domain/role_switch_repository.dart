/// T-MOB-028: Abstract contract for the role-switch endpoint.
///
/// The backend endpoint is `POST /v1/users/me/role/switch` with body
/// `{"role": "client" | "jeeber"}`. Returns 200 on success or 403 when
/// the KYC approval gate is not satisfied.
abstract class RoleSwitchRepository {
  /// Request a role switch to [role]. Throws [RoleSwitchException] on
  /// network errors. Returns [RoleSwitchResult.kycGated] on HTTP 403.
  Future<RoleSwitchResult> switchRole(String role);
}

/// Outcome of a [RoleSwitchRepository.switchRole] call.
enum RoleSwitchResult {
  /// Switch accepted by the gateway; caller should update local role state.
  success,

  /// Gateway returned 403 — the user's KYC has not been approved.
  kycGated,
}

/// Thrown by [RoleSwitchRepository] implementations on network / transport
/// failures. The cubit catches this and surfaces an error snackbar.
class RoleSwitchException implements Exception {
  const RoleSwitchException(this.message);
  final String message;

  @override
  String toString() => 'RoleSwitchException: $message';
}
