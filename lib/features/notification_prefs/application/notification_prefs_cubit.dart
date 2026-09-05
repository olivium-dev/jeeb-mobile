import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
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

  /// The last toggle the user asked for, replayed by [retryLastSave].
  NotificationPrefs? _pendingRevert;
  NotificationCategoryPrefs? _pendingSave;

  /// Fetch prefs on mount / retry. A retry from a LOADED screen keeps the rows
  /// rather than blanking them (R6: refresh never flips to loading).
  Future<void> load() async {
    final current = state;
    final NotificationPrefsLoaded? warm = current is NotificationPrefsLoaded
        ? current.copyWith(
            isRefreshing: true,
            clearSaveFailure: true,
            clearRefreshFailure: true,
          )
        : null;
    emit(warm ?? const NotificationPrefsLoading());
    try {
      final prefs = await _repo.fetch();
      if (isClosed) return;
      emit(NotificationPrefsLoaded(prefs: prefs));
    } on NotificationPrefsRepositoryException catch (e) {
      if (isClosed) return;
      _emitLoadFailure(
        warm,
        _view(e.failure),
        e.appFailure ?? _appFailureFor(e.failure),
      );
    } catch (e) {
      if (isClosed) return;
      _emitLoadFailure(
        warm,
        NotificationPrefsFailureView.unknown,
        AppFailure.of(e),
      );
    }
  }

  /// R6: a failed warm re-read keeps the loaded rows behind a refresh note;
  /// only a cold read blanks the screen to the error rung.
  void _emitLoadFailure(
    NotificationPrefsLoaded? warm,
    NotificationPrefsFailureView view,
    AppFailure failure,
  ) {
    if (warm != null) {
      emit(warm.copyWith(isRefreshing: false, refreshFailure: failure));
      return;
    }
    emit(NotificationPrefsError(view, failure));
  }

  /// Dismisses the failed-refresh note without touching the rows.
  void dismissRefreshFailure() {
    final current = state;
    if (current is NotificationPrefsLoaded && current.refreshFailure != null) {
      emit(current.copyWith(clearRefreshFailure: true));
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
    _pendingRevert = preRevert;
    _pendingSave = pending;
    _debounce = Timer(_debounceDuration, () => _save(preRevert, pending));
  }

  /// Replays the toggle the failed PATCH dropped (the snack's Retry).
  Future<void> retryLastSave() async {
    final revert = _pendingRevert;
    final pending = _pendingSave;
    if (revert == null || pending == null) return;
    final current = state;
    if (current is! NotificationPrefsLoaded) return;
    emit(current.copyWith(
      prefs: current.prefs.copyWith(categories: pending),
      saveError: false,
      clearSaveFailure: true,
    ));
    await _save(revert, pending);
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
      _pendingRevert = null;
      _pendingSave = null;
      emit(NotificationPrefsLoaded(prefs: confirmed));
    } on NotificationPrefsRepositoryException catch (e) {
      if (isClosed) return;
      // Revert to last server-confirmed snapshot; flag error.
      emit(NotificationPrefsLoaded(
        prefs: preRevert,
        saveError: true,
        saveFailure: e.appFailure ?? _appFailureFor(e.failure),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(NotificationPrefsLoaded(
        prefs: preRevert,
        saveError: true,
        saveFailure: AppFailure.of(e),
      ));
    }
  }

  /// Clear transient save-error flag once snackbar shown.
  void acknowledgeError() {
    final current = state;
    if (current is NotificationPrefsLoaded && current.saveError) {
      emit(current.copyWith(saveError: false, clearSaveFailure: true));
    }
  }

  static NotificationPrefsFailureView _view(NotificationPrefsFailure f) =>
      switch (f) {
        NotificationPrefsFailure.network => NotificationPrefsFailureView.network,
        NotificationPrefsFailure.unauthorized =>
          NotificationPrefsFailureView.unauthorized,
        NotificationPrefsFailure.serverError =>
          NotificationPrefsFailureView.serverError,
        NotificationPrefsFailure.malformed =>
          NotificationPrefsFailureView.malformed,
        NotificationPrefsFailure.unknown => NotificationPrefsFailureView.unknown,
      };

  static AppFailure _appFailureFor(NotificationPrefsFailure f) => switch (f) {
        NotificationPrefsFailure.network => const NetworkFailure(),
        NotificationPrefsFailure.unauthorized => const UnauthorizedFailure(),
        NotificationPrefsFailure.serverError => const ServerFailure(status: 500),
        NotificationPrefsFailure.malformed => const UnknownFailure(parse: true),
        NotificationPrefsFailure.unknown => const UnknownFailure(),
      };

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
