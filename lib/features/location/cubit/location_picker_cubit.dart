import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../data/location_repository.dart';
import 'location_picker_state.dart';

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
    } on Object catch (e) {
      // No saved location, or it failed to decode: start empty. The blob is
      // left in place — LocationRepository exposes no clear (R3).
      Diag.event('location_rehydrate_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
    }
  }

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
    } catch (e) {
      final AppFailure failure = AppFailure.of(e);
      emit(state.copyWith(
        isLocatingGps: false,
        error: failure is NetworkFailure || failure is TimeoutFailure
            ? LocationPickerError.networkUnavailable
            : LocationPickerError.gpsUnavailable,
        appFailure: failure,
      ));
    }
  }

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
      if (token != _searchToken) return;
      emit(state.copyWith(
        searchResults: results,
        isSearching: false,
      ));
    } on Object catch (e) {
      if (token != _searchToken) return;
      emit(state.copyWith(
        isSearching: false,
        error: LocationPickerError.searchFailed,
        appFailure: AppFailure.of(e),
      ));
    }
  }

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
    } on Object catch (e) {
      if (token != _reverseGeocodeToken) return;
      emit(state.copyWith(
        isResolvingAddress: false,
        error: LocationPickerError.geocodingFailed,
        appFailure: AppFailure.of(e),
      ));
    }
  }

  Future<void> confirmAndContinue() async {
    final draft = state.draftSelection;
    if (draft == null || state.isSaving) return;
    switch (state.step) {
      case LocationPickerStep.pickup:
        emit(state.copyWith(
          step: LocationPickerStep.dropoff,
          pickup: draft,
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
    } on Object catch (e) {
      emit(state.copyWith(
        isSaving: false,
        error: LocationPickerError.saveFailed,
        appFailure: AppFailure.of(e),
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
