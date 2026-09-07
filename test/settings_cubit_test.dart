import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/avatar_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/jeeber_unregister_service.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

import 'support/settings_fakes.dart';

class _ScriptedAccountService implements AccountService {
  _ScriptedAccountService({
    this.deletionOutcome = AccountActionOutcome.success,
    this.signOutOutcome = AccountActionOutcome.success,
  });

  AccountActionOutcome deletionOutcome;
  AccountActionOutcome signOutOutcome;
  int deletionCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async {
    deletionCalls++;
    return deletionOutcome;
  }

  @override
  Future<AccountActionOutcome> signOut() async {
    signOutCalls++;
    return signOutOutcome;
  }
}

class _RecordingDisplayNameRepository implements DisplayNameRepository {
  _RecordingDisplayNameRepository({this.throws = false});

  final bool throws;
  final List<String> submitted = <String>[];

  @override
  Future<void> submitDisplayName(String name) async {
    if (throws) {
      throw const DisplayNameRepositoryException(DisplayNameFailure.network);
    }
    submitted.add(name);
  }
}

SettingsCubit _buildCubit({
  InMemoryProfileRepository? repo,
  _ScriptedAccountService? account,
  _RecordingDisplayNameRepository? displayNameRepo,
  FakeAvatarRepository? avatarRepo,
  FakeAvatarCacheEvictor? cacheEvictor,
  FakeCustomerProfileRepository? remoteProfileRepo,
  FakeJeeberUnregisterService? unregisterService,
  String fallbackPhone = '+96170100200',
}) {
  final cubit = SettingsCubit(
    profileRepository: repo ?? InMemoryProfileRepository(),
    accountService: account ?? _ScriptedAccountService(),
    displayNameRepository: displayNameRepo,
    avatarRepository: avatarRepo,
    avatarCacheEvictor: cacheEvictor,
    remoteProfileRepository: remoteProfileRepo,
    jeeberUnregisterService: unregisterService,
    fallbackPhoneE164: fallbackPhone,
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('SettingsCubit — load', () {
    test('load seeds an empty profile with the fallback phone', () async {
      final cubit = _buildCubit();
      await cubit.load();
      expect(cubit.state.profile.phoneE164, '+96170100200');
      expect(cubit.state.profile.name, isNull);
      expect(cubit.state.profile.photoUrl, isNull);
      expect(cubit.state.isLoading, isFalse);
    });

    test('load returns the persisted profile when one exists', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
        photoUrl: 'https://cdn/jeeb/avatar.png',
      ));
      final cubit = _buildCubit(repo: repo);
      await cubit.load();
      expect(cubit.state.profile.name, 'Sami');
      expect(cubit.state.profile.photoUrl, 'https://cdn/jeeb/avatar.png');
    });

    test('concurrent loads do not race', () async {
      final cubit = _buildCubit();
      final a = cubit.load();
      final b = cubit.load();
      await Future.wait([a, b]);
      // No exception means the second call short-circuited as expected.
      expect(cubit.state.isLoading, isFalse);
    });
  });

  group('SettingsCubit — profile editing', () {
    test('saveProfile trims and persists, then emits the saved banner',
        () async {
      final repo = InMemoryProfileRepository();
      final cubit = _buildCubit(repo: repo);
      await cubit.load();
      await cubit.saveProfile(name: '   Sami   ', photoUrl: 'https://x.png');
      expect(cubit.state.profile.name, 'Sami');
      expect(cubit.state.profile.photoUrl, 'https://x.png');
      expect(cubit.state.banner, SettingsBanner.profileSaved);

      final reloaded = await repo.load();
      expect(reloaded?.name, 'Sami');
    });

    test('saveProfile treats blank-only input as null', () async {
      final cubit = _buildCubit();
      await cubit.load();
      await cubit.saveProfile(name: '   ');
      expect(cubit.state.profile.name, isNull);
    });

    test(
        'saveProfile mirrors the name to the gateway '
        '(PUT /api/User/profile username — profile-name lane)', () async {
      final remote = _RecordingDisplayNameRepository();
      final cubit = _buildCubit(displayNameRepo: remote);
      await cubit.load();
      await cubit.saveProfile(name: '  Ahmad  ');
      expect(remote.submitted, ['Ahmad']);
      expect(cubit.state.banner, SettingsBanner.profileSaved);
    });

    test('saveProfile skips the remote mirror when the name is blank',
        () async {
      final remote = _RecordingDisplayNameRepository();
      final cubit = _buildCubit(displayNameRepo: remote);
      await cubit.load();
      await cubit.saveProfile(name: '   ', photoUrl: 'https://x.png');
      expect(remote.submitted, isEmpty);
    });

    test(
        'LR-15: a failed remote mirror keeps the LOCAL save but never claims '
        '"Profile saved"', () async {
      final repo = InMemoryProfileRepository();
      final remote = _RecordingDisplayNameRepository(throws: true);
      final cubit = _buildCubit(repo: repo, displayNameRepo: remote);
      await cubit.load();
      await cubit.saveProfile(name: 'Ahmad');
      expect(cubit.state.profile.name, 'Ahmad');
      expect(cubit.state.banner, SettingsBanner.profileSaveFailed);
      expect(cubit.state.isSavingProfile, isFalse);
      expect((await repo.load())?.name, 'Ahmad');
    });

    test('removePhoto clears photoUrl but preserves the name', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
        photoUrl: 'https://cdn/jeeb/avatar.png',
      ));
      final cubit = _buildCubit(repo: repo);
      await cubit.load();
      await cubit.removePhoto();
      expect(cubit.state.profile.photoUrl, isNull);
      expect(cubit.state.profile.name, 'Sami');
    });

    test(
        'F5 regression: a name-only saveProfile survives a previously-set '
        'photo (the clobber bug the validator flagged)', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
        photoUrl: 'https://cdn/jeeb/avatar.png',
      ));
      final cubit = _buildCubit(repo: repo);
      await cubit.load();
      await cubit.saveProfile(name: 'Ahmad');
      expect(cubit.state.profile.name, 'Ahmad');
      expect(cubit.state.profile.photoUrl, 'https://cdn/jeeb/avatar.png');
      expect((await repo.load())?.photoUrl, 'https://cdn/jeeb/avatar.png');
    });
  });

  group('SettingsCubit — F5 change avatar', () {
    test('changeAvatar paints the local preview immediately, then commits '
        'the uploaded remote URL and preserves the name (the clobber twin)',
        () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
      ));
      final avatarRepo = FakeAvatarRepository()
        ..uploadedUrl = 'https://gw.test/api/users/u-1/avatar?v=2';
      final evictor = FakeAvatarCacheEvictor();
      final cubit =
          _buildCubit(repo: repo, avatarRepo: avatarRepo, cacheEvictor: evictor);
      await cubit.load();

      final bytes = Uint8List.fromList(List<int>.filled(10, 7));
      await cubit.changeAvatar(bytes: bytes, localPreviewPath: '/tmp/x.jpg');

      expect(avatarRepo.uploadCalls, 1);
      expect(avatarRepo.lastUploadedBytes, bytes);
      expect(cubit.state.profile.photoUrl, avatarRepo.uploadedUrl);
      expect(cubit.state.profile.name, 'Sami');
      expect(cubit.state.banner, SettingsBanner.profileSaved);
      expect((await repo.load())?.photoUrl, avatarRepo.uploadedUrl);
    });

    test('changeAvatar rolls back to the previous URL and rethrows on '
        'upload failure', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        photoUrl: 'https://cdn/jeeb/old.png',
      ));
      final avatarRepo = FakeAvatarRepository(
        uploadFailure: const AvatarRepositoryException(AvatarUploadFailure.network),
      );
      final cubit = _buildCubit(repo: repo, avatarRepo: avatarRepo);
      await cubit.load();

      await expectLater(
        cubit.changeAvatar(
          bytes: Uint8List(4),
          localPreviewPath: '/tmp/new.jpg',
        ),
        throwsA(isA<AvatarRepositoryException>()),
      );
      expect(cubit.state.profile.photoUrl, 'https://cdn/jeeb/old.png');
      expect(cubit.state.isSavingProfile, isFalse);
    });

    test('changeAvatar evicts the previous URL from the image cache after '
        'a successful upload', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        photoUrl: 'https://cdn/jeeb/old.png',
      ));
      final avatarRepo = FakeAvatarRepository()
        ..uploadedUrl = 'https://cdn/jeeb/new.png';
      final evictor = FakeAvatarCacheEvictor();
      final cubit =
          _buildCubit(repo: repo, avatarRepo: avatarRepo, cacheEvictor: evictor);
      await cubit.load();

      await cubit.changeAvatar(bytes: Uint8List(4), localPreviewPath: '/tmp/x.jpg');
      expect(evictor.evicted, ['https://cdn/jeeb/old.png']);
    });

    test('changeAvatar with no avatar repository wired keeps the local '
        'preview as the final value (bare/test-host degrade)', () async {
      final cubit = _buildCubit();
      await cubit.load();
      await cubit.changeAvatar(bytes: Uint8List(4), localPreviewPath: '/tmp/x.jpg');
      expect(cubit.state.profile.photoUrl, '/tmp/x.jpg');
    });

    // F10: the remote avatar still exists, so the screen must not claim it is
    // gone — the local clear is put back and the banner says what happened.
    test('removePhoto restores the photo and says so when the remote clear '
        'fails', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
        photoUrl: 'https://cdn/jeeb/avatar.png',
      ));
      final avatarRepo = FakeAvatarRepository(
        removeFailure: const AvatarRepositoryException(AvatarUploadFailure.network),
      );
      final cubit = _buildCubit(repo: repo, avatarRepo: avatarRepo);
      await cubit.load();

      await cubit.removePhoto();
      expect(avatarRepo.removeCalls, 1);
      expect(cubit.state.profile.photoUrl, 'https://cdn/jeeb/avatar.png');
      expect(cubit.state.banner, SettingsBanner.avatarRemoveFailed);
      expect(cubit.state.isSavingProfile, isFalse);
    });
  });

  group('SettingsCubit — F5 cross-device staleness', () {
    test('load() prefers a fresher remote avatarUrl over the local cache',
        () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
        photoUrl: 'https://cdn/jeeb/stale-device-a.png',
      ));
      final remote = FakeCustomerProfileRepository(
        profile: const CustomerProfileViewData(
          avatarUrl: 'https://cdn/jeeb/fresh-device-b.png',
        ),
      );
      final cubit = _buildCubit(repo: repo, remoteProfileRepo: remote);
      await cubit.load();
      expect(cubit.state.profile.photoUrl, 'https://cdn/jeeb/fresh-device-b.png');
    });

    test('load() degrades to the local cache when the remote fetch fails',
        () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        photoUrl: 'https://cdn/jeeb/local.png',
      ));
      final remote = FakeCustomerProfileRepository(throws: true);
      final cubit = _buildCubit(repo: repo, remoteProfileRepo: remote);
      await cubit.load();
      expect(cubit.state.profile.photoUrl, 'https://cdn/jeeb/local.png');
    });
  });

  group('SettingsCubit — notification toggles', () {
    blocTest<SettingsCubit, SettingsState>(
      'setNotification(offers, false) flips just that field',
      build: _buildCubit,
      act: (cubit) =>
          cubit.setNotification(NotificationCategory.offers, false),
      verify: (cubit) {
        expect(cubit.state.notifications.offers, isFalse);
        expect(cubit.state.notifications.chat, isTrue);
      },
    );

    test('setNotification preserves other categories', () {
      final cubit = _buildCubit();
      cubit.setNotification(NotificationCategory.chat, false);
      cubit.setNotification(NotificationCategory.status, false);
      expect(cubit.state.notifications.chat, isFalse);
      expect(cubit.state.notifications.status, isFalse);
      expect(cubit.state.notifications.ratingReminders, isTrue);
      expect(cubit.state.notifications.offers, isTrue);
    });
  });

  group('SettingsCubit — destructive actions', () {
    test('requestAccountDeletion latches deletionPending on success',
        () async {
      final account = _ScriptedAccountService();
      final cubit = _buildCubit(account: account);
      await cubit.requestAccountDeletion();
      expect(cubit.state.deletionPending, isTrue);
      expect(cubit.state.banner, SettingsBanner.accountDeletionRequested);
      expect(account.deletionCalls, 1);
    });

    test('requestAccountDeletion short-circuits when already pending',
        () async {
      final account = _ScriptedAccountService();
      final cubit = _buildCubit(account: account);
      await cubit.requestAccountDeletion();
      await cubit.requestAccountDeletion();
      expect(account.deletionCalls, 1);
    });

    test('requestAccountDeletion surfaces network errors without latching',
        () async {
      final account = _ScriptedAccountService(
        deletionOutcome: AccountActionOutcome.networkError,
      );
      final cubit = _buildCubit(account: account);
      await cubit.requestAccountDeletion();
      expect(cubit.state.deletionPending, isFalse);
      expect(cubit.state.banner, SettingsBanner.networkError);
    });

    test('signOut clears the profile cache on success', () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
      ));
      final cubit = _buildCubit(repo: repo);
      await cubit.load();
      expect(cubit.state.profile.name, 'Sami');

      await cubit.signOut();
      expect(cubit.state.banner, SettingsBanner.signedOut);
      expect(cubit.state.profile.name, isNull);
      expect(await repo.load(), isNull);
    });

    // F37: every outcome clears the local session — a user must never be
    // trapped inside a signed-in shell because the revoke hop failed.
    test('signOut still clears the local session on a network error',
        () async {
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(
        phoneE164: '+96170100200',
        name: 'Sami',
      ));
      final cubit = _buildCubit(
        repo: repo,
        account: _ScriptedAccountService(
          signOutOutcome: AccountActionOutcome.networkError,
        ),
      );
      await cubit.load();
      await cubit.signOut();
      expect(cubit.state.banner, SettingsBanner.signedOut);
      expect(cubit.state.profile.name, isNull);
      expect((await repo.load())?.name, isNull);
    });
  });

  group('SettingsCubit — F3 unregister as jeeber', () {
    test('success latches jeeberUnregistered and shows the done banner',
        () async {
      final service = FakeJeeberUnregisterService();
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      expect(cubit.state.jeeberUnregistered, isTrue);
      expect(cubit.state.isUnregisteringJeeber, isFalse);
      expect(cubit.state.banner, SettingsBanner.jeeberUnregistered);
      expect(service.calls, 1);
    });

    test('notAJeeber (idempotent replay) also latches the done banner',
        () async {
      final service = FakeJeeberUnregisterService(
        outcome: JeeberUnregisterOutcome.notAJeeber,
      );
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      expect(cubit.state.jeeberUnregistered, isTrue);
      expect(cubit.state.banner, SettingsBanner.jeeberUnregistered);
    });

    test('activeDelivery blocks without latching jeeberUnregistered',
        () async {
      final service = FakeJeeberUnregisterService(
        outcome: JeeberUnregisterOutcome.activeDelivery,
      );
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      expect(cubit.state.jeeberUnregistered, isFalse);
      expect(cubit.state.banner, SettingsBanner.jeeberUnregisterActiveDelivery);
    });

    test('positiveBalance blocks without latching jeeberUnregistered',
        () async {
      final service = FakeJeeberUnregisterService(
        outcome: JeeberUnregisterOutcome.positiveBalance,
      );
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      expect(cubit.state.jeeberUnregistered, isFalse);
      expect(
        cubit.state.banner,
        SettingsBanner.jeeberUnregisterPositiveBalance,
      );
    });

    test('a 502 dark path shows "temporarily unavailable", not success',
        () async {
      final service = FakeJeeberUnregisterService(
        outcome: JeeberUnregisterOutcome.unavailable,
      );
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      expect(cubit.state.jeeberUnregistered, isFalse);
      expect(cubit.state.banner, SettingsBanner.jeeberUnregisterUnavailable);
    });

    test('a generic network error surfaces the shared network-error banner',
        () async {
      final service = FakeJeeberUnregisterService(
        outcome: JeeberUnregisterOutcome.networkError,
      );
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      expect(cubit.state.banner, SettingsBanner.networkError);
    });

    test('no service wired degrades to "temporarily unavailable" (bare host)',
        () async {
      final cubit = _buildCubit();
      await cubit.unregisterAsJeeber();
      expect(cubit.state.jeeberUnregistered, isFalse);
      expect(cubit.state.banner, SettingsBanner.jeeberUnregisterUnavailable);
    });

    test('does not double-submit while a call is in flight', () async {
      final service = FakeJeeberUnregisterService();
      final cubit = _buildCubit(unregisterService: service);
      final a = cubit.unregisterAsJeeber();
      final b = cubit.unregisterAsJeeber();
      await Future.wait([a, b]);
      expect(service.calls, 1);
    });

    test('short-circuits once jeeberUnregistered has already latched',
        () async {
      final service = FakeJeeberUnregisterService();
      final cubit = _buildCubit(unregisterService: service);
      await cubit.unregisterAsJeeber();
      await cubit.unregisterAsJeeber();
      expect(service.calls, 1);
    });
  });

  group('SettingsCubit — banner lifecycle', () {
    test('dismissBanner is a no-op when nothing is showing', () {
      final cubit = _buildCubit();
      cubit.dismissBanner();
      expect(cubit.state.banner, SettingsBanner.none);
    });

    test('dismissBanner clears the active banner', () async {
      final cubit = _buildCubit();
      await cubit.load();
      await cubit.saveProfile(name: 'Sami');
      expect(cubit.state.banner, SettingsBanner.profileSaved);
      cubit.dismissBanner();
      expect(cubit.state.banner, SettingsBanner.none);
    });
  });
}
