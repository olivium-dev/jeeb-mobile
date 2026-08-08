import 'package:equatable/equatable.dart';

import '../domain/notification_preferences.dart';
import '../domain/user_profile.dart';

enum SettingsBanner {
  none,
  profileSaved,
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

  final UserProfile profile;
  final NotificationPreferences notifications;
  final bool isLoading;
  final bool isSavingProfile;
  final bool isDeletingAccount;
  final bool isSigningOut;

  final bool deletionPending;

  // F3: `isUnregisteringJeeber` guards double-submit; `jeeberUnregistered`
  // latches (never resets) so the role-gated row/card family and the
  // confirm-sheet caller can tell a completed unregister from a blocked one.
  final bool isUnregisteringJeeber;
  final bool jeeberUnregistered;

  final SettingsBanner banner;

  SettingsState copyWith({
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
