import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../profile_name/domain/display_name_repository.dart';
import '../domain/account_service.dart';
import '../domain/avatar_cache_evictor.dart';
import '../domain/avatar_repository.dart';
import '../domain/jeeber_unregister_service.dart';
import '../domain/notification_preferences.dart';
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
    JeeberUnregisterService? jeeberUnregisterService,
    SettingsNotificationPrefsStore? notificationStore,
    String fallbackPhoneE164 = '',
  })  : _profileRepository = profileRepository,
        _accountService = accountService,
        _displayNameRepository = displayNameRepository,
        _avatarRepository = avatarRepository,
        _cacheEvictor = avatarCacheEvictor,
        _remoteProfileRepository = remoteProfileRepository,
        _refreshSignals = refreshSignals,
        _jeeberUnregisterService = jeeberUnregisterService,
        _notificationStore = notificationStore,
        _fallbackPhoneE164 = fallbackPhoneE164,
        super(const SettingsState());

  final ProfileRepository _profileRepository;
  final AccountService _accountService;

  final DisplayNameRepository? _displayNameRepository;
  final AvatarRepository? _avatarRepository;
  final AvatarCacheEvictor? _cacheEvictor;

  /// F3: optional so a bare/test cubit degrades — see [unregisterAsJeeber].
  final JeeberUnregisterService? _jeeberUnregisterService;

  /// F5: lets `load()` also pull the remote avatar so a cross-device change
  /// shows here. Optional so a bare/test cubit degrades to local-only.
  final CustomerProfileRepository? _remoteProfileRepository;

  /// F11: device-local persistence for the four toggles. Optional so a bare
  /// cubit degrades to the pre-F11 in-memory behaviour.
  final SettingsNotificationPrefsStore? _notificationStore;

  final ProfileRefreshSignals? _refreshSignals;
  final String _fallbackPhoneE164;

  Future<void> load() => _load(silent: false);

  /// R6: a warm re-read keeps the loaded rows on screen — it never flips the
  /// screen back to the loading rung, and reports failure as a refresh note.
  Future<void> refresh() =>
      _load(silent: state.status == SettingsStatus.loaded);

  Future<void> _load({required bool silent}) async {
    if (state.isLoading) return;
    emit(silent
        ? state.copyWith(
            isLoading: true,
            banner: SettingsBanner.none,
            clearRefreshError: true,
          )
        : state.copyWith(
            status: SettingsStatus.loading,
            isLoading: true,
            banner: SettingsBanner.none,
            clearError: true,
            clearRefreshError: true,
          ));
    final UserProfile? loaded;
    try {
      loaded = await _profileRepository.load();
    } catch (e) {
      emit(silent
          ? state.copyWith(isLoading: false, refreshError: AppFailure.of(e))
          : state.copyWith(
              status: SettingsStatus.failed,
              isLoading: false,
              error: AppFailure.of(e),
            ));
      return;
    }
    var resolved = loaded ?? UserProfile(phoneE164: _fallbackPhoneE164);
    NotificationPreferences? storedNotifications;
    final store = _notificationStore;
    if (store != null) {
      try {
        storedNotifications = await store.read();
      } catch (e) {
        Diag.event('settings_notification_prefs_read_failed', {
          'kind': AppFailure.of(e).kind.name,
        });
      }
    }
    AppFailure? refreshError;
    final remoteRepo = _remoteProfileRepository;
    if (remoteRepo != null) {
      try {
        final remote = await remoteRepo.fetchProfile();
        final remoteAvatar = remote.avatarUrl;
        if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
          resolved = resolved.copyWith(photoUrl: remoteAvatar);
        }
        // `/v1/users/me` is authoritative for the SIGNED-IN account; a local
        // cache written by a previous account otherwise leaks its name here.
        final remoteName = remote.name;
        if (remoteName != null && remoteName.trim().isNotEmpty) {
          resolved = resolved.copyWith(name: remoteName.trim());
        }
      } catch (e) {
        // Best-effort — the local/fallback profile above still renders, but
        // the screen says so rather than pretending the read succeeded.
        refreshError = AppFailure.of(e);
      }
    }
    emit(state.copyWith(
      status: SettingsStatus.loaded,
      profile: resolved,
      notifications: storedNotifications,
      isLoading: false,
      refreshError: refreshError,
      clearRefreshError: refreshError == null,
    ));
  }

  void dismissRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
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
    final previous = state.profile;
    final next = state.profile.copyWith(name: cleanedName, photoUrl: resolvedPhoto);
    emit(state.copyWith(
      profile: next,
      isSavingProfile: true,
      banner: SettingsBanner.none,
      clearError: true,
    ));
    final bool remoteAccepted;
    try {
      await _profileRepository.save(next);
      remoteAccepted = await _syncDisplayNameRemote(cleanedName, previous);
    } catch (e) {
      emit(state.copyWith(
        profile: previous,
        isSavingProfile: false,
        banner: SettingsBanner.profileSaveFailed,
        error: AppFailure.of(e),
      ));
      return;
    }
    if (!remoteAccepted) {
      emit(state.copyWith(
        isSavingProfile: false,
        banner: SettingsBanner.profileSaveFailed,
      ));
      return;
    }
    emit(state.copyWith(
      isSavingProfile: false,
      banner: SettingsBanner.profileSaved,
    ));
  }

  String? _cleanName(String? name) =>
      (name == null || name.trim().isEmpty) ? null : name.trim();

  /// False when the remote name write was rejected, so `saveProfile` never
  /// reports "Profile saved" for a name the backend refused (LR-15).
  Future<bool> _syncDisplayNameRemote(String? name, UserProfile previous) async {
    final repo = _displayNameRepository;
    if (repo == null || name == null || name.isEmpty) return true;
    try {
      await repo.submitDisplayName(name);
      _refreshSignals?.signalProfileChanged();
      return true;
    } on DisplayNameRepositoryException catch (e) {
      if (e.failure == DisplayNameFailure.unauthorized) {
        // A rejected identity change: the local edit must not stand.
        emit(state.copyWith(
          profile: state.profile.copyWith(name: previous.name),
          error: const UnauthorizedFailure(),
        ));
      }
      return false;
    } catch (e) {
      Diag.event('settings_display_name_sync_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
      return false;
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
      } catch (e) {
        // The remote avatar still exists, so the screen must not claim it is
        // gone: put it back and say so.
        final restored = state.profile.copyWith(photoUrl: previousUrl);
        try {
          await _profileRepository.save(restored);
        } catch (_) {
          // The local write is best-effort; the screen still has to report.
        }
        emit(state.copyWith(
          profile: restored,
          isSavingProfile: false,
          banner: SettingsBanner.avatarRemoveFailed,
          error: AppFailure.of(e),
        ));
        return;
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

  Future<void> setNotification(
    NotificationCategory category,
    bool enabled,
  ) async {
    final previous = state.notifications;
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
    emit(state.copyWith(notifications: next, banner: SettingsBanner.none));
    final store = _notificationStore;
    if (store == null) return;
    try {
      await store.write(next);
    } catch (e) {
      emit(state.copyWith(
        notifications: previous,
        banner: SettingsBanner.notificationSaveFailed,
        error: AppFailure.of(e),
      ));
    }
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
      case AccountActionOutcome.notSignedIn:
        emit(state.copyWith(
          isDeletingAccount: false,
          banner: SettingsBanner.accountDeleteNotSignedIn,
        ));
      case AccountActionOutcome.serverError:
        emit(state.copyWith(
          isDeletingAccount: false,
          banner: SettingsBanner.accountDeleteFailed,
        ));
    }
  }

  /// F3: honest per-outcome banners — a dark `502 upstream_fault` (UM has no
  /// revoke op yet) renders as "temporarily unavailable", never a fake
  /// success. [state.jeeberUnregistered] latches on success/notAJeeber so the
  /// caller can trigger a role-state refresh exactly once.
  Future<void> unregisterAsJeeber() async {
    if (state.isUnregisteringJeeber || state.jeeberUnregistered) return;
    final service = _jeeberUnregisterService;
    if (service == null) {
      emit(state.copyWith(banner: SettingsBanner.jeeberUnregisterUnavailable));
      return;
    }
    emit(state.copyWith(
      isUnregisteringJeeber: true,
      banner: SettingsBanner.none,
    ));
    final outcome = await service.unregister();
    switch (outcome) {
      case JeeberUnregisterOutcome.success:
      case JeeberUnregisterOutcome.notAJeeber:
        emit(state.copyWith(
          isUnregisteringJeeber: false,
          jeeberUnregistered: true,
          banner: SettingsBanner.jeeberUnregistered,
        ));
      case JeeberUnregisterOutcome.activeDelivery:
        emit(state.copyWith(
          isUnregisteringJeeber: false,
          banner: SettingsBanner.jeeberUnregisterActiveDelivery,
        ));
      case JeeberUnregisterOutcome.positiveBalance:
        emit(state.copyWith(
          isUnregisteringJeeber: false,
          banner: SettingsBanner.jeeberUnregisterPositiveBalance,
        ));
      case JeeberUnregisterOutcome.unavailable:
        emit(state.copyWith(
          isUnregisteringJeeber: false,
          banner: SettingsBanner.jeeberUnregisterUnavailable,
        ));
      case JeeberUnregisterOutcome.networkError:
        emit(state.copyWith(
          isUnregisteringJeeber: false,
          banner: SettingsBanner.networkError,
        ));
      case JeeberUnregisterOutcome.serverError:
        emit(state.copyWith(
          isUnregisteringJeeber: false,
          banner: SettingsBanner.jeeberUnregisterUnavailable,
        ));
    }
  }

  Future<void> signOut() async {
    if (state.isSigningOut) return;
    emit(state.copyWith(isSigningOut: true, banner: SettingsBanner.none));
    final outcome = await _accountService.signOut();
    switch (outcome) {
      // Every outcome clears the local session — never trap a user inside a
      // signed-in shell — but the banner only claims success once it did.
      case AccountActionOutcome.success:
      case AccountActionOutcome.alreadyPending:
      case AccountActionOutcome.notSignedIn:
      case AccountActionOutcome.serverError:
      case AccountActionOutcome.networkError:
        try {
          await _profileRepository.clear();
        } catch (e) {
          emit(state.copyWith(
            isSigningOut: false,
            banner: SettingsBanner.networkError,
            error: AppFailure.of(e),
          ));
          return;
        }
        emit(state.copyWith(
          isSigningOut: false,
          banner: SettingsBanner.signedOut,
          profile: UserProfile(phoneE164: _fallbackPhoneE164),
        ));
    }
  }
}

enum NotificationCategory { offers, chat, status, ratingReminders }
