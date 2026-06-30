import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/location_select_repository.dart';
import 'location_select_state.dart';

/// Drives the `location-select` step (JM-024). Loads the user's saved addresses
/// (`GET /api/users/me/saved-locations`) so a returning customer can pick one,
/// and tracks the current selection (current GPS / a saved address / a freshly
/// pinned point) that the Confirm CTA forwards to order-chat.
///
/// The saved-address load is non-fatal to the flow: if it fails, the screen
/// still renders the Current/New affordances (the customer can pin a new point)
/// — so a transport failure surfaces a retry banner but never blocks the
/// create flow.
class LocationSelectCubit extends Cubit<LocationSelectState> {
  LocationSelectCubit({
    required LocationSelectRepository repository,
    required String userId,
  })  : _repository = repository,
        _userId = userId,
        super(const LocationSelectState());

  final LocationSelectRepository _repository;
  final String _userId;

  /// Cold entry — guards re-entry so a remount does not re-fetch
  /// (40_GUARDRAILS_ARCH §2.2).
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
  }

  /// Pull-to-retry / error-banner retry — does NOT flip to a full-screen
  /// spinner (40_GUARDRAILS_ARCH §2.2).
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

  /// Selects the "Current Location" option (the default).
  void selectCurrent() {
    if (state.choiceKind == LocationChoiceKind.current) return;
    emit(state.copyWith(
      choiceKind: LocationChoiceKind.current,
      clearSelectedSaved: true,
      clearPinned: true,
    ));
  }

  /// Selects a saved address by id.
  void selectSaved(String id) {
    if (state.isSavedSelected(id)) return;
    emit(state.copyWith(
      choiceKind: LocationChoiceKind.saved,
      selectedSavedId: id,
      clearPinned: true,
    ));
  }

  /// Records that the customer confirmed a freshly-pinned point from the
  /// map-pin step (capture-location → back here).
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
