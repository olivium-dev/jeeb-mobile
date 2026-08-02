import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';
import 'notification_prefs_state.dart';

/// Notification preferences driver (JM-058).
/// GET prefs on mount; each toggle optimistically updates then schedules debounced PUT (500ms).
/// PUT failure reverts category and fires saveError. Transactional locked (always-on);
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

  /// Fetch prefs on mount / retry.
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

  /// Toggle category, optimistic update, debounced PUT.
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
      // Revert to last server-confirmed snapshot; flag error.
      emit(NotificationPrefsLoaded(prefs: preRevert, saveError: true));
    }
  }

  /// Clear transient save-error flag once snackbar shown.
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
