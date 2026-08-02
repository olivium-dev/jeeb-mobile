import '../entities/availability_status.dart';

abstract class AvailabilityGateway {
  Future<AvailabilityStatus> fetch();

  Future<AvailabilityStatus> toggle({required bool goOnline});
}

class AvailabilityGatewayException implements Exception {
  const AvailabilityGatewayException(this.message);
  final String message;

  @override
  String toString() => 'AvailabilityGatewayException: $message';
}

class InMemoryAvailabilityGateway implements AvailabilityGateway {
  InMemoryAvailabilityGateway({
    AvailabilityStatus initial = AvailabilityStatus.initial,
    this.respondWithError = false,
  }) : _current = initial;

  AvailabilityStatus _current;

  bool respondWithError;

  void setError(bool value) {
    respondWithError = value;
  }

  void setActiveDeliveryCount(int count) {
    _current = _current.copyWith(activeDeliveryCount: count);
  }

  @override
  Future<AvailabilityStatus> fetch() async {
    if (respondWithError) {
      throw const AvailabilityGatewayException('fetch failed');
    }
    return _current;
  }

  @override
  Future<AvailabilityStatus> toggle({required bool goOnline}) async {
    if (respondWithError) {
      throw const AvailabilityGatewayException('toggle failed');
    }
    _current = _current.copyWith(
      state:
          goOnline ? AvailabilityState.online : AvailabilityState.offline,
      lastActivityAt: DateTime.now(),
    );
    return _current;
  }
}
