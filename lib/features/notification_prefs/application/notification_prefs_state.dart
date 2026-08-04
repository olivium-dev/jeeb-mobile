import 'package:equatable/equatable.dart';

import '../domain/notification_prefs_model.dart';

/// Loading / loaded / error lifecycle for notification prefs screen (JM-058).
sealed class NotificationPrefsState extends Equatable {
  const NotificationPrefsState();
}

/// Initial load in flight; show full-page loading indicator.
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
  });

  final NotificationPrefs prefs;

  /// True while debounced PUT in-flight.
  final bool isSaving;

  /// True after PUT failed and toggle reverted (drives snackbar).
  final bool saveError;

  NotificationPrefsLoaded copyWith({
    NotificationPrefs? prefs,
    bool? isSaving,
    bool? saveError,
  }) {
    return NotificationPrefsLoaded(
      prefs: prefs ?? this.prefs,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
    );
  }

  @override
  List<Object?> get props => [prefs, isSaving, saveError];
}

/// Initial fetch failed.
class NotificationPrefsError extends NotificationPrefsState {
  const NotificationPrefsError(this.failure);

  final NotificationPrefsFailureView failure;

  @override
  List<Object?> get props => [failure];
}

/// Screen-facing error classification; decoupled from data-layer enum so presentation switch is exhaustive.
enum NotificationPrefsFailureView { network, unknown }
