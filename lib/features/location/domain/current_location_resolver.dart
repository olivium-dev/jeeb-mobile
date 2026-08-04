import 'package:equatable/equatable.dart';

/// Why a one-shot device-GPS acquisition ended, for the "Current Location" option on `location-select` (JEBV4-176 / Q-060)
enum CurrentLocationOutcome {
  resolved,

  permissionDenied,

  serviceDisabled,

  failed,
}

class CurrentLocationResult extends Equatable {
  const CurrentLocationResult._(
    this.outcome, {
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  /// [latitude]/[longitude] stay POSITIONAL: existing call sites (and
  /// `location_select_cubit_test.dart:57`) construct this form positionally,
  /// so the accuracy radius joins as an optional named parameter.
  const CurrentLocationResult.resolved(
    double latitude,
    double longitude, {
    double? accuracyMeters,
  }) : this._(
          CurrentLocationOutcome.resolved,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
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

  /// Horizontal accuracy radius of the fix in metres, as reported by the OS
  /// sensor. Null when the platform did not supply one (or the outcome is not
  /// [CurrentLocationOutcome.resolved]). It is a DEVICE value — there is no
  /// backend field and no endpoint behind it.
  final double? accuracyMeters;

  @override
  List<Object?> get props => [outcome, latitude, longitude, accuracyMeters];
}

abstract class CurrentLocationResolver {
  Future<CurrentLocationResult> resolve();

  Future<void> openLocationSettings();

  Future<void> openAppSettings();
}
