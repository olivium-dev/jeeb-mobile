import 'package:equatable/equatable.dart';

import '../domain/notification_prefs_model.dart';

/// Loading / loaded / error lifecycle for the notification prefs screen.
sealed class NotificationPrefsState extends Equatable {
  const NotificationPrefsState();
}

/// Initial load in flight — show full-page loading indicator.
class NotificationPrefsLoading extends NotificationPrefsState {
  const NotificationPrefsLoading();

  @override
  List<Object?> get props => [];
}

/// Preferences successfully loaded and ready to display.
class NotificationPrefsLoaded extends NotificationPrefsState {
  const NotificationPrefsLoaded({
    required this.prefs,
    this.isSaving = false,
    this.saveError = false,
  });

  final NotificationPrefs prefs;

  /// True while a debounced PATCH is in-flight.
  final bool isSaving;

  /// True for one frame when the PATCH failed and the toggle was reverted.
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
  const NotificationPrefsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
