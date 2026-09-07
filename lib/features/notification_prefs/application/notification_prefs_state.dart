import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/notification_prefs_model.dart';

/// Loading / loaded / error lifecycle for notification prefs screen (JM-058).
sealed class NotificationPrefsState extends Equatable {
  const NotificationPrefsState();
}

/// Initial load in flight; show full-page loading indicator. A retry from a
/// LOADED screen sets `isRefreshing` there instead of coming back here.
class NotificationPrefsLoading extends NotificationPrefsState {
  const NotificationPrefsLoading();

  @override
  List<Object?> get props => [];
}

/// Preferences loaded and ready to display.
class NotificationPrefsLoaded extends NotificationPrefsState {
  const NotificationPrefsLoaded({
    required this.prefs,
    this.isSaving = false,
    this.saveError = false,
    this.isRefreshing = false,
    this.saveFailure,
    this.refreshFailure,
  });

  final NotificationPrefs prefs;

  /// A warm re-read while the rows stay on screen.
  final bool isRefreshing;

  /// The classified failure behind [saveError].
  final AppFailure? saveFailure;

  /// A failed warm re-read (R6): the rows stay, the screen says the refresh
  /// did not land.
  final AppFailure? refreshFailure;

  /// True while debounced PUT in-flight.
  final bool isSaving;

  /// True after PUT failed and toggle reverted (drives snackbar).
  final bool saveError;

  NotificationPrefsLoaded copyWith({
    NotificationPrefs? prefs,
    bool? isSaving,
    bool? saveError,
    bool? isRefreshing,
    AppFailure? saveFailure,
    bool clearSaveFailure = false,
    AppFailure? refreshFailure,
    bool clearRefreshFailure = false,
  }) {
    return NotificationPrefsLoaded(
      prefs: prefs ?? this.prefs,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
      refreshFailure:
          clearRefreshFailure ? null : (refreshFailure ?? this.refreshFailure),
    );
  }

  @override
  List<Object?> get props =>
      [prefs, isSaving, saveError, isRefreshing, saveFailure, refreshFailure];
}

/// Initial fetch failed.
class NotificationPrefsError extends NotificationPrefsState {
  const NotificationPrefsError(this.failure, [this.appFailure]);

  final NotificationPrefsFailureView failure;

  /// The classified transport failure, for `failureCopy`.
  final AppFailure? appFailure;

  @override
  List<Object?> get props => [failure, appFailure];
}

/// Screen-facing error classification; decoupled from data-layer enum so presentation switch is exhaustive.
enum NotificationPrefsFailureView {
  network,
  unauthorized,
  serverError,
  malformed,
  unknown,
}
