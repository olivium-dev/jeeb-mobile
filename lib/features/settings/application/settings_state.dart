import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/notification_preferences.dart';
import '../domain/user_profile.dart';

/// LR-05: the screen needs a FAILED rung; `isLoading` alone left a throwing
/// profile read spinning forever.
enum SettingsStatus { initial, loading, loaded, failed }

enum SettingsBanner {
  none,
  profileSaved,
  profileSaveFailed,
  avatarRemoveFailed,
  notificationSaveFailed,
  accountDeleteFailed,
  accountDeleteNotSignedIn,
  signedOut,
  accountDeletionRequested,
  networkError,
  // F3: distinct per-outcome copy — never collapse the 502 dark path into a
  // fake success or a generic error (see JeeberUnregisterService).
  jeeberUnregistered,
  jeeberUnregisterActiveDelivery,
  jeeberUnregisterPositiveBalance,
  jeeberUnregisterUnavailable,
}

class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.error,
    this.refreshError,
    this.profile = const UserProfile.empty(),
    this.notifications = const NotificationPreferences(),
    this.isLoading = false,
    this.isSavingProfile = false,
    this.isDeletingAccount = false,
    this.isSigningOut = false,
    this.deletionPending = false,
    this.isUnregisteringJeeber = false,
    this.jeeberUnregistered = false,
    this.banner = SettingsBanner.none,
  });

  /// The rung the screen paints.
  final SettingsStatus status;

  /// The failure that owns the screen on [SettingsStatus.failed], or the one
  /// behind a failed write banner.
  final AppFailure? error;

  /// A best-effort remote enrichment that failed while the local profile
  /// still renders — a note, never a blanked screen.
  final AppFailure? refreshError;

  final UserProfile profile;
  final NotificationPreferences notifications;
  final bool isLoading;
  final bool isSavingProfile;
  final bool isDeletingAccount;
  final bool isSigningOut;

  final bool deletionPending;

  // F3: guards double-submit; `jeeberUnregistered` latches so callers can tell
  // a completed unregister from a blocked one.
  final bool isUnregisteringJeeber;
  final bool jeeberUnregistered;

  final SettingsBanner banner;

  SettingsState copyWith({
    SettingsStatus? status,
    AppFailure? error,
    bool clearError = false,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    UserProfile? profile,
    NotificationPreferences? notifications,
    bool? isLoading,
    bool? isSavingProfile,
    bool? isDeletingAccount,
    bool? isSigningOut,
    bool? deletionPending,
    bool? isUnregisteringJeeber,
    bool? jeeberUnregistered,
    SettingsBanner? banner,
  }) {
    return SettingsState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      refreshError:
          clearRefreshError ? null : (refreshError ?? this.refreshError),
      profile: profile ?? this.profile,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      isDeletingAccount: isDeletingAccount ?? this.isDeletingAccount,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      deletionPending: deletionPending ?? this.deletionPending,
      isUnregisteringJeeber:
          isUnregisteringJeeber ?? this.isUnregisteringJeeber,
      jeeberUnregistered: jeeberUnregistered ?? this.jeeberUnregistered,
      banner: banner ?? this.banner,
    );
  }

  @override
  List<Object?> get props => [
        status,
        error,
        refreshError,
        profile,
        notifications,
        isLoading,
        isSavingProfile,
        isDeletingAccount,
        isSigningOut,
        deletionPending,
        isUnregisteringJeeber,
        jeeberUnregistered,
        banner,
      ];
}
