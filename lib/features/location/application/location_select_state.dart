import 'package:equatable/equatable.dart';

import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';

enum LocationSelectStatus { initial, loading, loaded, failed }

enum LocationChoiceKind { current, saved, pinned }

enum CurrentGpsStatus {
  idle,

  resolving,

  resolved,

  permissionDenied,

  serviceDisabled,

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
    this.currentGpsStatus = CurrentGpsStatus.idle,
    this.gpsLat,
    this.gpsLng,
    this.error,
  });

  final LocationSelectStatus status;
  final List<SavedLocation> savedAddresses;

  final LocationChoiceKind choiceKind;

  final String? selectedSavedId;

  final double? pinnedLat;
  final double? pinnedLng;

  final CurrentGpsStatus currentGpsStatus;

  final double? gpsLat;
  final double? gpsLng;

  final LocationSelectFailure? error;

  bool get hasSavedAddresses => savedAddresses.isNotEmpty;

  bool get hasCurrentGps =>
      currentGpsStatus == CurrentGpsStatus.resolved &&
      gpsLat != null &&
      gpsLng != null;

  bool get canConfirm {
    final baseLoaded = status == LocationSelectStatus.loaded ||
        (status == LocationSelectStatus.failed &&
            choiceKind != LocationChoiceKind.saved);
    if (!baseLoaded) return false;
    switch (choiceKind) {
      case LocationChoiceKind.current:
        return hasCurrentGps;
      case LocationChoiceKind.pinned:
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
    bool clearPinned = false,
    CurrentGpsStatus? currentGpsStatus,
    double? gpsLat,
    double? gpsLng,
    bool clearGps = false,
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
      currentGpsStatus: currentGpsStatus ?? this.currentGpsStatus,
      gpsLat: clearGps ? null : (gpsLat ?? this.gpsLat),
      gpsLng: clearGps ? null : (gpsLng ?? this.gpsLng),
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
        currentGpsStatus,
        gpsLat,
        gpsLng,
        error,
      ];
}
