import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/current_location_resolver.dart';
import '../domain/location_select_repository.dart';
import 'location_select_state.dart';

class LocationSelectCubit extends Cubit<LocationSelectState> {
  LocationSelectCubit({
    required LocationSelectRepository repository,
    required String userId,
    CurrentLocationResolver? currentLocationResolver,
  })  : _repository = repository,
        _userId = userId,
        _resolver = currentLocationResolver,
        super(const LocationSelectState());

  final LocationSelectRepository _repository;
  final String _userId;
  final CurrentLocationResolver? _resolver;

  Future<void> load() async {
    if (state.status != LocationSelectStatus.initial) return;
    emit(state.copyWith(status: LocationSelectStatus.loading, clearError: true));
    try {
      final addresses = await _repository.fetchSavedAddresses(_userId);
      emit(state.copyWith(
        status: LocationSelectStatus.loaded,
        savedAddresses: addresses,
      ));
    } on LocationSelectException catch (e) {
      emit(state.copyWith(status: LocationSelectStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: LocationSelectStatus.failed,
        error: LocationSelectFailure.unknown,
      ));
    }
    if (state.choiceKind == LocationChoiceKind.current) {
      await resolveCurrentGps();
    }
  }

  Future<void> refresh() async {
    try {
      final addresses = await _repository.fetchSavedAddresses(_userId);
      emit(state.copyWith(
        status: LocationSelectStatus.loaded,
        savedAddresses: addresses,
        clearError: true,
      ));
    } on LocationSelectException catch (e) {
      emit(state.copyWith(status: LocationSelectStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: LocationSelectStatus.failed,
        error: LocationSelectFailure.unknown,
      ));
    }
  }

  void selectCurrent() {
    if (state.choiceKind != LocationChoiceKind.current) {
      emit(state.copyWith(
        choiceKind: LocationChoiceKind.current,
        clearSelectedSaved: true,
        clearPinned: true,
      ));
    }
    if (!state.hasCurrentGps) {
      resolveCurrentGps();
    }
  }

  Future<void> resolveCurrentGps() async {
    final resolver = _resolver;
    if (resolver == null) return;
    emit(state.copyWith(
      currentGpsStatus: CurrentGpsStatus.resolving,
      clearGps: true,
    ));
    final result = await resolver.resolve();
    if (isClosed) return;
    if (state.choiceKind != LocationChoiceKind.current) return;
    switch (result.outcome) {
      case CurrentLocationOutcome.resolved:
        emit(state.copyWith(
          currentGpsStatus: CurrentGpsStatus.resolved,
          gpsLat: result.latitude,
          gpsLng: result.longitude,
          gpsAccuracyMeters: result.accuracyMeters,
        ));
      case CurrentLocationOutcome.permissionDenied:
        emit(state.copyWith(
          currentGpsStatus: CurrentGpsStatus.permissionDenied,
          clearGps: true,
        ));
      case CurrentLocationOutcome.serviceDisabled:
        emit(state.copyWith(
          currentGpsStatus: CurrentGpsStatus.serviceDisabled,
          clearGps: true,
        ));
      case CurrentLocationOutcome.failed:
        emit(state.copyWith(
          currentGpsStatus: CurrentGpsStatus.failed,
          clearGps: true,
        ));
    }
  }

  Future<void> openLocationSettings() async =>
      _resolver?.openLocationSettings();

  Future<void> openAppSettings() async => _resolver?.openAppSettings();

  void selectSaved(String id) {
    if (state.isSavedSelected(id)) return;
    emit(state.copyWith(
      choiceKind: LocationChoiceKind.saved,
      selectedSavedId: id,
      clearPinned: true,
    ));
  }

  void markPinned({double? latitude, double? longitude}) {
    emit(state.copyWith(
      choiceKind: LocationChoiceKind.pinned,
      clearSelectedSaved: true,
      pinnedLat: latitude,
      pinnedLng: longitude,
      clearPinned: latitude == null && longitude == null,
    ));
  }
}
