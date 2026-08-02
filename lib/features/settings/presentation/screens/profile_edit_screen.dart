import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../photo_attachment/data/image_picker_photo_picker_service.dart';
import '../../../photo_attachment/domain/photo_compressor.dart';
import '../../../photo_attachment/domain/photo_picker_service.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../../data/profile_photo_store.dart';
import '../widgets/profile_avatar.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/profile_edit_screen_fixtures.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../domain/profile_repository.dart';

/// Profile edit screen (T-mobile-031).
///
/// Two editable fields: display name and avatar. Phone number is rendered
/// read-only because changing it requires re-running phone+OTP registration
/// (T-mobile-002). Talks to the screen-wide [SettingsCubit] so the same
/// state powers the parent settings list — there is no separate
/// `ProfileCubit`.
// ORPHAN (JEBV4-227, verified 2026-07-12): only reachable via orphaned /settings — see docs/project-understanding/reconciliation/orphans.md
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    this.photoPicker,
    this.photoStore,
    this.photoCompressor = const HalvingPhotoCompressor(),
  });

  /// JEBV4-13 test seams for the Change-avatar flow. Production resolves the
  /// picker from DI (falling back to the real `image_picker` adapter) and
  /// persists via [AppDirProfilePhotoStore].
  final PhotoPickerService? photoPicker;
  final ProfilePhotoStore? photoStore;
  final PhotoCompressor photoCompressor;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController;
  String? _validationError;
  bool _isChangingPhoto = false;

  @override
  void initState() {
    super.initState();
    final initialName = context.read<SettingsCubit>().state.profile.name ?? '';
    _nameController = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onSave(AppLocalizations l10n) {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      setState(() => _validationError = l10n.profileNameRequired);
      return;
    }
    setState(() => _validationError = null);
    context.read<SettingsCubit>().saveProfile(name: value);
  }

  /// Resolve the picker: injected seam → DI registration → the real
  /// `image_picker` adapter (the dependency-free default that makes the CTA
  /// honest — JEBV4-13; previously `onTap: () {}`).
  PhotoPickerService _resolvePicker() {
    final injected = widget.photoPicker;
    if (injected != null) return injected;
    if (sl.isRegistered<PhotoPickerService>()) return sl<PhotoPickerService>();
    return ImagePickerPhotoPickerService();
  }

  /// JEBV4-13: the Change-avatar flow — camera/gallery source sheet →
  /// platform pick → compress (2 MB ceiling) → persist locally → save on the
  /// profile. Cancelling anywhere is silent; real failures surface honestly.
  Future<void> _onChangePhoto(AppLocalizations l10n) async {
    if (_isChangingPhoto) return;
    final cubit = context.read<SettingsCubit>();
    // Same OMDS sheet + choice-key repurposing as the onboarding photo step
    // (dm_onboarding_photo_upload_card.dart): 'photo' → camera, 'video' →
    // gallery; only the localized labels are visible.
    final choice = await OmdsMediaPickerSheet.show(
      context,
      title: l10n.profileAvatarChange,
      subtitle: l10n.profilePhotoSheetSubtitle,
      photoLabel: l10n.dmOnboardingPhotoUploadCameraLabel,
      videoLabel: l10n.dmOnboardingPhotoUploadGalleryLabel,
      cancelLabel: l10n.actionCancel,
    );
    if (choice != 'photo' && choice != 'video') return;
    setState(() => _isChangingPhoto = true);
    try {
      final picker = _resolvePicker();
      final raw = choice == 'photo'
          ? await picker.pickFromCamera()
          : await picker.pickFromGallery();
      final compressed = await widget.photoCompressor.compress(raw.bytes);
      final store = widget.photoStore ?? const AppDirProfilePhotoStore();
      final path = await store.persist(compressed);
      await cubit.saveProfile(name: cubit.state.profile.name, photoUrl: path);
    } on PhotoPickException catch (e) {
      if (e.failure != PhotoPickFailure.cancelled && mounted) {
        showOmdsErrorSnackbar(
          context,
          message: e.failure == PhotoPickFailure.permissionDenied
              ? l10n.profilePhotoPermissionDenied
              : l10n.profilePhotoChangeFailed,
        );
      }
    } catch (_) {
      if (mounted) {
        showOmdsErrorSnackbar(context, message: l10n.profilePhotoChangeFailed);
      }
    } finally {
      if (mounted) setState(() => _isChangingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) => prev.banner != curr.banner,
      listener: (context, state) {
        if (state.banner == SettingsBanner.profileSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.profileSaved)),
          );
          context.read<SettingsCubit>().dismissBanner();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: OMDSAppBar(
            title: l10n.profileEditTitle,
            showBackButton: true,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Spacing.medium),
              children: [
                _ProfileAvatarBlock(
                  state: state,
                  isChangingPhoto: _isChangingPhoto,
                  onChangePhoto: () => _onChangePhoto(l10n),
                ),
                const SizedBox(height: Spacing.large),
                _NameField(
                  controller: _nameController,
                  errorText: _validationError,
                  label: l10n.profileNameLabel,
                  hint: l10n.profileNameHint,
                ),
                const SizedBox(height: Spacing.large),
                _PhoneRow(phoneE164: state.profile.phoneE164),
                const SizedBox(height: Spacing.large),
                Semantics(
                  identifier: 'profile_edit_save_cta',
                  button: true,
                  container: true,
                  child: OmdsPrimaryButton(
                    key: const Key('profile-edit-save'),
                    text: state.isSavingProfile
                        ? l10n.profileSaving
                        : l10n.profileSave,
                    isEnabled: !state.isSavingProfile,
                    onTap: () => _onSave(l10n),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileAvatarBlock extends StatelessWidget {
  const _ProfileAvatarBlock({
    required this.state,
    required this.isChangingPhoto,
    required this.onChangePhoto,
  });

  final SettingsState state;
  final bool isChangingPhoto;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        ProfileAvatar(
          name: state.profile.name,
          photoUrl: state.profile.photoUrl,
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'profile_edit_change_avatar_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            key: const Key('profile-edit-change-avatar'),
            text: l10n.profileAvatarChange,
            variant: OmdsButtonVariant.text,
            isEnabled: !state.isSavingProfile && !isChangingPhoto,
            // JEBV4-13: was `onTap: () {}` — a dead CTA on a primary profile
            // affordance. Now opens the camera/gallery source sheet and saves
            // the picked photo (see _onChangePhoto).
            onTap: onChangePhoto,
          ),
        ),
        if (state.profile.photoUrl != null)
          Semantics(
            identifier: 'profile_edit_remove_avatar_cta',
            button: true,
            container: true,
            child: OmdsPrimaryButton(
              key: const Key('profile-edit-remove-avatar'),
              text: l10n.profileAvatarRemove,
              variant: OmdsButtonVariant.text,
              isEnabled: !state.isSavingProfile,
              onTap: () => context.read<SettingsCubit>().removePhoto(),
            ),
          ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.errorText,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String? errorText;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'profile_edit_name_field',
      textField: true,
      container: true,
      child: OmdsTextField(
        key: const Key('profile-edit-name'),
        controller: controller,
        labelText: label,
        hintText: hint,
        errorText: errorText,
        isRequired: true,
        textCapitalization: TextCapitalization.words,
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phoneE164});

  final String phoneE164;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsSettingsSection(
      title: AppLocalizations.of(context).profileTitle,
      children: [
        OmdsSettingsRow(
          key: const Key('profile-edit-phone-readonly'),
          title: phoneE164.isEmpty ? '—' : phoneE164,
          leadingIcon: Icons.phone_outlined,
          leadingIconColor: colorScheme.onSurfaceVariant,
          icon: Icons.lock_outline,
        ),
      ],
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/settings/profile_edit_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so two things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([_profileEditScreenPhoneBox], 390x844) rather than the harness's default
//    390x200 — a form with an avatar, a field, a row and three CTAs cannot be
//    judged in a 200 pt strip.
//
// 2. It builds without a `Router`. `OMDSAppBar`'s back arrow falls back to
//    `Navigator.maybePop`, which the canvas's own `MaterialApp` satisfies, and
//    nothing else on the screen navigates. No local `GoRouter` is needed.
//
// **There is no `cubit:` seam, and that is the whole story of this screen.**
// `_ProfileEditScreenState.initState` reaches for `context.read<SettingsCubit>()`
// and seeds its `TextEditingController` from `state.profile.name` AT THAT
// MOMENT — after which nothing re-syncs it. So what this screen shows is
// decided not by a state object but by WHEN it is mounted relative to
// `SettingsCubit.load()`. Both orderings are previewed, from the same shared
// host (`lib/devtool/catalog/fixtures/profile_edit_screen_fixtures.dart`,
// `awaitLoad:`) as the Screen Catalog entry. Every fixture is a local fake
// over `ProfileRepository`; `SharedPrefsProfileRepository`, `DioAccountService`
// and `DioDisplayNameRepository` — the three collaborators `app_router.dart`
// hands the real cubit — are never constructed, so these are network-free by
// construction rather than by the guard in [jeebPreviewHost].
//
// What these previews surfaced in the screen:
//
//  * **The name field is blank for every real user.** `app_router.dart` builds
//    `SettingsCubit(...)..load()` in the route builder with `ProfileEditScreen`
//    as its direct child, so `initState` runs while the profile is still
//    `UserProfile.empty()` and seeds the controller with `''`. When the read
//    lands a frame later the avatar and the phone row update — they read
//    `state` in `build` — and the name field does not, because a
//    `TextEditingController` is not part of the rebuilt tree. `Loads after
//    mount · the name field stays blank` is that frame. A user whose name is
//    on file opens "Edit profile", sees an empty Name, and either retypes it or
//    taps Save and is told "Please enter your name."
//  * **There is no loading state and no error state.** `SettingsState.isLoading`
//    is never read by this screen, so a profile read that is slow (`Never
//    loads · the screen has no loading state`) presents a fully interactive,
//    empty, *savable* form with `—` where the phone belongs. And
//    `SettingsCubit.load()` does not catch: a repository that throws leaves the
//    screen on that identical picture forever, with the exception surfacing as
//    an unhandled async error rather than as anything the user can see or
//    retry. There is no third picture to preview for the failure — that IS the
//    finding.
//  * **Save silently deletes the avatar.** `_onSave` calls
//    `saveProfile(name: value)` with no `photoUrl`, which defaults to `null`,
//    and `UserProfile.copyWith` distinguishes "omitted" from `null` by a
//    sentinel — so an explicit `null` CLEARS the field. Open `Photo on file ·
//    remove offered`, tap Save, and `profile_edit_remove_avatar_cta` vanishes
//    with the photo. `removePhoto()` and `_onChangePhoto` both pass the name
//    through explicitly; the name-only path is the one that does not, and it is
//    pinned in the render test.
//  * **`isRequired: true` gives the field a SECOND, unlocalized error.**
//    `OmdsTextField` auto-validates on change and emits a hardcoded English
//    "This field is required" when it is cleared, which is not the screen's own
//    localized `profileNameRequired` and does not translate in the AR
//    rendering. Both can be produced within two taps of each other.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _profileEditScreenPhoneBox = Size(390, 844);

/// One specimen, built with the JEBV4-13 photo seams filled so the Change-
/// avatar CTA is honest in the canvas.
///
/// Without them `_resolvePicker()` falls through DI to
/// `ImagePickerPhotoPickerService` and a tap would reach for the real
/// `image_picker` platform channel; with them the tap runs the whole flow —
/// source sheet, canned bytes, compress, persist — against in-memory doubles
/// that already ship in `lib/` for exactly this purpose.
Widget _profileEditScreenHosted(
  ProfileRepository repository, {
  bool awaitLoad = true,
  String? saveOnMount,
}) {
  return ProfileEditScreenPreviewHost(
    repository: repository,
    awaitLoad: awaitLoad,
    saveOnMount: saveOnMount,
    child: ProfileEditScreen(
      photoPicker: StubPhotoPickerService(),
      photoStore: FakeProfilePhotoStore(),
    ),
  );
}

/// The designed state: a saved profile, mounted after the read landed.
///
/// This is the screen as it was drawn — name in the field, phone in the
/// read-only row under a padlock, one primary CTA. It is what the Screen
/// Catalog has always shown and it is NOT what a user gets (see `Loads after
/// mount`); keeping both is the point.
///
/// Matrixed because this is the reference rendering. The AR pass is where the
/// padlock/phone row mirrors while the E.164 number stays LTR, and where the
/// field label and the three stacked CTAs are re-measured against longer copy.
///
/// The 200% pass is where the two halves of the form disagree. Measured off
/// the render tree on the 390x844 box this preview declares: the name field
/// grows 48 → 72 dp with the type, and `OmdsPrimaryButton` stays 358x48 at
/// both scales — its height is `height ?? Sizes.fourXLarge`, a constant no
/// `TextScaler` touches. Nothing overflows today (a 32 dp label clears a 48 dp
/// pill by about 4 dp, the same arithmetic that saves `ProfileAvatar`), so
/// this is headroom rather than a defect — but it is arithmetic headroom, and
/// one step up the type ramp or one longer localized label spends it.
@JeebPreview(
  group: 'settings',
  name: 'Saved profile · name and phone',
  size: _profileEditScreenPhoneBox,
  matrix: true,
)
Widget profileEditScreenSaved() => _profileEditScreenHosted(
      ProfileEditScreenFakeProfileRepository(profileEditScreenSavedProfile),
    );

/// A phone-only signup that never finished the profile-name step.
///
/// The catalog's `Empty — No Name Yet`. `name == null` puts `?` in the avatar
/// and leaves the field empty, so this is the one state where both
/// `profileNameLabel` ("Name") and `profileNameHint` ("How should we address
/// you?") are painted at once — the hint being the longest single string on
/// the screen, and the only one that has to share a 358 dp box with a floating
/// label.
///
/// Also the state that proves the remove-avatar CTA is conditional: with no
/// `photoUrl` there is no `profile_edit_remove_avatar_cta`, which is what
/// `test/profile_edit_screen_test.dart` asserts.
@JeebPreview(
  group: 'settings',
  name: 'No name yet',
  size: _profileEditScreenPhoneBox,
)
Widget profileEditScreenNoNameYet() => _profileEditScreenHosted(
      ProfileEditScreenFakeProfileRepository(profileEditScreenNoNameProfile),
    );

/// The only state with a `photoUrl`, and so the only one that renders the
/// third CTA — `profile_edit_remove_avatar_cta`.
///
/// The stored path is the shape `AppDirProfilePhotoStore` writes and its file
/// is gone (a reinstall regenerates the iOS container UUID), so `ProfileAvatar`
/// degrades through `Image.file`'s `errorBuilder` to the same initial bubble as
/// "no photo at all" — the avatar block cannot tell you that the photo is
/// missing, only the presence of the Remove CTA can. Until that read lands
/// there is no glyph either: the `Image.file` branch has an `errorBuilder` but
/// no `frameBuilder`, where the network branch beside it has a `placeholder`,
/// so a set avatar is a bare 96 dp hole for the duration of the read.
///
/// This is the state the Save-wipes-the-photo defect lives in: tapping the
/// primary CTA here clears `photoUrl` and takes the Remove CTA with it, and
/// nothing on screen says so.
@JeebPreview(
  group: 'settings',
  name: 'Photo on file · remove offered',
  size: _profileEditScreenPhoneBox,
)
Widget profileEditScreenWithPhoto() => _profileEditScreenHosted(
      ProfileEditScreenFakeProfileRepository(profileEditScreenPhotoProfile),
    );

/// **The state every real user opens the screen in.**
///
/// `app_router.dart` mounts `ProfileEditScreen` in the same frame it builds
/// `SettingsCubit(...)..load()`, so this preview mounts first and lets the read
/// land underneath (`awaitLoad: false`). Once it settles the avatar shows `R`
/// and the phone row shows `+96181234567` — both are read from `state` in
/// `build` — while the Name field, seeded once in `initState` from the empty
/// profile, is still blank.
///
/// Compare it side by side with `Saved profile`: same fixture data, one frame
/// of difference in when the screen was mounted, and the only editable field on
/// the screen is empty in one and populated in the other.
@JeebPreview(
  group: 'settings',
  name: 'Loads after mount · the name field stays blank',
  size: _profileEditScreenPhoneBox,
)
Widget profileEditScreenLoadsAfterMount() => _profileEditScreenHosted(
      ProfileEditScreenFakeProfileRepository(profileEditScreenLateProfile),
      awaitLoad: false,
    );

/// A profile read that never lands — a cold start on a bad connection.
///
/// `SettingsState.isLoading` is true for the whole life of this preview and the
/// screen never reads it: no spinner, no skeleton, no disabled CTA. What it
/// draws instead is a complete, interactive form over a profile that does not
/// exist yet — `?` avatar, empty name, `—` for the phone, and a live Save
/// button that would write that empty profile back.
///
/// The failure branch has no picture of its own. `SettingsCubit.load()` awaits
/// the repository without a try/catch, so a read that THROWS leaves the screen
/// on exactly this frame, permanently, with the exception escaping as an
/// unhandled async error.
@JeebPreview(
  group: 'settings',
  name: 'Never loads · the screen has no loading state',
  size: _profileEditScreenPhoneBox,
)
Widget profileEditScreenNeverLoads() => _profileEditScreenHosted(
      const ProfileEditScreenPendingLoadRepository(),
      awaitLoad: false,
    );

/// A save in flight, held open by a write that never returns.
///
/// `isSavingProfile` is the one flag this screen does read, and it drives three
/// things: the CTA label flips to "Saving…", the CTA is disabled, and Change/
/// Remove avatar are disabled with it. Worth looking at rather than trusting:
/// `OmdsPrimaryButton` renders a disabled FILLED button as its own colour at
/// 45% alpha, so "Saving…" is a slightly paler pill and nothing else — there is
/// no progress indicator anywhere on this screen, and the text field stays
/// fully editable while the write is in flight.
@JeebPreview(
  group: 'settings',
  name: 'Saving · write in flight',
  size: _profileEditScreenPhoneBox,
)
Widget profileEditScreenSaving() => _profileEditScreenHosted(
      const ProfileEditScreenPendingSaveRepository(
        profileEditScreenSavingProfile,
      ),
      saveOnMount: 'Nour Chamoun',
    );

/// The layout ceiling: a full Arabic name (given + patronymic + family + nisba,
/// 36 characters) against the longest E.164 number Jeeb issues.
///
/// Not a synthetic stress test — Arabic names are the majority case for this
/// app. What it shows, measured on the 390x844 box this preview declares:
///
///   * EN light — the name lays out at 576 dp inside 318 dp of editable width,
///     so nearly half of it is off-screen at any moment. `maxLines: 1` is the
///     OMDS default and this screen does not override it, so the field scrolls
///     instead of wrapping and there is no ellipsis or any other mark saying
///     the name continues. A user cannot see their own name whole on the one
///     screen that exists to edit it.
///   * AR RTL dark — the field, the padlocked phone row and the CTAs all
///     mirror; the phone number itself stays LTR inside a mirrored row.
///   * EN 200% — the body is a `ListView`, so height is free. Nothing
///     overflows in either locale at either scale; the ceiling here is
///     legibility, not clipping.
@JeebPreview(
  group: 'settings',
  name: 'Ceiling · long Arabic name',
  size: _profileEditScreenPhoneBox,
  matrix: true,
)
Widget profileEditScreenLongName() => _profileEditScreenHosted(
      ProfileEditScreenFakeProfileRepository(profileEditScreenLongProfile),
    );
