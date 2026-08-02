// Shared dev-only fixtures for `ProfileEditScreen`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

// ── The repositories. ────────────────────────────────────────────────────────

/// In-memory [ProfileRepository]: `load()` resolves to [stored] on the next
/// microtask, and `save()` replaces it.
/// The microtask matters. `SharedPrefsProfileRepository` resolves in
class ProfileEditScreenFakeProfileRepository implements ProfileRepository {
  ProfileEditScreenFakeProfileRepository([this._stored]);

  UserProfile? _stored;

  /// What the last `save()` (or the constructor) left behind.
  UserProfile? get stored => _stored;

  @override
  Future<UserProfile?> load() async => _stored;

  @override
  Future<void> save(UserProfile profile) async {
    _stored = profile;
  }

  @override
  Future<void> clear() async {
    _stored = const UserProfile.empty();
  }
}

/// A profile read that never lands.
/// [SettingsCubit.load] emits `isLoading: true` and then waits, so this pins
/// the screen on the frame it mounts in — which is the interesting one here,
class ProfileEditScreenPendingLoadRepository implements ProfileRepository {
  const ProfileEditScreenPendingLoadRepository();

  @override
  Future<UserProfile?> load() => Completer<UserProfile?>().future;

  @override
  Future<void> save(UserProfile profile) async {}

  @override
  Future<void> clear() async {}
}

/// Loads [stored] normally, then never finishes writing.
/// `SettingsCubit.saveProfile` emits `isSavingProfile: true` before it awaits
/// the write and clears the flag after, so a write that never returns is the
class ProfileEditScreenPendingSaveRepository implements ProfileRepository {
  const ProfileEditScreenPendingSaveRepository(this.stored);

  /// What `load()` resolves to before the save is started.
  final UserProfile stored;

  @override
  Future<UserProfile?> load() async => stored;

  @override
  Future<void> save(UserProfile profile) => Completer<void>().future;

  @override
  Future<void> clear() async {}
}

/// Scripted [AccountService]. `ProfileEditScreen` never calls either method —
/// sign-out and delete-account live on the parent settings list — but
/// [SettingsCubit] requires one, so this is the null object that keeps the
class ProfileEditScreenFakeAccountService implements AccountService {
  const ProfileEditScreenFakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async =>
      AccountActionOutcome.success;

  @override
  Future<AccountActionOutcome> signOut() async => AccountActionOutcome.success;
}

// ── The designed profiles. ───────────────────────────────────────────────────

/// The ordinary account: a name on file, a Lebanese mobile, no avatar.
const UserProfile profileEditScreenSavedProfile = UserProfile(
  phoneE164: '+96170123456',
  name: 'Maya Haddad',
);

/// A phone-only signup that never finished the profile-name step: the phone is
/// all Jeeb knows. `name == null` is what puts the `?` in the avatar and
const UserProfile profileEditScreenNoNameProfile = UserProfile(
  phoneE164: '+96176554433',
);

/// The only profile with a `photoUrl`, and therefore the only state that
/// renders `profile_edit_remove_avatar_cta`.
const UserProfile profileEditScreenPhotoProfile = UserProfile(
  phoneE164: '+96171998877',
  name: 'Karim Aoun',
  photoUrl: profileEditScreenStalePhotoPath,
);

/// See [profileEditScreenPhotoProfile].
const String profileEditScreenStalePhotoPath =
    '/var/mobile/Containers/Data/Application/'
    '8B4E9F2A-1C3D-4E5F-9A7B-2D6C8E0F1A3B/Documents/'
    'profile_avatar_1754136000000.jpg';

/// The profile used for the "loads after the screen has already mounted"
/// state. Nothing about it is unusual — the point of that state is the
const UserProfile profileEditScreenLateProfile = UserProfile(
  phoneE164: '+96181234567',
  name: 'Rania Nasrallah',
);

/// The profile a save is driven from.
const UserProfile profileEditScreenSavingProfile = UserProfile(
  phoneE164: '+96179445566',
  name: 'Nour Chamoun',
);

/// The layout ceiling: a full Arabic name as people actually write them
/// (given + patronymic + family + nisba) against a phone number in the longest
const UserProfile profileEditScreenLongProfile = UserProfile(
  phoneE164: '+9613000077221',
  name: 'عبد الرحمن المهندس الطرابلسي بن يوسف',
);

// ── The host. ────────────────────────────────────────────────────────────────

/// Mounts [child] (a `ProfileEditScreen`) under a [SettingsCubit] built from
/// [repository], and owns the cubit's lifetime.
/// The screen has no `cubit:` constructor seam: `_ProfileEditScreenState`
class ProfileEditScreenPreviewHost extends StatefulWidget {
  const ProfileEditScreenPreviewHost({
    super.key,
    required this.repository,
    required this.child,
    this.awaitLoad = true,
    this.saveOnMount,
  });

  /// The profile store the cubit is built over. Always a fake from this file.
  final ProfileRepository repository;

  /// The screen under review. Supplied by the caller so BOTH surfaces
  /// construct `ProfileEditScreen` themselves — the preview-coverage detector
  final Widget child;

  /// Whether to wait for `load()` before the first build. See the class doc —
  /// this is the difference between the catalog's historical picture and the
  final bool awaitLoad;

  /// When set, `saveProfile(name:)` is dispatched immediately after mount.
  /// Paired with [ProfileEditScreenPendingSaveRepository] this holds the
  final String? saveOnMount;

  @override
  State<ProfileEditScreenPreviewHost> createState() =>
      _ProfileEditScreenPreviewHostState();
}

class _ProfileEditScreenPreviewHostState
    extends State<ProfileEditScreenPreviewHost> {
  SettingsCubit? _cubit;

  @override
  void initState() {
    super.initState();
    final cubit = SettingsCubit(
      profileRepository: widget.repository,
      accountService: const ProfileEditScreenFakeAccountService(),
    );
    if (widget.awaitLoad) {
      unawaited(_mountWhenLoaded(cubit));
      return;
    }
    _cubit = cubit;
    unawaited(cubit.load());
    _driveSave(cubit);
  }

  Future<void> _mountWhenLoaded(SettingsCubit cubit) async {
    await cubit.load();
    if (!mounted) {
      await cubit.close();
      return;
    }
    setState(() => _cubit = cubit);
    _driveSave(cubit);
  }

  void _driveSave(SettingsCubit cubit) {
    final name = widget.saveOnMount;
    if (name != null) unawaited(cubit.saveProfile(name: name));
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    // One frame of nothing while `load()` resolves, only on the awaitLoad
    if (cubit == null) return const SizedBox.shrink();
    return BlocProvider<SettingsCubit>.value(value: cubit, child: widget.child);
  }
}
