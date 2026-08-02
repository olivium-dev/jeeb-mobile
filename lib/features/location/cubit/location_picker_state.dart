import 'package:equatable/equatable.dart';

import '../data/location_repository.dart';

enum LocationPickerStep { pickup, dropoff, done }

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

  final LocationPoint? pickup;

  final LocationPoint? dropoff;

  final LocationPoint? draftSelection;

  final String searchQuery;
  final List<LocationPoint> searchResults;

  final bool isLocatingGps;

  final bool isResolvingAddress;

  final bool isSearching;

  final bool isSaving;

  final LocationPickerError? error;

  bool get canConfirm => draftSelection != null && !isSaving;

  bool get isComplete =>
      step == LocationPickerStep.done && pickup != null && dropoff != null;

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
