import 'package:equatable/equatable.dart';

import '../domain/notification_preferences.dart';
import '../domain/user_profile.dart';

enum SettingsBanner {
  none,
  profileSaved,
  signedOut,
  accountDeletionRequested,
  networkError,
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
    this.banner = SettingsBanner.none,
  });

  final UserProfile profile;
  final NotificationPreferences notifications;
  final bool isLoading;
  final bool isSavingProfile;
  final bool isDeletingAccount;
  final bool isSigningOut;

  final bool deletionPending;

  final SettingsBanner banner;

  SettingsState copyWith({
    UserProfile? profile,
    NotificationPreferences? notifications,
    bool? isLoading,
    bool? isSavingProfile,
    bool? isDeletingAccount,
    bool? isSigningOut,
    bool? deletionPending,
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
        banner,
      ];
}
