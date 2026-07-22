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
