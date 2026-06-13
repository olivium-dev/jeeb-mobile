import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';
import 'notification_prefs_state.dart';

/// Drives the notification preferences screen.
///
/// On mount, GETs `/users/me/notification-preferences`.
/// Each toggle optimistically updates the UI then schedules a debounced 500ms
/// PATCH. On PATCH failure the toggle reverts and [NotificationPrefsLoaded.saveError]
/// fires so the screen can show an OMDS snackbar (AC2).
class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit({required NotificationPrefsRepository repository})
      : _repo = repository,
        super(const NotificationPrefsLoading());

  final NotificationPrefsRepository _repo;
  Timer? _debounce;

  /// Fetches prefs from the gateway on mount.
  Future<void> load() async {
    emit(const NotificationPrefsLoading());
    try {
      final prefs = await _repo.fetch();
      emit(NotificationPrefsLoaded(prefs: prefs));
    } catch (e) {
      emit(NotificationPrefsError(e.toString()));
    }
  }

  /// Toggles a topic field by name and schedules a debounced PATCH.
  void toggleTopic(String topic, bool value) {
    final current = state;
    if (current is! NotificationPrefsLoaded) return;
    final updated = _applyTopic(current.prefs.preferences, topic, value);
    emit(current.copyWith(
      prefs: current.prefs.copyWith(preferences: updated),
      saveError: false,
    ));
    _scheduleDebounce(current.prefs, updated);
  }

  NotificationTopicPrefs _applyTopic(
    NotificationTopicPrefs prev,
    String topic,
    bool value,
  ) {
    switch (topic) {
      case 'offers':
        return prev.copyWith(offers: value);
      case 'chat':
        return prev.copyWith(chat: value);
      case 'statusChanges':
        return prev.copyWith(statusChanges: value);
      case 'ratingReminders':
        return prev.copyWith(ratingReminders: value);
      default:
        return prev;
    }
  }

  void _scheduleDebounce(
    NotificationPrefs preRevert,
    NotificationTopicPrefs pending,
  ) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _patch(preRevert, pending);
    });
  }

  Future<void> _patch(
    NotificationPrefs preRevert,
    NotificationTopicPrefs pending,
  ) async {
    final current = state;
    if (current is! NotificationPrefsLoaded) return;
    emit(current.copyWith(isSaving: true));
    try {
      final serverPrefs = await _repo.patch(pending);
      if (isClosed) return;
      emit(NotificationPrefsLoaded(prefs: serverPrefs));
    } catch (_) {
      if (isClosed) return;
      emit(NotificationPrefsLoaded(prefs: preRevert, saveError: true));
    }
  }

  /// Clears the transient save-error flag so the screen can stop showing it.
  void acknowledgeError() {
    final current = state;
    if (current is NotificationPrefsLoaded && current.saveError) {
      emit(current.copyWith(saveError: false));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
