import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/saved_location.dart';
import '../../domain/saved_location_repository.dart';
import 'saved_locations_state.dart';

class SavedLocationsCubit extends Cubit<SavedLocationsState> {
  SavedLocationsCubit(this._repository)
      : super(const SavedLocationsLoading());

  final SavedLocationRepository _repository;

  List<SavedLocation> _current = const [];

  Future<void> load() async {
    emit(const SavedLocationsLoading());
    try {
      _current = await _repository.fetchSavedLocations();
      emit(SavedLocationsLoaded(_current));
    } catch (_) {
      emit(const SavedLocationsError('fetch_failed'));
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
        message: 'cap_reached',
        isCapError: true,
      ));
    } catch (_) {
      emit(SavedLocationsMutationError(
        locations: _current,
        message: 'save_failed',
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
    } catch (_) {
      emit(SavedLocationsMutationError(
        locations: _current,
        message: 'save_failed',
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
    } catch (_) {
      emit(SavedLocationsMutationError(
        locations: _current,
        message: 'delete_failed',
      ));
    }
  }

  void acknowledgeError() {
    emit(SavedLocationsLoaded(_current));
  }
}
