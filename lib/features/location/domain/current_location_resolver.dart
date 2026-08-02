import 'package:equatable/equatable.dart';

/// Why a one-shot device-GPS acquisition ended, for the "Current Location" option on `location-select` (JEBV4-176 / Q-060)
enum CurrentLocationOutcome {
  resolved,

  permissionDenied,

  serviceDisabled,

  failed,
}

class CurrentLocationResult extends Equatable {
  const CurrentLocationResult._(this.outcome, {this.latitude, this.longitude});

  const CurrentLocationResult.resolved(double latitude, double longitude)
      : this._(
          CurrentLocationOutcome.resolved,
          latitude: latitude,
          longitude: longitude,
        );

  const CurrentLocationResult.permissionDenied()
      : this._(CurrentLocationOutcome.permissionDenied);

  const CurrentLocationResult.serviceDisabled()
      : this._(CurrentLocationOutcome.serviceDisabled);

  const CurrentLocationResult.failed()
      : this._(CurrentLocationOutcome.failed);

  final CurrentLocationOutcome outcome;
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [outcome, latitude, longitude];
}

abstract class CurrentLocationResolver {
  Future<CurrentLocationResult> resolve();

  Future<void> openLocationSettings();

  Future<void> openAppSettings();
}
