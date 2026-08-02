
enum CancelRequestFailure {
  network,

  conflict,

  notFound,

  forbidden,

  unknown,
}

abstract class CancelRequestRepository {
  Future<void> cancelRequest({required String requestId});
}

class CancelRequestException implements Exception {
  const CancelRequestException(this.failure, [this.message]);

  final CancelRequestFailure failure;
  final String? message;

  @override
  String toString() => 'CancelRequestException($failure, $message)';
}
