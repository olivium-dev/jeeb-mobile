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
    this.error,
  });

  final LocationSelectStatus status;
  final List<SavedLocation> savedAddresses;

  /// The kind of option currently selected.
  final LocationChoiceKind choiceKind;

  /// Set only when [choiceKind] is [LocationChoiceKind.saved].
  final String? selectedSavedId;

  /// Non-null only when [status] is [LocationSelectStatus.failed].
  final LocationSelectFailure? error;

  bool get hasSavedAddresses => savedAddresses.isNotEmpty;

  /// A location is always confirmable: "Current Location" is the safe default,
  /// so the Confirm CTA is reachable on first paint (JM-024 AC4). The selection
  /// only changes WHICH location is forwarded to order-chat.
  ///
  /// The saved-addresses fetch (`GET /users/:id/saved-locations`) can fail
  /// independently — the LIVE gateway 404s a customer with no saved addresses.
  /// That failure must only degrade the saved-addresses sub-list; it must NOT
  /// block confirming Current Location / a freshly-pinned point. Gating solely
  /// on `loaded` violated the AC4 invariant above and dead-ended order creation
  /// (tier → location → [BLOCKED]). So `failed` stays confirmable UNLESS the
  /// user explicitly chose a saved address (which by definition never loaded).
  bool get canConfirm =>
      status == LocationSelectStatus.loaded ||
      (status == LocationSelectStatus.failed &&
          choiceKind != LocationChoiceKind.saved);

  bool isSavedSelected(String id) =>
      choiceKind == LocationChoiceKind.saved && selectedSavedId == id;

  LocationSelectState copyWith({
    LocationSelectStatus? status,
    List<SavedLocation>? savedAddresses,
    LocationChoiceKind? choiceKind,
    String? selectedSavedId,
    bool clearSelectedSaved = false,
    LocationSelectFailure? error,
    bool clearError = false,
  }) {
    return LocationSelectState(
      status: status ?? this.status,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      choiceKind: choiceKind ?? this.choiceKind,
      selectedSavedId:
          clearSelectedSaved ? null : (selectedSavedId ?? this.selectedSavedId),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        savedAddresses,
        choiceKind,
        selectedSavedId,
        error,
      ];
}
