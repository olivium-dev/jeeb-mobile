import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../widgets/profile_avatar.dart';

/// Profile edit screen (T-mobile-031).
///
/// Two editable fields: display name and avatar. Phone number is rendered
/// read-only because changing it requires re-running phone+OTP registration
/// (T-mobile-002). Talks to the screen-wide [SettingsCubit] so the same
/// state powers the parent settings list — there is no separate
/// `ProfileCubit`.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController;
  String? _validationError;

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
                _ProfileAvatarBlock(state: state),
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
                OmdsPrimaryButton(
                  key: const Key('profile-edit-save'),
                  text: state.isSavingProfile
                      ? l10n.profileSaving
                      : l10n.profileSave,
                  isEnabled: !state.isSavingProfile,
                  onTap: () => _onSave(l10n),
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
  const _ProfileAvatarBlock({required this.state});

  final SettingsState state;

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
        TextButton(
          key: const Key('profile-edit-change-avatar'),
          onPressed: state.isSavingProfile ? null : () {},
          child: Text(l10n.profileAvatarChange),
        ),
        if (state.profile.photoUrl != null)
          TextButton(
            key: const Key('profile-edit-remove-avatar'),
            onPressed: state.isSavingProfile
                ? null
                : () => context.read<SettingsCubit>().removePhoto(),
            child: Text(l10n.profileAvatarRemove),
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
    return OmdsTextField(
      key: const Key('profile-edit-name'),
      controller: controller,
      labelText: label,
      hintText: hint,
      errorText: errorText,
      isRequired: true,
      textCapitalization: TextCapitalization.words,
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
