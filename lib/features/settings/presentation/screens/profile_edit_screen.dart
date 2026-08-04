import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../photo_attachment/data/image_picker_photo_picker_service.dart';
import '../../../photo_attachment/domain/photo_compressor.dart';
import '../../../photo_attachment/domain/photo_picker_service.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../../data/profile_photo_store.dart';
import '../widgets/profile_avatar.dart';

/// Profile edit screen (T-mobile-031).
///
/// Two editable fields: display name and avatar. Phone number is rendered
/// read-only because changing it requires re-running phone+OTP registration
/// (T-mobile-002). Talks to the screen-wide [SettingsCubit] so the same
/// state powers the parent settings list — there is no separate
/// `ProfileCubit`.
///
/// redesign-2026-08: re-skinned onto the Jeeb system to match its parent
/// (screen 20, `settings_screen.dart`). Bands, top to bottom: in-body
/// [JeebTopBar] → avatar hero + its two text actions → name field →
/// `PROFILE` label + the outlined read-only phone row → a real empty band →
/// the docked [JeebCtaFooter] Save pill. The flow, the copy and every
/// `Semantics(identifier:)` are unchanged.
///
/// MIDNIGHT M3-23 (ORPHAN ruling KEEP+restyle): it now mounts R22's own field —
/// `content` variant, orange glow top-end, decor still — instead of falling
/// back to the flat scaffold navy, so pushing here from Settings does not drop
/// the glow. It also gained the loading frame it never had, which is what
/// fixes the empty-name-field defect described on [_ProfileEditScreenState].
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

  /// Frozen identifier for the cold-read frame.
  static const String loadingIdentifier = 'profile_edit_loading';

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

/// The live route builds its `SettingsCubit` with a trailing `..load()`, which
/// emits `isLoading: true` synchronously and resolves the profile a microtask
/// later — so [initState] used to seed the name controller from an empty
/// profile and never re-read it. Real accounts opened Edit profile to a blank
/// name field; the catalog masked it with `awaitLoad: true`. The screen now
/// withholds the form until the read lands and seeds the controller then.
class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController;
  String? _validationError;
  bool _isChangingPhoto = false;
  late bool _nameSeeded;

  @override
  void initState() {
    super.initState();
    final state = context.read<SettingsCubit>().state;
    _nameSeeded = !state.isLoading;
    _nameController = TextEditingController(
      text: _nameSeeded ? state.profile.name ?? '' : '',
    );
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
      listenWhen: (prev, curr) =>
          prev.banner != curr.banner || (prev.isLoading && !curr.isLoading),
      listener: (context, state) {
        if (!state.isLoading && !_nameSeeded) {
          _nameSeeded = true;
          _nameController.text = state.profile.name ?? '';
        }
        if (state.banner == SettingsBanner.profileSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.profileSaved)),
          );
          context.read<SettingsCubit>().dismissBanner();
        }
      },
      builder: (context, state) {
        return JeebMidnightField(
          // R22's field, carried across unchanged: one orange radial top-end
          // (`88% -6%`), no periwinkle wash, and the tile is board-still.
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              // The docked footer owns the bottom inset (same split as
              // settings_screen.dart), so the scroll body must not claim it.
              bottom: false,
              child: Column(
                children: [
                  // In-body top bar — the parent screen's header, not an
                  // `AppBar`. Default `onLeadingPressed` is the guarded
                  // `Navigator.maybePop()` OMDSAppBar used, so back is
                  // unchanged.
                  JeebTopBar.back(
                    title: l10n.profileEditTitle,
                    identifier: 'profile_edit_back',
                  ),
                  if (state.isLoading)
                    const Expanded(child: Center(child: _ProfileEditLoading()))
                  else ...[
                    Expanded(
                      child: ListView(
                        // 24px gutters (plan §4.3); the residual space below
                        // the last band is the board's real empty band — the
                        // footer is docked, not last.
                        padding: const EdgeInsetsDirectional.only(
                          start: Spacing.xLarge,
                          end: Spacing.xLarge,
                          top: Spacing.medium,
                          bottom: Spacing.large,
                        ),
                        children: [
                          _ProfileAvatarBlock(
                            state: state,
                            isChangingPhoto: _isChangingPhoto,
                            onChangePhoto: () => _onChangePhoto(l10n),
                          ),
                          const SizedBox(height: Spacing.xLarge),
                          _NameField(
                            controller: _nameController,
                            errorText: _validationError,
                            label: l10n.profileNameLabel,
                            hint: l10n.profileNameHint,
                          ),
                          const SizedBox(height: Spacing.xLarge),
                          _PhoneSection(phoneE164: state.profile.phoneE164),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: JeebCtaFooter.single(
                        child: Semantics(
                          identifier: 'profile_edit_save_cta',
                          button: true,
                          container: true,
                          child: JeebCtaButton.primary(
                            key: const Key('profile-edit-save'),
                            label: state.isSavingProfile
                                ? l10n.profileSaving
                                : l10n.profileSave,
                            isEnabled: !state.isSavingProfile,
                            onTap: () => _onSave(l10n),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The cold profile read. `radar` for the reason M3-22 named on
/// `account_status`: an account listening for a signal, not a request. Its
/// three identity discs are dropped — there is no second party on this surface.
class _ProfileEditLoading extends StatelessWidget {
  const _ProfileEditLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      variant: JeebEmptyStateVariant.radar,
      status: JeebEmptyStateStatus.loading,
      medallions: const <JeebEmptyMedallion>[],
      identifier: ProfileEditScreen.loadingIdentifier,
      headline: l10n.profileEditLoadingHeadline,
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
        // Still [ProfileAvatar], NOT JeebAvatar: a just-picked avatar is an
        // absolute on-device path and JeebAvatar composes OmdsProfileAvatar,
        // which renders through the network-only OmdsCachedImage. Swapping it
        // would blank the photo on the very screen that picks it (JEBV4-13).
        // The kit's hero diameter keeps the disc on the system's scale.
        ProfileAvatar(
          name: state.profile.name,
          photoUrl: state.profile.photoUrl,
          diameter: JeebAvatar.heroDiameter,
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'profile_edit_change_avatar_cta',
          button: true,
          container: true,
          child: JeebCtaButton.text(
            key: const Key('profile-edit-change-avatar'),
            label: l10n.profileAvatarChange,
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
            // Destructive, so it takes R22's docked-footer treatment verbatim
            // (`settings_footer.dart`): a bare danger-SOFT `onErrorContainer`
            // label, never full-strength `error` and never a filled pill.
            child: TextButton(
              key: const Key('profile-edit-remove-avatar'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                textStyle: context.jeebText.bodySmall,
              ),
              onPressed: state.isSavingProfile
                  ? null
                  : () => context.read<SettingsCubit>().removePhoto(),
              child: Text(l10n.profileAvatarRemove),
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
      // MIDNIGHT: the pass-1 note here ("OmdsTextField already reads the
      // theme") is FALSE — omds hard-codes `colorScheme.primary` on the
      // floating label and focus ring, i.e. orange. 40 call sites; see the row
      // report, not a per-screen patch.
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

/// The read-only phone band: `PROFILE` section label + a single outlined row.
///
/// It states a fact rather than navigating, so there is no chevron and no tap
/// target — the padlock is the whole affordance story (screen 20's always-on
/// security-codes row uses the same treatment).
class _PhoneSection extends StatelessWidget {
  const _PhoneSection({required this.phoneE164});

  /// Trailing padlock size, matching the board's `tpl 1212` glyph.
  static const double lockGlyphSize = 17;

  final String phoneE164;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The row's own muted ink, read the way every kit child reads it: this
    // survives a bare test theme with no JeebSemanticColors registered, and
    // re-inks itself if the row ever lands on a navy surface.
    final muted = JeebSurfaceTone.of(context).mutedInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.profileTitle),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            JeebListRow(
              key: const Key('profile-edit-phone-readonly'),
              icon: Icons.phone,
              title: phoneE164.isEmpty ? '—' : phoneE164,
              showChevron: false,
              trailing: Icon(
                // Deliberately the outline glyph, not R10's filled one: a
                // shipped test pins `Icons.lock_outline` as the read-only mark.
                Icons.lock_outline,
                size: lockGlyphSize,
                color: muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
