
import 'waiting_request.dart';

enum WaitingFailure {
  network,

  notFound,

  unknown,

  contractViolation,
}

abstract class WaitingRepository {
  Future<WaitingRequest> fetchWaiting(String requestId);

  Future<WaitingRequest> fetchRequest(String requestId);

  Future<int> fetchOfferCount(String requestId, {int fallback = 0});
}

class WaitingException implements Exception {
  const WaitingException(this.failure, [this.message]);

  final WaitingFailure failure;
  final String? message;

  @override
  String toString() => 'WaitingException($failure, $message)';
}
