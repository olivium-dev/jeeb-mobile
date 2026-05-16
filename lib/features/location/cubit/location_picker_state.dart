import 'package:equatable/equatable.dart';

import '../data/location_repository.dart';

/// Which leg of the delivery the user is currently picking. The flow is
/// strictly pickup → dropoff; back-navigation rewinds from dropoff to pickup.
enum LocationPickerStep { pickup, dropoff, done }

/// Transient error surfaces produced by the cubit. One-shot — the view
/// renders matching copy and calls
/// [LocationPickerCubit.acknowledgeError] so the same error isn't replayed
/// on the next rebuild.
enum LocationPickerError {
  gpsPermissionDenied,
  gpsUnavailable,
  searchFailed,
  geocodingFailed,
  saveFailed,
}

class LocationPickerState extends Equatable {
  const LocationPickerState({
    this.step = LocationPickerStep.pickup,
    this.pickup,
    this.dropoff,
    this.draftSelection,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isLocatingGps = false,
    this.isResolvingAddress = false,
    this.isSearching = false,
    this.isSaving = false,
    this.error,
  });

  final LocationPickerStep step;

  /// Locked-in pickup choice. Becomes non-null once the user confirms the
  /// pickup step and stays sticky as they pick the dropoff.
  final LocationPoint? pickup;

  /// Locked-in dropoff choice. Becomes non-null once the user confirms the
  /// dropoff step.
  final LocationPoint? dropoff;

  /// What the map pin / preview is currently centred on for the active step.
  /// Distinct from [pickup]/[dropoff] so the user can drag without
  /// overwriting the prior committed value until they explicitly confirm.
  final LocationPoint? draftSelection;

  final String searchQuery;
  final List<LocationPoint> searchResults;

  /// True while [LocationPickerCubit.detectCurrentLocation] is in flight.
  final bool isLocatingGps;

  /// True while reverse-geocoding a freshly dragged pin position.
  final bool isResolvingAddress;

  /// True while [LocationPickerCubit.searchAddress] is in flight.
  final bool isSearching;

  /// True while [LocationPickerCubit.savePair] is in flight.
  final bool isSaving;

  final LocationPickerError? error;

  bool get canConfirm => draftSelection != null && !isSaving;

  /// True once both pickup and dropoff are committed and saved — the host
  /// listens for this to pop back to the request-summary screen.
  bool get isComplete =>
      step == LocationPickerStep.done && pickup != null && dropoff != null;

  /// Convenience for the screen layer: the canonical "where are we now"
  /// label, used for the section title.
  LocationPickerStep get activeStep => step;

  LocationPickerState copyWith({
    LocationPickerStep? step,
    LocationPoint? pickup,
    bool clearPickup = false,
    LocationPoint? dropoff,
    bool clearDropoff = false,
    LocationPoint? draftSelection,
    bool clearDraftSelection = false,
    String? searchQuery,
    List<LocationPoint>? searchResults,
    bool? isLocatingGps,
    bool? isResolvingAddress,
    bool? isSearching,
    bool? isSaving,
    LocationPickerError? error,
    bool clearError = false,
  }) {
    return LocationPickerState(
      step: step ?? this.step,
      pickup: clearPickup ? null : (pickup ?? this.pickup),
      dropoff: clearDropoff ? null : (dropoff ?? this.dropoff),
      draftSelection: clearDraftSelection
          ? null
          : (draftSelection ?? this.draftSelection),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isLocatingGps: isLocatingGps ?? this.isLocatingGps,
      isResolvingAddress: isResolvingAddress ?? this.isResolvingAddress,
      isSearching: isSearching ?? this.isSearching,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        step,
        pickup,
        dropoff,
        draftSelection,
        searchQuery,
        searchResults,
        isLocatingGps,
        isResolvingAddress,
        isSearching,
        isSaving,
        error,
      ];
}
