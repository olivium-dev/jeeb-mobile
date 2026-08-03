import 'package:equatable/equatable.dart';

/// Why a one-shot device-GPS acquisition ended, for the "Current Location"
/// option on `location-select` (JEBV4-176 / Q-060).
///
/// This REPLACES the old silent Beirut fallback (`33.8886, 35.4955`): when the
/// device cannot yield a real fix we surface WHICH honest recovery the UI must
/// offer, never a fabricated coordinate.
enum CurrentLocationOutcome {
  /// A real device fix was obtained ([CurrentLocationResult.latitude] /
  /// [CurrentLocationResult.longitude] are non-null).
  resolved,

  /// The app's location permission is denied (or was dismissed). Recovery:
  /// re-request / "open app settings".
  permissionDenied,

  /// The OS-level location services (device GPS toggle) are switched off.
  /// Recovery: "open location settings".
  serviceDisabled,

  /// The platform raised an unexpected error while acquiring the fix.
  /// Recovery: "retry".
  failed,
}

/// The result of [CurrentLocationResolver.resolve]. Coordinates are non-null
/// ONLY when [outcome] is [CurrentLocationOutcome.resolved].
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

/// Acquires the device's current GPS coordinate for the location-select
/// "Current Location" option, and exposes the OS settings deep-links the
/// GPS-recovery UI needs. Kept behind this port so the cubit and its tests
/// never import `geolocator` directly (per JEEB-BOUNDARIES §F9).
///
/// Concrete implementations:
///   * `GeolocatorCurrentLocationResolver` — production shim over
///     [GeolocatorGeocaptureGateway].
///   * a fake, used by widget/unit tests to script the outcome.
abstract class CurrentLocationResolver {
  /// One-shot: checks location services, ensures a foreground permission
  /// (prompting once if undetermined/denied), then reads a single fix. Never
  /// throws — every failure mode is mapped to a [CurrentLocationOutcome].
  Future<CurrentLocationResult> resolve();

  /// Opens the OS location-services settings page (device GPS toggle).
  Future<void> openLocationSettings();

  /// Opens this app's OS settings page (to grant the location permission).
  Future<void> openAppSettings();
}
