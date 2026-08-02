// Shared dev-only fixtures for `ProfileEditScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_10_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/settings/presentation/screens/profile_edit_screen.dart`.
//
// The catalog owned a private `_FakeProfileRepository` / `_FakeAccountService`
// / `_sampleProfile()` plus a `_ProfileEditPreview` host. All of it moved here.
// The host is the part that must not be duplicated: this screen takes NO
// `cubit:` seam — it reads `SettingsCubit` from the ambient `BlocProvider` and
// seeds its name field ONCE in `initState` — so *when* the host mounts the
// screen relative to `SettingsCubit.load()` decides what the screen shows.
// Two surfaces each choosing that moment for themselves would be two different
// screens wearing the same name.
//
// Everything here is a LOCAL fake over the `ProfileRepository` /
// `AccountService` interfaces. `SharedPrefsProfileRepository`,
// `DioAccountService` and `DioDisplayNameRepository` — the three collaborators
// `app_router.dart` hands the real cubit — are never constructed, and
// `displayNameRepository` is left null so no state can reach
// `PUT /api/User/profile`. Network-free by construction, not merely by the
// guard the preview host installs.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

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
///
/// The microtask matters. `SharedPrefsProfileRepository` resolves in
/// milliseconds, not instantly, and this fake reproduces that ordering: a host
/// that mounts the screen without awaiting `load()` sees exactly what the real
/// route sees on its first frame.
///
/// Mutable on purpose — a designer who taps Save in the catalog should see the
/// value stick.
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
///
/// [SettingsCubit.load] emits `isLoading: true` and then waits, so this pins
/// the screen on the frame it mounts in — which is the interesting one here,
/// because `ProfileEditScreen` renders no loading affordance of any kind.
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
///
/// `SettingsCubit.saveProfile` emits `isSavingProfile: true` before it awaits
/// the write and clears the flag after, so a write that never returns is the
/// only way to hold the "Saving…" button state still.
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
/// screen off the gateway.
class ProfileEditScreenFakeAccountService implements AccountService {
  const ProfileEditScreenFakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async =>
      AccountActionOutcome.success;

  @override
  Future<AccountActionOutcome> signOut() async => AccountActionOutcome.success;
}

// ── The designed profiles. ───────────────────────────────────────────────────
//
// Every profile carries a DISTINCT name and a DISTINCT phone number. Both dev
// surfaces render the same screen behind the same app bar, so the only thing
// that tells two states apart is their content — and a render test that pinned
// a string two fixtures shared would pass with a preview wired to the wrong
// fake.

/// The ordinary account: a name on file, a Lebanese mobile, no avatar.
const UserProfile profileEditScreenSavedProfile = UserProfile(
  phoneE164: '+96170123456',
  name: 'Maya Haddad',
);

/// A phone-only signup that never finished the profile-name step: the phone is
/// all Jeeb knows. `name == null` is what puts the `?` in the avatar and
/// leaves the name field empty.
const UserProfile profileEditScreenNoNameProfile = UserProfile(
  phoneE164: '+96176554433',
);

/// The only profile with a `photoUrl`, and therefore the only state that
/// renders `profile_edit_remove_avatar_cta`.
///
/// The path is the shape `AppDirProfilePhotoStore.persist` actually writes —
/// an absolute file path under the app documents directory, with the iOS
/// container UUID that a reinstall regenerates. It does not exist, so
/// `ProfileAvatar` takes its `Image.file` → `errorBuilder` branch and degrades
/// to the initial bubble. That keeps the state network-free: a `https:` avatar
/// would be the one fixture that reaches `OmdsCachedImage`.
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
/// TIMING, so this is deliberately an ordinary account with its own phone.
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
/// E.164 shape Jeeb issues.
///
/// Not a synthetic stress test — Arabic names are the majority case for this
/// app, and this one is 36 characters, which lays out at 576 dp against the
/// 318 dp of editable width a 390 dp phone gives the field. It is the fixture
/// that answers whether the name field, the read-only phone row and the three
/// stacked CTAs still hold at 200% text and mirrored.
const UserProfile profileEditScreenLongProfile = UserProfile(
  phoneE164: '+9613000077221',
  name: 'عبد الرحمن المهندس الطرابلسي بن يوسف',
);

// ── The host. ────────────────────────────────────────────────────────────────

/// Mounts [child] (a `ProfileEditScreen`) under a [SettingsCubit] built from
/// [repository], and owns the cubit's lifetime.
///
/// The screen has no `cubit:` constructor seam: `_ProfileEditScreenState`
/// reaches for `context.read<SettingsCubit>()` in `initState` and seeds its
/// `TextEditingController` from whatever `state.profile.name` is AT THAT
/// MOMENT — after which nothing ever re-syncs it. So the one knob that decides
/// what this screen looks like is [awaitLoad]:
///
///   * `true` — mount only once `load()` has resolved. The name field starts
///     populated. This is the state the catalog has always shown.
///   * `false` — mount immediately and let `load()` land underneath, which is
///     what `app_router.dart` does (`SettingsCubit(...)..load()` in the route
///     builder, with `ProfileEditScreen` as its direct child). The name field
///     starts — and stays — EMPTY.
///
/// Both are real; only the second is what a user sees. Keeping the knob here
/// rather than in each surface is the whole reason this host is shared.
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
  /// requires the preview section to build the widget it is named after, and a
  /// designer reading the catalog entry should see which screen it opens.
  final Widget child;

  /// Whether to wait for `load()` before the first build. See the class doc —
  /// this is the difference between the catalog's historical picture and the
  /// production one.
  final bool awaitLoad;

  /// When set, `saveProfile(name:)` is dispatched immediately after mount.
  /// Paired with [ProfileEditScreenPendingSaveRepository] this holds the
  /// screen on its in-flight save.
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
    // path. Not a loading state — the screen has none; see the preview prose.
    if (cubit == null) return const SizedBox.shrink();
    return BlocProvider<SettingsCubit>.value(value: cubit, child: widget.child);
  }
}
