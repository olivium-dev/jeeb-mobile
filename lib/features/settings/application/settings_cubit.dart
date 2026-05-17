import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account_service.dart';
import '../domain/notification_preferences.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';
import 'settings_state.dart';

/// Single cubit for the entire settings surface (T-mobile-031).
///
/// Wraps three collaborators:
///   - [ProfileRepository] — load/save the user profile (name + photo).
///   - [AccountService] — sign-out and delete-account at the gateway.
///   - In-memory [NotificationPreferences] — toggled by the user; persistence
///     ships separately when the user-preference-v2 NSwag client lands.
///
/// The cubit owns the destructive-action state machine (sign-out and
/// delete-account) so the UI just dispatches and renders the banner.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required ProfileRepository profileRepository,
    required AccountService accountService,
    String fallbackPhoneE164 = '',
  })  : _profileRepository = profileRepository,
        _accountService = accountService,
        _fallbackPhoneE164 = fallbackPhoneE164,
        super(const SettingsState());

  final ProfileRepository _profileRepository;
  final AccountService _accountService;
  final String _fallbackPhoneE164;

  /// Hydrates the cubit from the profile repository. Safe to call multiple
  /// times — concurrent calls are short-circuited by the [SettingsState.isLoading]
  /// flag.
  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, banner: SettingsBanner.none));
    final loaded = await _profileRepository.load();
    final resolved = loaded ?? UserProfile(phoneE164: _fallbackPhoneE164);
    emit(state.copyWith(profile: resolved, isLoading: false));
  }

  /// Dismiss the current banner. Call after the user acknowledges feedback,
  /// before navigating away, etc.
  void dismissBanner() {
    if (state.banner == SettingsBanner.none) return;
    emit(state.copyWith(banner: SettingsBanner.none));
  }

  /// Persist a profile edit. Trims the name, treats blank as null, and emits
  /// the `profileSaved` banner on success.
  Future<void> saveProfile({String? name, String? photoUrl}) async {
    if (state.isSavingProfile) return;
    final cleanedName = (name == null || name.trim().isEmpty) ? null : name.trim();
    final next = state.profile.copyWith(
      name: cleanedName,
      photoUrl: photoUrl,
    );
    emit(state.copyWith(
      profile: next,
      isSavingProfile: true,
      banner: SettingsBanner.none,
    ));
    await _profileRepository.save(next);
    emit(state.copyWith(
      isSavingProfile: false,
      banner: SettingsBanner.profileSaved,
    ));
  }

  /// Remove the currently-set avatar without touching the name. Convenience
  /// path the UI exposes via the "Remove avatar" affordance.
  Future<void> removePhoto() async {
    return saveProfile(name: state.profile.name, photoUrl: null);
  }

  /// Toggle a single notification category. The `category` is identified by
  /// the field name so the switch row can call into one method instead of
  /// four. Unknown categories are a programmer error and asserted in debug.
  void setNotification(NotificationCategory category, bool enabled) {
    final next = switch (category) {
      NotificationCategory.offers =>
        state.notifications.copyWith(offers: enabled),
      NotificationCategory.chat =>
        state.notifications.copyWith(chat: enabled),
      NotificationCategory.status =>
        state.notifications.copyWith(status: enabled),
      NotificationCategory.ratingReminders =>
        state.notifications.copyWith(ratingReminders: enabled),
    };
    emit(state.copyWith(notifications: next));
  }

  /// Submit a delete-account request. Latches `deletionPending` on success
  /// so the row in the UI flips and can't be re-tapped while the gateway
  /// processes the request.
  Future<void> requestAccountDeletion() async {
    if (state.isDeletingAccount || state.deletionPending) return;
    emit(state.copyWith(
      isDeletingAccount: true,
      banner: SettingsBanner.none,
    ));
    final outcome = await _accountService.requestAccountDeletion();
    switch (outcome) {
      case AccountActionOutcome.success:
      case AccountActionOutcome.alreadyPending:
        emit(state.copyWith(
          isDeletingAccount: false,
          deletionPending: true,
          banner: SettingsBanner.accountDeletionRequested,
        ));
      case AccountActionOutcome.networkError:
        emit(state.copyWith(
          isDeletingAccount: false,
          banner: SettingsBanner.networkError,
        ));
    }
  }

  /// Sign out the user. Clears the cached profile on the gateway success
  /// path so the next sign-in starts from a clean slate.
  Future<void> signOut() async {
    if (state.isSigningOut) return;
    emit(state.copyWith(isSigningOut: true, banner: SettingsBanner.none));
    final outcome = await _accountService.signOut();
    switch (outcome) {
      case AccountActionOutcome.success:
      case AccountActionOutcome.alreadyPending:
        await _profileRepository.clear();
        emit(state.copyWith(
          isSigningOut: false,
          banner: SettingsBanner.signedOut,
          profile: UserProfile(phoneE164: _fallbackPhoneE164),
        ));
      case AccountActionOutcome.networkError:
        emit(state.copyWith(
          isSigningOut: false,
          banner: SettingsBanner.networkError,
        ));
    }
  }
}

/// Discriminator passed to [SettingsCubit.setNotification].
enum NotificationCategory { offers, chat, status, ratingReminders }
