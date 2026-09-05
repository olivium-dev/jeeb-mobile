import '../../../core/network/app_failure.dart';
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

  /// Null means the count is UNKNOWN — never a fabricated zero.
  Future<int?> fetchOfferCount(String requestId);
}

class WaitingException implements Exception {
  const WaitingException(this.failure, [this.message, this.classifiedFailure]);

  final WaitingFailure failure;
  final String? message;

  /// The transport's own classification, when it had one. The 4-value
  /// [WaitingFailure] enum cannot round-trip 401/403/410/5xx.
  final AppFailure? classifiedFailure;

  /// The classified failure: the transport's when present, else derived from
  /// [failure]. Single source for every consumer.
  AppFailure get appFailure =>
      classifiedFailure ??
      switch (failure) {
        WaitingFailure.network => const NetworkFailure(),
        WaitingFailure.notFound => NotFoundFailure(cause: this),
        WaitingFailure.contractViolation =>
          UnknownFailure(cause: this, parse: true),
        WaitingFailure.unknown => UnknownFailure(cause: this),
      };

  @override
  String toString() => 'WaitingException($failure, $message)';
}
