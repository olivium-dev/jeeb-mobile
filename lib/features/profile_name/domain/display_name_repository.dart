/// Port for submitting authenticated user's display name to gateway.
abstract class DisplayNameRepository {
  Future<void> submitDisplayName(String name);
}

enum DisplayNameFailure { network, unauthorized, serverError, unknown }

class DisplayNameRepositoryException implements Exception {
  const DisplayNameRepositoryException(this.failure, [this.message]);

  final DisplayNameFailure failure;
  final String? message;

  @override
  String toString() =>
      'DisplayNameRepositoryException(${failure.name}${message == null ? '' : ': $message'})';
}
