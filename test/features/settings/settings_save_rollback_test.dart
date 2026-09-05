// LR-15 / F10: `saveProfile` emitted `profileSaved` unconditionally and left
// `isSavingProfile: true` when the repository threw; `removePhoto` claimed
// success for an avatar the backend still holds.
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/domain/avatar_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

import '../../support/settings_fakes.dart';

/// Reads succeed; the SAVE throws.
class _SaveFailingRepository implements ProfileRepository {
  _SaveFailingRepository(this._stored);

  UserProfile? _stored;

  @override
  Future<UserProfile?> load() async => _stored;

  @override
  Future<void> save(UserProfile profile) async =>
      throw const NetworkFailure(offline: true);

  @override
  Future<void> clear() async => _stored = null;
}

class _RejectingDisplayNameRepository implements DisplayNameRepository {
  _RejectingDisplayNameRepository(this.failure);

  final DisplayNameFailure failure;
  int calls = 0;

  @override
  Future<void> submitDisplayName(String name) async {
    calls++;
    throw DisplayNameRepositoryException(failure);
  }
}

void main() {
  const seed = UserProfile(
    phoneE164: '+96170100200',
    name: 'Sami',
    photoUrl: 'https://cdn/jeeb/avatar.png',
  );

  test('a throwing local save restores the previous profile and says so',
      () async {
    final cubit = SettingsCubit(
      profileRepository: _SaveFailingRepository(seed),
      accountService: const FakeAccountService(),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.saveProfile(name: 'Ahmad');

    expect(cubit.state.profile, seed);
    expect(cubit.state.isSavingProfile, isFalse);
    expect(cubit.state.banner, SettingsBanner.profileSaveFailed);
    expect(cubit.state.banner, isNot(SettingsBanner.profileSaved));
    expect(cubit.state.error, isA<NetworkFailure>());
  });

  test('an UNAUTHORIZED remote name rejection reverts the name', () async {
    final repo = InMemoryProfileRepository();
    await repo.save(seed);
    final remote = _RejectingDisplayNameRepository(
      DisplayNameFailure.unauthorized,
    );
    final cubit = SettingsCubit(
      profileRepository: repo,
      accountService: const FakeAccountService(),
      displayNameRepository: remote,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.saveProfile(name: 'Ahmad');

    expect(remote.calls, 1);
    expect(cubit.state.profile.name, 'Sami');
    expect(cubit.state.banner, SettingsBanner.profileSaveFailed);
  });

  test('a NETWORK remote name rejection keeps the local edit', () async {
    final repo = InMemoryProfileRepository();
    await repo.save(seed);
    final cubit = SettingsCubit(
      profileRepository: repo,
      accountService: const FakeAccountService(),
      displayNameRepository:
          _RejectingDisplayNameRepository(DisplayNameFailure.network),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.saveProfile(name: 'Ahmad');

    expect(cubit.state.profile.name, 'Ahmad');
    expect(cubit.state.banner, SettingsBanner.profileSaveFailed);
  });

  test('removePhoto restores photoUrl when the remote clear fails', () async {
    final repo = InMemoryProfileRepository();
    await repo.save(seed);
    final avatar = FakeAvatarRepository(
      removeFailure:
          const AvatarRepositoryException(AvatarUploadFailure.serverError),
    );
    final cubit = SettingsCubit(
      profileRepository: repo,
      accountService: const FakeAccountService(),
      avatarRepository: avatar,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.removePhoto();

    expect(avatar.removeCalls, 1);
    expect(cubit.state.profile.photoUrl, seed.photoUrl);
    expect((await repo.load())?.photoUrl, seed.photoUrl);
    expect(cubit.state.banner, SettingsBanner.avatarRemoveFailed);
    expect(cubit.state.isSavingProfile, isFalse);
  });
}
