import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/profile_refresh_signals.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../profile_name/domain/display_name_repository.dart';
import '../domain/account_service.dart';
import '../domain/avatar_cache_evictor.dart';
import '../domain/avatar_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';
import 'settings_state.dart';

/// Sentinel for [SettingsCubit.saveProfile]'s params: OMITTED means "leave
/// untouched" (distinct from `null` = "clear"), fixing the name-only-save clobber.
const Object _unset = Object();

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required ProfileRepository profileRepository,
    required AccountService accountService,
    DisplayNameRepository? displayNameRepository,
    AvatarRepository? avatarRepository,
    AvatarCacheEvictor? avatarCacheEvictor,
    CustomerProfileRepository? remoteProfileRepository,
    ProfileRefreshSignals? refreshSignals,
    String fallbackPhoneE164 = '',
  })  : _profileRepository = profileRepository,
        _accountService = accountService,
        _displayNameRepository = displayNameRepository,
        _avatarRepository = avatarRepository,
        _cacheEvictor = avatarCacheEvictor,
        _remoteProfileRepository = remoteProfileRepository,
        _refreshSignals = refreshSignals,
        _fallbackPhoneE164 = fallbackPhoneE164,
        super(const SettingsState());

  final ProfileRepository _profileRepository;
  final AccountService _accountService;

  final DisplayNameRepository? _displayNameRepository;
  final AvatarRepository? _avatarRepository;
  final AvatarCacheEvictor? _cacheEvictor;

  /// F5: lets `load()` also pull the remote avatar so a cross-device change
  /// shows here. Optional so a bare/test cubit degrades to local-only.
  final CustomerProfileRepository? _remoteProfileRepository;

  final ProfileRefreshSignals? _refreshSignals;
  final String _fallbackPhoneE164;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, banner: SettingsBanner.none));
    final loaded = await _profileRepository.load();
    var resolved = loaded ?? UserProfile(phoneE164: _fallbackPhoneE164);
    final remoteRepo = _remoteProfileRepository;
    if (remoteRepo != null) {
      try {
        final remote = await remoteRepo.fetchProfile();
        final remoteAvatar = remote.avatarUrl;
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          resolved = resolved.copyWith(photoUrl: remoteAvatar);
        }
      } on Object {
        // Best-effort — the local/fallback profile above still renders.
      }
    }
    emit(state.copyWith(profile: resolved, isLoading: false));
  }

  void dismissBanner() {
    if (state.banner == SettingsBanner.none) return;
    emit(state.copyWith(banner: SettingsBanner.none));
  }

  /// Saves the display name and/or a caller-supplied photo URL. Either
  /// argument may be omitted to leave that field untouched — see [_unset].
  Future<void> saveProfile({Object? name = _unset, Object? photoUrl = _unset}) async {
    if (state.isSavingProfile) return;
    final nameProvided = !identical(name, _unset);
    final photoProvided = !identical(photoUrl, _unset);
    final cleanedName =
        nameProvided ? _cleanName(name as String?) : state.profile.name;
    final resolvedPhoto =
        photoProvided ? photoUrl as String? : state.profile.photoUrl;
    final next = state.profile.copyWith(name: cleanedName, photoUrl: resolvedPhoto);
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

  String? _cleanName(String? name) =>
      (name == null || name.trim().isEmpty) ? null : name.trim();

  Future<void> _syncDisplayNameRemote(String? name) async {
    final repo = _displayNameRepository;
    if (repo == null || name == null || name.isEmpty) return;
    try {
      await repo.submitDisplayName(name);
      _refreshSignals?.signalProfileChanged();
    } on Object {
      // Pre-existing contract: the caller re-reads state to see the result.
    }
  }

  /// F5: [localPreviewPath] paints instantly, then [bytes] upload to the CDN
  /// and commit; rolls back + rethrows on failure for the screen's catch.
  Future<void> changeAvatar({
    required Uint8List bytes,
    required String localPreviewPath,
  }) async {
    if (state.isSavingProfile) return;
    final previousUrl = state.profile.photoUrl;
    final optimistic = state.profile.copyWith(photoUrl: localPreviewPath);
    emit(state.copyWith(
      profile: optimistic,
      isSavingProfile: true,
      banner: SettingsBanner.none,
    ));

    final repo = _avatarRepository;
    if (repo == null) {
      // No remote wiring: local optimistic value is final (pre-F5 behaviour).
      await _profileRepository.save(optimistic);
      emit(state.copyWith(
        isSavingProfile: false,
        banner: SettingsBanner.profileSaved,
      ));
      return;
    }

    try {
      final remoteUrl = await repo.uploadAvatar(bytes);
      final saved = state.profile.copyWith(photoUrl: remoteUrl);
      await _profileRepository.save(saved);
      emit(state.copyWith(
        profile: saved,
        isSavingProfile: false,
        banner: SettingsBanner.profileSaved,
      ));
      _refreshSignals?.signalProfileChanged();
      if (previousUrl != null && previousUrl != remoteUrl) {
        unawaited(_cacheEvictor?.evict(previousUrl));
      }
    } on AvatarRepositoryException {
      final rolledBack = state.profile.copyWith(photoUrl: previousUrl);
      emit(state.copyWith(profile: rolledBack, isSavingProfile: false));
      rethrow;
    }
  }

  /// F5: clears the avatar locally AND attempts a remote clear — the old
  /// `saveProfile(photoUrl: null)` never reached the backend.
  Future<void> removePhoto() async {
    if (state.isSavingProfile) return;
    final previousUrl = state.profile.photoUrl;
    if (previousUrl == null) return;
    final cleared = state.profile.copyWith(photoUrl: null);
    emit(state.copyWith(
      profile: cleared,
      isSavingProfile: true,
      banner: SettingsBanner.none,
    ));
    await _profileRepository.save(cleared);
    final repo = _avatarRepository;
    if (repo != null) {
      try {
        await repo.removeAvatar();
        _refreshSignals?.signalProfileChanged();
      } on Object {
        // Fail-soft: local clear already committed; self-heals on next mutation.
      }
    }
    if (previousUrl.isNotEmpty) {
      unawaited(_cacheEvictor?.evict(previousUrl));
    }
    emit(state.copyWith(
      isSavingProfile: false,
      banner: SettingsBanner.profileSaved,
    ));
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
