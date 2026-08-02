import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/profile_refresh_signals.dart';
import '../../profile_name/domain/display_name_repository.dart';
import '../domain/account_service.dart';
import '../domain/notification_preferences.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required ProfileRepository profileRepository,
    required AccountService accountService,
    DisplayNameRepository? displayNameRepository,
    ProfileRefreshSignals? refreshSignals,
    String fallbackPhoneE164 = '',
  })  : _profileRepository = profileRepository,
        _accountService = accountService,
        _displayNameRepository = displayNameRepository,
        _refreshSignals = refreshSignals,
        _fallbackPhoneE164 = fallbackPhoneE164,
        super(const SettingsState());

  final ProfileRepository _profileRepository;
  final AccountService _accountService;

  final DisplayNameRepository? _displayNameRepository;

  final ProfileRefreshSignals? _refreshSignals;
  final String _fallbackPhoneE164;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, banner: SettingsBanner.none));
    final loaded = await _profileRepository.load();
    final resolved = loaded ?? UserProfile(phoneE164: _fallbackPhoneE164);
    emit(state.copyWith(profile: resolved, isLoading: false));
  }

  void dismissBanner() {
    if (state.banner == SettingsBanner.none) return;
    emit(state.copyWith(banner: SettingsBanner.none));
  }

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
    await _syncDisplayNameRemote(cleanedName);
    emit(state.copyWith(
      isSavingProfile: false,
      banner: SettingsBanner.profileSaved,
    ));
  }

  Future<void> _syncDisplayNameRemote(String? name) async {
    final repo = _displayNameRepository;
    if (repo == null || name == null || name.isEmpty) return;
    try {
      await repo.submitDisplayName(name);
      _refreshSignals?.signalProfileChanged();
    } on Object {
    }
  }

  Future<void> removePhoto() async {
    return saveProfile(name: state.profile.name, photoUrl: null);
  }

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

enum NotificationCategory { offers, chat, status, ratingReminders }
