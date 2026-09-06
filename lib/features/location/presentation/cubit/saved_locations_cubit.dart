import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/app_failure.dart';
import '../../domain/saved_location.dart';
import '../../domain/saved_location_repository.dart';
import 'saved_locations_state.dart';

class SavedLocationsCubit extends Cubit<SavedLocationsState> {
  SavedLocationsCubit(this._repository)
      : super(const SavedLocationsLoading());

  final SavedLocationRepository _repository;

  List<SavedLocation> _current = const [];

  bool _loading = false;

  /// A refresh keeps the rows on screen: only a cold load may show a spinner
  /// or an error page.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final bool warm = _current.isNotEmpty;
    if (!warm) emit(const SavedLocationsLoading());
    try {
      _current = await _repository.fetchSavedLocations();
      emit(SavedLocationsLoaded(_current));
    } catch (e) {
      final AppFailure failure = AppFailure.of(e);
      emit(warm
          ? SavedLocationsLoaded(_current, refreshError: failure)
          : SavedLocationsError(failure));
    } finally {
      _loading = false;
    }
  }

  Future<void> create({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    emit(SavedLocationsMutating(_current));
    try {
      final created = await _repository.saveLocation(
        latitude: latitude,
        longitude: longitude,
        label: label,
        category: category,
        address: address,
      );
      _current = [created, ..._current];
      emit(SavedLocationsLoaded(_current));
    } on SavedLocationCapReachedException {
      emit(SavedLocationsMutationError(
        locations: _current,
        mutation: SavedLocationsMutation.create,
        isCapError: true,
      ));
    } catch (e) {
      emit(SavedLocationsMutationError(
        locations: _current,
        mutation: SavedLocationsMutation.create,
        failure: AppFailure.of(e),
      ));
    }
  }

  Future<void> update({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    emit(SavedLocationsMutating(_current));
    try {
      final updated = await _repository.updateLocation(
        id: id,
        latitude: latitude,
        longitude: longitude,
        label: label,
        category: category,
        address: address,
      );
      _current = _current
          .map((l) => l.id == id ? updated : l)
          .toList(growable: false);
      emit(SavedLocationsLoaded(_current));
    } catch (e) {
      emit(SavedLocationsMutationError(
        locations: _current,
        mutation: SavedLocationsMutation.update,
        failure: AppFailure.of(e),
      ));
    }
  }

  Future<void> delete(String id) async {
    emit(SavedLocationsMutating(_current));
    try {
      await _repository.deleteLocation(id);
      _current = _current
          .where((l) => l.id != id)
          .toList(growable: false);
      emit(SavedLocationsLoaded(_current));
    } catch (e) {
      emit(SavedLocationsMutationError(
        locations: _current,
        mutation: SavedLocationsMutation.delete,
        failure: AppFailure.of(e),
      ));
    }
  }

  void acknowledgeError() {
    emit(SavedLocationsLoaded(_current));
  }

  /// Drops the warm-refresh notice once the user dismisses it; the rows stay.
  void acknowledgeRefreshError() {
    emit(SavedLocationsLoaded(_current));
  }
}
