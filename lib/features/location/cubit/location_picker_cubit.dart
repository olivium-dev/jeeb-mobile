import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/location_repository.dart';
import 'location_picker_state.dart';

/// Drives the two-step pickup → dropoff location picker.
///
/// Three external collaborators:
///   - [LocationRepository] — GPS resolve, address search, reverse geocode,
///     and the final save call against jeeb-gateway.
///   - The map widget (via the screen layer) — feeds drag updates through
///     [onPinDragged].
///   - The search bar — feeds query strings through [searchAddress] (debounced
///     by the cubit, not the widget, so tests can drive timing
///     deterministically).
class LocationPickerCubit extends Cubit<LocationPickerState> {
  LocationPickerCubit({
    required LocationRepository repository,
    Duration searchDebounce = const Duration(milliseconds: 300),
  })  : _repository = repository,
        _searchDebounce = searchDebounce,
        super(const LocationPickerState());

  final LocationRepository _repository;
  final Duration _searchDebounce;

  Timer? _searchTimer;
  int _searchToken = 0;
  int _reverseGeocodeToken = 0;

  /// Cold-load entry point. Rehydrates the previously saved pair (if any)
  /// so the user lands on the dropoff step when they're resuming. Done as a
  /// best-effort — a repository failure just leaves the state at defaults.
  Future<void> rehydrate() async {
    try {
      final saved = await _repository.loadSavedLocations();
      if (saved == null) return;
      emit(state.copyWith(
        step: LocationPickerStep.done,
        pickup: saved.pickup,
        dropoff: saved.dropoff,
        draftSelection: saved.dropoff,
      ));
    } on Object {
      // Rehydrate is opportunistic — never surface a load error to the UI.
    }
  }

  /// Detect the current GPS position and place the draft pin there.
  /// Distinct from the map widget's own GPS button so the cubit owns the
  /// permission/unavailable error mapping.
  Future<void> detectCurrentLocation() async {
    if (state.isLocatingGps) return;
    emit(state.copyWith(isLocatingGps: true, clearError: true));
    try {
      final point = await _repository.resolveCurrentGps();
      emit(state.copyWith(
        isLocatingGps: false,
        draftSelection: point,
      ));
    } on LocationFailure catch (e) {
      emit(state.copyWith(
        isLocatingGps: false,
        error: _mapFailure(e.kind),
      ));
    } catch (_) {
      emit(state.copyWith(
        isLocatingGps: false,
        error: LocationPickerError.gpsUnavailable,
      ));
    }
  }

  /// Called on every keystroke in the search bar. Stores the query and
  /// schedules a debounced lookup so we don't fire one request per character.
  /// Empty queries clear results immediately.
  void searchAddress(String query) {
    _searchTimer?.cancel();
    emit(state.copyWith(searchQuery: query, clearError: true));
    if (query.trim().isEmpty) {
      emit(state.copyWith(
        searchResults: const [],
        isSearching: false,
      ));
      return;
    }
    final token = ++_searchToken;
    emit(state.copyWith(isSearching: true));
    _searchTimer = Timer(_searchDebounce, () => _runSearch(query, token));
  }

  Future<void> _runSearch(String query, int token) async {
    try {
      final results = await _repository.searchAddress(query);
      if (token != _searchToken) return; // stale
      emit(state.copyWith(
        searchResults: results,
        isSearching: false,
      ));
    } on Object {
      if (token != _searchToken) return;
      emit(state.copyWith(
        isSearching: false,
        error: LocationPickerError.searchFailed,
      ));
    }
  }

  /// User tapped a search suggestion — commit it as the current draft.
  void selectSearchResult(LocationPoint point) {
    _searchTimer?.cancel();
    emit(state.copyWith(
      draftSelection: point,
      searchResults: const [],
      searchQuery: point.address ?? state.searchQuery,
      isSearching: false,
      clearError: true,
    ));
  }

  /// User dragged the map pin to a new lat/lng. Updates the draft eagerly
  /// (so the preview moves) and reverse-geocodes in the background to fill
  /// in the address text.
  void onPinDragged({required double latitude, required double longitude}) {
    final draft = LocationPoint(
      latitude: latitude,
      longitude: longitude,
      address: null,
    );
    emit(state.copyWith(
      draftSelection: draft,
      isResolvingAddress: true,
      clearError: true,
    ));
    final token = ++_reverseGeocodeToken;
    unawaited(_reverseGeocode(latitude: latitude, longitude: longitude, token: token));
  }

  Future<void> _reverseGeocode({
    required double latitude,
    required double longitude,
    required int token,
  }) async {
    try {
      final address = await _repository.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      if (token != _reverseGeocodeToken) return;
      final current = state.draftSelection;
      if (current == null) return;
      emit(state.copyWith(
        isResolvingAddress: false,
        draftSelection: current.copyWith(address: address),
      ));
    } on Object {
      if (token != _reverseGeocodeToken) return;
      emit(state.copyWith(
        isResolvingAddress: false,
        error: LocationPickerError.geocodingFailed,
      ));
    }
  }

  /// Commits the current draft to pickup, then advances to dropoff. If the
  /// user is already on dropoff, this completes the flow and triggers the save.
  Future<void> confirmAndContinue() async {
    final draft = state.draftSelection;
    if (draft == null || state.isSaving) return;
    switch (state.step) {
      case LocationPickerStep.pickup:
        emit(state.copyWith(
          step: LocationPickerStep.dropoff,
          pickup: draft,
          // Pre-seed the dropoff draft with the pickup pin so the map opens
          // in a useful place; the user immediately drags from there.
          draftSelection: draft,
          searchQuery: '',
          searchResults: const [],
        ));
      case LocationPickerStep.dropoff:
        await _save(pickup: state.pickup!, dropoff: draft);
      case LocationPickerStep.done:
        return;
    }
  }

  /// Step backwards. From dropoff returns the user to pickup so they can
  /// re-pin — keeps the already-chosen pickup as the draft. From `done` the
  /// host pops the screen instead; the cubit doesn't try to re-open the
  /// committed pair.
  void goBack() {
    switch (state.step) {
      case LocationPickerStep.pickup:
      case LocationPickerStep.done:
        return;
      case LocationPickerStep.dropoff:
        emit(state.copyWith(
          step: LocationPickerStep.pickup,
          draftSelection: state.pickup,
          searchQuery: '',
          searchResults: const [],
          clearError: true,
        ));
    }
  }

  Future<void> _save({
    required LocationPoint pickup,
    required LocationPoint dropoff,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final saved = await _repository.saveDeliveryLocations(
        pickup: pickup,
        dropoff: dropoff,
      );
      emit(state.copyWith(
        isSaving: false,
        step: LocationPickerStep.done,
        pickup: saved.pickup,
        dropoff: saved.dropoff,
        draftSelection: saved.dropoff,
      ));
    } on Object {
      emit(state.copyWith(
        isSaving: false,
        error: LocationPickerError.saveFailed,
      ));
    }
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  LocationPickerError _mapFailure(LocationFailureKind kind) {
    switch (kind) {
      case LocationFailureKind.gpsPermissionDenied:
        return LocationPickerError.gpsPermissionDenied;
      case LocationFailureKind.gpsUnavailable:
        return LocationPickerError.gpsUnavailable;
      case LocationFailureKind.geocodingFailed:
        return LocationPickerError.geocodingFailed;
      case LocationFailureKind.searchFailed:
        return LocationPickerError.searchFailed;
      case LocationFailureKind.saveFailed:
        return LocationPickerError.saveFailed;
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
