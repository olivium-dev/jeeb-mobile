import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';
import 'notification_prefs_state.dart';

/// Drives the notification-preferences screen (JM-058, D64).
///
/// On mount, GETs `/v1/notifications/preferences`. Each category toggle
/// optimistically updates the UI then schedules a debounced PUT (default 500ms).
/// On PUT failure the category reverts and [NotificationPrefsLoaded.saveError]
/// fires so the screen shows an OMDS snackbar. The transactional class is locked
/// (never toggled) and push is the only channel surfaced (R2).
class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit({
    required NotificationPrefsRepository repository,
    Duration debounce = const Duration(milliseconds: 500),
  })  : _repo = repository,
        _debounceDuration = debounce,
        super(const NotificationPrefsLoading());

  final NotificationPrefsRepository _repo;
  final Duration _debounceDuration;
  Timer? _debounce;

  /// Fetches prefs from the gateway on mount / retry.
  Future<void> load() async {
    emit(const NotificationPrefsLoading());
    try {
      final prefs = await _repo.fetch();
      emit(NotificationPrefsLoaded(prefs: prefs));
    } on NotificationPrefsRepositoryException catch (e) {
      emit(NotificationPrefsError(_view(e.failure)));
    } catch (_) {
      emit(const NotificationPrefsError(NotificationPrefsFailureView.unknown));
    }
  }

  /// Toggles a category, optimistically updates, and schedules a debounced PUT.
  void toggleCategory(NotificationCategory category, bool value) {
    final current = state;
    if (current is! NotificationPrefsLoaded) return;

    final preRevert = current.prefs;
    final updatedCategories =
        current.prefs.categories.withValue(category, value);
    emit(current.copyWith(
      prefs: current.prefs.copyWith(categories: updatedCategories),
      saveError: false,
    ));
    _scheduleSave(preRevert, updatedCategories);
  }

  void _scheduleSave(
    NotificationPrefs preRevert,
    NotificationCategoryPrefs pending,
  ) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _save(preRevert, pending));
  }

  Future<void> _save(
    NotificationPrefs preRevert,
    NotificationCategoryPrefs pending,
  ) async {
    final current = state;
    if (current is! NotificationPrefsLoaded) return;
    emit(current.copyWith(isSaving: true));
    try {
      final confirmed = await _repo.save(pending);
      if (isClosed) return;
      emit(NotificationPrefsLoaded(prefs: confirmed));
    } catch (_) {
      if (isClosed) return;
      // Revert to the last server-confirmed snapshot + flag the error (D30).
      emit(NotificationPrefsLoaded(prefs: preRevert, saveError: true));
    }
  }

  /// Clears the transient save-error flag once the snackbar has been shown.
  void acknowledgeError() {
    final current = state;
    if (current is NotificationPrefsLoaded && current.saveError) {
      emit(current.copyWith(saveError: false));
    }
  }

  NotificationPrefsFailureView _view(NotificationPrefsFailure f) {
    switch (f) {
      case NotificationPrefsFailure.network:
        return NotificationPrefsFailureView.network;
      case NotificationPrefsFailure.unknown:
        return NotificationPrefsFailureView.unknown;
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
