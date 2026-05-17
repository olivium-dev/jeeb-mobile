import '../entities/availability_status.dart';

/// Wire protocol contract for the Jeeber availability endpoint.
///
/// In production this is a thin Dio wrapper around
/// `PUT /api/availability/toggle` on jeeb-gateway; tests inject
/// [InMemoryAvailabilityGateway].
abstract class AvailabilityGateway {
  /// Fetches the current availability snapshot at cold start.
  Future<AvailabilityStatus> fetch();

  /// Flips the Jeeber's availability state and returns the canonical
  /// post-toggle snapshot from the server (including any updated
  /// active-delivery count). Throws [AvailabilityGatewayException] on
  /// network/transport errors so the cubit can surface a retry.
  Future<AvailabilityStatus> toggle({required bool goOnline});
}

/// Thrown by [AvailabilityGateway] implementations when the network call
/// fails. The cubit catches this and surfaces a non-fatal banner.
class AvailabilityGatewayException implements Exception {
  const AvailabilityGatewayException(this.message);
  final String message;

  @override
  String toString() => 'AvailabilityGatewayException: $message';
}

/// In-memory gateway used during the UI-only milestone. Scripted via
/// [respondWithError] so widget tests can drive the error branch without
/// stubbing.
class InMemoryAvailabilityGateway implements AvailabilityGateway {
  InMemoryAvailabilityGateway({
    AvailabilityStatus initial = AvailabilityStatus.initial,
    this.respondWithError = false,
  }) : _current = initial;

  AvailabilityStatus _current;

  /// When `true`, both [fetch] and [toggle] throw
  /// [AvailabilityGatewayException] so the cubit can be put through its
  /// error path. Toggle at runtime via [setError].
  bool respondWithError;

  /// Test hook that lets a fixture flip the error mode mid-run without
  /// rebuilding the gateway.
  void setError(bool value) {
    respondWithError = value;
  }

  /// Test hook that lets a fixture mutate the active-delivery count so
  /// the screen renders the "N active deliveries" line without going
  /// through a real matching flow.
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
