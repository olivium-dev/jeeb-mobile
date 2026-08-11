import '../entities/availability_status.dart';

/// Whether the go-online PATCH carried coordinates, and why not when it did not.
enum GoOnlineLocationOutcome { attached, permissionDenied, fixFailed, notApplicable }

class AvailabilityToggleResult {
  const AvailabilityToggleResult({
    required this.status,
    this.location = GoOnlineLocationOutcome.notApplicable,
  });

  final AvailabilityStatus status;

  final GoOnlineLocationOutcome location;
}

abstract class AvailabilityGateway {
  Future<AvailabilityStatus> fetch();

  Future<AvailabilityToggleResult> toggle({required bool goOnline});

  /// Re-stamps server-side last_location without changing online state.
  Future<GoOnlineLocationOutcome> refreshLocation();
}

class AvailabilityGatewayException implements Exception {
  const AvailabilityGatewayException(this.message);
  final String message;

  @override
  String toString() => 'AvailabilityGatewayException: $message';
}

/// Thrown by the injected location seam when the OS refuses the fix outright.
class LocationCaptureDeniedException implements Exception {
  const LocationCaptureDeniedException();

  @override
  String toString() => 'LocationCaptureDeniedException';
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
  Future<AvailabilityToggleResult> toggle({required bool goOnline}) async {
    if (respondWithError) {
      throw const AvailabilityGatewayException('toggle failed');
    }
    _current = _current.copyWith(
      state:
          goOnline ? AvailabilityState.online : AvailabilityState.offline,
      lastActivityAt: DateTime.now(),
    );
    return AvailabilityToggleResult(
      status: _current,
      location: goOnline
          ? GoOnlineLocationOutcome.attached
          : GoOnlineLocationOutcome.notApplicable,
    );
  }

  @override
  Future<GoOnlineLocationOutcome> refreshLocation() async =>
      GoOnlineLocationOutcome.notApplicable;
}
