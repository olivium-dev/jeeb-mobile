import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
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
  String fallbackPhone = '+96170100200',
}) {
  final cubit = SettingsCubit(
    profileRepository: repo ?? InMemoryProfileRepository(),
    accountService: account ?? _ScriptedAccountService(),
    displayNameRepository: displayNameRepo,
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
        'a failed remote mirror never fails the local save '
        '(fail-soft; the projection self-heals on the next getMe)', () async {
      final repo = InMemoryProfileRepository();
      final remote = _RecordingDisplayNameRepository(throws: true);
      final cubit = _buildCubit(repo: repo, displayNameRepo: remote);
      await cubit.load();
      await cubit.saveProfile(name: 'Ahmad');
      expect(cubit.state.profile.name, 'Ahmad');
      expect(cubit.state.banner, SettingsBanner.profileSaved);
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

    test('signOut leaves profile untouched on network error', () async {
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
      expect(cubit.state.banner, SettingsBanner.networkError);
      expect(cubit.state.profile.name, 'Sami');
      expect((await repo.load())?.name, 'Sami');
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
