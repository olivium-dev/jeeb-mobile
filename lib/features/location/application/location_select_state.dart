import 'package:equatable/equatable.dart';

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

class LocationSelectState extends Equatable {
  const LocationSelectState({
    this.status = LocationSelectStatus.initial,
    this.savedAddresses = const [],
    this.choiceKind = LocationChoiceKind.current,
    this.selectedSavedId,
    this.pinnedLat,
    this.pinnedLng,
    this.error,
  });

  final LocationSelectStatus status;
  final List<SavedLocation> savedAddresses;

  /// The kind of option currently selected.
  final LocationChoiceKind choiceKind;

  /// Set only when [choiceKind] is [LocationChoiceKind.saved].
  final String? selectedSavedId;

  /// The REAL coordinate the customer dropped on the map-pin step
  /// (capture-location), captured when [choiceKind] is
  /// [LocationChoiceKind.pinned]. S0-REQ-03: before this existed, `markPinned`
  /// recorded only the choice KIND and the pinned lat/lng was thrown away at
  /// the call site, so the compose step had nothing to read and defaulted the
  /// pickup to the Beirut constant — the user's pin silently vanished. Null
  /// when no real point was captured (e.g. the GPS-less dev build, or a
  /// `current`/`saved` choice), in which case the compose step keeps its
  /// non-null Beirut fallback to satisfy the gateway's required-coords contract.
  final double? pinnedLat;
  final double? pinnedLng;

  /// Non-null only when [status] is [LocationSelectStatus.failed].
  final LocationSelectFailure? error;

  bool get hasSavedAddresses => savedAddresses.isNotEmpty;

  /// True once the customer has actually PICKED a location to deliver to.
  /// "Current Location" is the safe default selection ([LocationChoiceKind.current]),
  /// so a valid pickup+dropoff origin exists on first paint (JM-024 AC4); a
  /// freshly-pinned point ([LocationChoiceKind.pinned]) also counts, and a saved
  /// address counts only once its [selectedSavedId] is set. This is the SINGLE
  /// confirmed point the compose step seeds into both `pickupLocation` and
  /// `dropoffLocation` (see ComposeRequestController._buildDraft).
  bool get hasPickedLocation =>
      choiceKind == LocationChoiceKind.current ||
      choiceKind == LocationChoiceKind.pinned ||
      (choiceKind == LocationChoiceKind.saved && selectedSavedId != null);

  /// The Confirm CTA's enablement depends ONLY on the customer having picked a
  /// pickup+dropoff location ([hasPickedLocation]) — NOT on the saved-locations
  /// fetch succeeding.
  ///
  /// The saved-locations read (`GET /api/users/me/saved-locations`) is a pure
  /// convenience: it can 404, error, or come back empty without blocking a
  /// create. Gating Confirm on `status == loaded` was the defect — a failed
  /// fetch ([LocationSelectStatus.failed]) left the CTA permanently disabled and
  /// the customer could never create a request even though "Current Location"
  /// is a valid default pick. So we deliberately do NOT require `loaded` here;
  /// the screen's footer still hides itself during the cold-load spinner
  /// (initial/loading), and on `failed` it shows the retry banner while the
  /// Confirm CTA stays enabled.
  bool get canConfirm => hasPickedLocation;

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
    bool clearPinned = false,
    LocationSelectFailure? error,
    bool clearError = false,
  }) {
    return LocationSelectState(
      status: status ?? this.status,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      choiceKind: choiceKind ?? this.choiceKind,
      selectedSavedId:
          clearSelectedSaved ? null : (selectedSavedId ?? this.selectedSavedId),
      pinnedLat: clearPinned ? null : (pinnedLat ?? this.pinnedLat),
      pinnedLng: clearPinned ? null : (pinnedLng ?? this.pinnedLng),
      error: clearError ? null : (error ?? this.error),
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
        error,
      ];
}
