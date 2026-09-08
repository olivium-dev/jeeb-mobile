import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';

/// Cold-load lifecycle for the location-select screen. `empty` (no saved
/// addresses) is a sub-state of [loaded], not a 5th status (40_GUARDRAILS_ARCH
/// §3) — the screen always renders the Current/New affordances regardless.
enum LocationSelectStatus { initial, loading, loaded, failed }

/// Which option the customer currently has selected on `location-select`.
/// `current` is the default (pin to current GPS / the pickup origin); a saved
/// address is selected by its [SavedLocation.id]; a freshly-pinned point from
/// the map step is held transiently as [pinned].
enum LocationChoiceKind { current, saved, pinned }

/// Lifecycle of the one-shot device-GPS acquisition for the "Current Location"
/// option (JEBV4-176 / Q-060). This is what REPLACED the silent Beirut
/// fallback: instead of pretending `33.8886, 35.4955` is the customer's
/// location, the screen resolves a REAL fix and, when it cannot, surfaces the
/// honest recovery state below (which gates the Confirm CTA).
enum CurrentGpsStatus {
  /// Not attempted yet (e.g. no resolver wired in an isolated dev/test host).
  idle,

  /// Acquiring a fix (permission prompt / reading the sensor).
  resolving,

  /// A real device coordinate is held ([LocationSelectState.gpsLat] /
  /// [LocationSelectState.gpsLng] are non-null). Only in this state may a
  /// current-location request be confirmed.
  resolved,

  /// The app's location permission is denied. Recovery: open app settings.
  permissionDenied,

  /// The device's location services (OS GPS toggle) are off. Recovery: open
  /// location settings.
  serviceDisabled,

  /// The platform failed to produce a fix. Recovery: retry.
  failed,
}

class LocationSelectState extends Equatable {
  const LocationSelectState({
    this.status = LocationSelectStatus.initial,
    this.savedAddresses = const [],
    this.choiceKind = LocationChoiceKind.current,
    this.selectedSavedId,
    this.pinnedLat,
    this.pinnedLng,
    this.pinnedAddress,
    this.currentGpsStatus = CurrentGpsStatus.idle,
    this.gpsLat,
    this.gpsLng,
    this.gpsAccuracyMeters,
    this.error,
    this.appFailure,
    this.refreshError,
  });

  final LocationSelectStatus status;
  final List<SavedLocation> savedAddresses;

  /// The kind of option currently selected.
  final LocationChoiceKind choiceKind;

  /// Set only when [choiceKind] is [LocationChoiceKind.saved].
  final String? selectedSavedId;

  /// The freshly-pinned map coordinate (capture-location -> markPinned), set
  /// only when [choiceKind] is [LocationChoiceKind.pinned]. Threaded into the
  /// create draft as the REAL pickup coordinate (S0-REQ-03); null otherwise.
  final double? pinnedLat;
  final double? pinnedLng;

  /// Best-effort OS-resolved label for [pinnedLat]/[pinnedLng]. Null means the
  /// request uses its existing coordinate-format address fallback.
  final String? pinnedAddress;

  /// Lifecycle of the device-GPS acquisition for the "Current Location" option.
  final CurrentGpsStatus currentGpsStatus;

  /// The REAL device coordinate for the "Current Location" option, set only
  /// when [currentGpsStatus] is [CurrentGpsStatus.resolved]. Threaded into the
  /// create draft as the pickup coordinate (JEBV4-176) — there is no Beirut
  /// fallback: a null here keeps the current-location choice un-confirmable.
  final double? gpsLat;
  final double? gpsLng;

  /// Horizontal accuracy radius (metres) of the device fix above, when the OS
  /// reported one. Display-only — it tells the customer HOW precise the pin is
  /// and never gates [canConfirm] (a coarse fix is still a real fix). Cleared
  /// by `clearGps` alongside the coordinate.
  final double? gpsAccuracyMeters;

  /// Non-null only when [status] is [LocationSelectStatus.failed].
  final LocationSelectFailure? error;

  /// The classified cold-load failure. [error] stays for the fixtures.
  final AppFailure? appFailure;

  /// A refresh failed while rows are on screen: the note goes ABOVE the list
  /// and [status] stays `loaded`.
  final AppFailure? refreshError;

  bool get hasSavedAddresses => savedAddresses.isNotEmpty;

  /// True once the device GPS has yielded a real fix for the current option.
  bool get hasCurrentGps =>
      currentGpsStatus == CurrentGpsStatus.resolved &&
      gpsLat != null &&
      gpsLng != null;

  /// Whether the customer has a confirmable pickup selection.
  ///
  /// The saved-addresses fetch (`GET /api/users/me/saved-locations`) can fail
  /// on a GENUINE transport error (offline / 5xx). That failure must only
  /// degrade the saved-addresses sub-list; it must NOT block confirming a
  /// freshly-pinned point — gating solely on `loaded` would dead-end order
  /// creation on any network blip. So `failed` stays confirmable UNLESS the
  /// user explicitly chose a saved address (which by definition never loaded).
  ///
  /// JEBV4-176 (Q-060): the "Current Location" option is NO LONGER
  /// unconditionally confirmable. It used to fall through to a hardcoded Beirut
  /// coordinate (`33.8886, 35.4955`), so a customer with GPS off / permission
  /// denied silently created a request pinned to downtown Beirut. Now the
  /// current option is confirmable ONLY once a REAL device fix has resolved
  /// ([hasCurrentGps]); until then the screen shows the GPS-recovery UI and
  /// Confirm stays disabled. A saved address or a map-pinned point (both carry
  /// real coordinates) remain confirmable as before.
  ///
  /// NOTE: an EMPTY customer is NOT a failure. The live gateway returns
  /// `200 {items:[]}` for a customer with no saved addresses, so the screen
  /// reaches `loaded` with an empty list.
  bool get canConfirm {
    final baseLoaded = status == LocationSelectStatus.loaded ||
        (status == LocationSelectStatus.failed &&
            choiceKind != LocationChoiceKind.saved);
    if (!baseLoaded) return false;
    switch (choiceKind) {
      case LocationChoiceKind.current:
        return hasCurrentGps;
      case LocationChoiceKind.pinned:
        // JEBV4-176: a pinned choice is confirmable ONLY once a REAL picked
        // coordinate was captured. The capture-location placeholder (no live
        // map yet, B-23 owner-gated) pops WITHOUT a coordinate rather than
        // fabricate the old Beirut default, so `markPinned(null, null)` leaves
        // these null and Confirm stays disabled — no fabricated pickup can be
        // created. A live map writes real pinnedLat/Lng and this re-enables.
        return pinnedLat != null && pinnedLng != null;
      case LocationChoiceKind.saved:
        return true;
    }
  }

  bool isSavedSelected(String id) =>
      choiceKind == LocationChoiceKind.saved && selectedSavedId == id;

  LocationSelectState copyWith({
    LocationSelectStatus? status,
    List<SavedLocation>? savedAddresses,
    LocationChoiceKind? choiceKind,
    String? selectedSavedId,
    bool clearSelectedSaved = false,
    double? pinnedLat,
    double? pinnedLng,
    String? pinnedAddress,
    bool clearPinned = false,
    bool clearPinnedAddress = false,
    CurrentGpsStatus? currentGpsStatus,
    double? gpsLat,
    double? gpsLng,
    double? gpsAccuracyMeters,
    bool clearGps = false,
    LocationSelectFailure? error,
    bool clearError = false,
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool clearRefreshError = false,
  }) {
    return LocationSelectState(
      status: status ?? this.status,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      choiceKind: choiceKind ?? this.choiceKind,
      selectedSavedId:
          clearSelectedSaved ? null : (selectedSavedId ?? this.selectedSavedId),
      pinnedLat: clearPinned ? null : (pinnedLat ?? this.pinnedLat),
      pinnedLng: clearPinned ? null : (pinnedLng ?? this.pinnedLng),
      pinnedAddress: clearPinned || clearPinnedAddress
          ? null
          : (pinnedAddress ?? this.pinnedAddress),
      currentGpsStatus: currentGpsStatus ?? this.currentGpsStatus,
      gpsLat: clearGps ? null : (gpsLat ?? this.gpsLat),
      gpsLng: clearGps ? null : (gpsLng ?? this.gpsLng),
      gpsAccuracyMeters:
          clearGps ? null : (gpsAccuracyMeters ?? this.gpsAccuracyMeters),
      error: clearError ? null : (error ?? this.error),
      appFailure: clearError ? null : (appFailure ?? this.appFailure),
      refreshError:
          clearRefreshError ? null : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        savedAddresses,
        choiceKind,
        selectedSavedId,
        pinnedLat,
        pinnedLng,
        pinnedAddress,
        currentGpsStatus,
        gpsLat,
        gpsLng,
        appFailure,
        refreshError,
        gpsAccuracyMeters,
        error,
      ];
}
