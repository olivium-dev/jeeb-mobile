import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/current_location_resolver.dart';
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
///
/// JEBV4-176 (Q-060): the "Current Location" option now resolves a REAL device
/// GPS fix via [CurrentLocationResolver] instead of silently falling back to a
/// hardcoded Beirut coordinate. Acquisition state lives on
/// [LocationSelectState.currentGpsStatus]; only a `resolved` fix makes the
/// current option confirmable. A null [_resolver] (isolated dev/test host with
/// no GPS) leaves the status `idle` — the customer must pin a point instead,
/// which is honest rather than fabricating a location.
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
    // The default selection is "Current Location", so acquire the device fix
    // as soon as the screen loads (regardless of the saved-address outcome —
    // a customer with no/failed saved addresses still creates via GPS). Awaited
    // so the resolved/recovery emit lands within this cold-load flow (the host
    // memoizes the user-id future, so load() runs exactly once — no churn).
    if (state.choiceKind == LocationChoiceKind.current) {
      await resolveCurrentGps();
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

  /// Selects the "Current Location" option (the default) and (re)acquires the
  /// device GPS fix for it.
  void selectCurrent() {
    if (state.choiceKind != LocationChoiceKind.current) {
      emit(state.copyWith(
        choiceKind: LocationChoiceKind.current,
        clearSelectedSaved: true,
        clearPinned: true,
      ));
    }
    // Re-resolve unless we already hold a fix (idempotent tap on an already
    // resolved current option should not re-prompt).
    if (!state.hasCurrentGps) {
      resolveCurrentGps();
    }
  }

  /// Acquires (or re-acquires, for the recovery "retry" CTA) a REAL device GPS
  /// fix for the current-location option. Maps the resolver outcome onto
  /// [LocationSelectState.currentGpsStatus] and, on success, stores the real
  /// coordinate the create draft uses. Never fabricates a coordinate.
  Future<void> resolveCurrentGps() async {
    final resolver = _resolver;
    if (resolver == null) return; // no GPS capability wired — stay idle.
    emit(state.copyWith(
      currentGpsStatus: CurrentGpsStatus.resolving,
      clearGps: true,
    ));
    final result = await resolver.resolve();
    if (isClosed) return;
    // The customer may have switched to a saved address / pin while we awaited;
    // don't clobber that selection with a stale GPS result.
    if (state.choiceKind != LocationChoiceKind.current) return;
    switch (result.outcome) {
      case CurrentLocationOutcome.resolved:
        emit(state.copyWith(
          currentGpsStatus: CurrentGpsStatus.resolved,
          gpsLat: result.latitude,
          gpsLng: result.longitude,
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

  /// Recovery CTA — opens the OS location-services (device GPS toggle) page.
  Future<void> openLocationSettings() async =>
      _resolver?.openLocationSettings();

  /// Recovery CTA — opens this app's OS settings page to grant permission.
  Future<void> openAppSettings() async => _resolver?.openAppSettings();

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
