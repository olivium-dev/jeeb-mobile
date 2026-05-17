import 'package:equatable/equatable.dart';

import '../domain/notification_preferences.dart';
import '../domain/user_profile.dart';

/// Banner the screen surfaces after a destructive action completes. The
/// cubit clears it on the next user interaction so it doesn't linger across
/// route transitions.
enum SettingsBanner {
  none,
  profileSaved,
  signedOut,
  accountDeletionRequested,
  networkError,
}

/// Whole-screen state for the settings list + profile-edit screen
/// (T-mobile-031).
///
/// `phoneE164` is intentionally derived from `profile` rather than a
/// separate field — the read-only phone row mirrors the profile model so
/// there is one source of truth.
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

  /// Latches once a delete-account request has been submitted so the row
  /// flips to a "pending" affordance and can't be re-tapped.
  final bool deletionPending;

  /// Transient banner the UI renders for action feedback.
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
