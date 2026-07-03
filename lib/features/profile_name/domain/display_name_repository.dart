/// Port for submitting the signed-in user's display name to the gateway.
///
/// Cycle-2 gateway (a99c66a) fixed the jeeberName pipeline server-side: the
/// users projection preserves learned names, mirrors `PUT /api/User/profile`
/// `username`, and passively hydrates from user-management on
/// `GET /v1/users/me`. This port is the CLIENT half of that fix — until now
/// nothing in the app ever submitted a name, so OTP-minted accounts kept a
/// blank/synthetic `username` and receipts/chat/pushes could never greet
/// "Ahmad" (the cycle-1 greeting suppression only hides that symptom).
abstract class DisplayNameRepository {
  /// Submits [name] as the user's display name (`username` on the gateway
  /// profile). Throws [DisplayNameRepositoryException] on failure.
  Future<void> submitDisplayName(String name);
}

/// Failure classes for a display-name submit, mirroring the sibling
/// repository ports (e.g. `CustomerProfileFailure`).
enum DisplayNameFailure { network, unauthorized, unknown }

/// Typed exception thrown by [DisplayNameRepository.submitDisplayName].
class DisplayNameRepositoryException implements Exception {
  const DisplayNameRepositoryException(this.failure, [this.message]);

  final DisplayNameFailure failure;
  final String? message;

  @override
  String toString() =>
      'DisplayNameRepositoryException(${failure.name}${message == null ? '' : ': $message'})';
}
