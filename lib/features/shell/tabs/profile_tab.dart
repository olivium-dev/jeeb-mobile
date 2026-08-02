import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../settings/presentation/widgets/become_jeeber_card.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    final role = context.watch<RoleCubit>().state;

    return ListView(
      key: const Key('profile-tab-root'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      children: [
        BecomeJeeberCard(
          isAlreadyJeeber: role == UserRole.jeeber,
          onTap: () => _openKycFlow(context),
        ),
        OmdsSettingsSection(
          title: l10n.settingsLanguage,
          children: [
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-language-en'),
              title: l10n.settingsLanguageEnglish,
              selected: locale.languageCode == 'en',
              onTap: () => context
                  .read<LocaleCubit>()
                  .setLocale(const Locale('en')),
            ),
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-language-ar'),
              title: l10n.settingsLanguageArabic,
              selected: locale.languageCode == 'ar',
              onTap: () => context
                  .read<LocaleCubit>()
                  .setLocale(const Locale('ar')),
            ),
          ],
        ),
        OmdsSettingsSection(
          title: l10n.settingsRole,
          children: [
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-role-client'),
              title: l10n.settingsRoleClient,
              selected: role == UserRole.client,
              onTap: () =>
                  context.read<RoleCubit>().setRole(UserRole.client),
            ),
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-role-jeeber'),
              title: l10n.settingsRoleJeeber,
              selected: role == UserRole.jeeber,
              onTap: () =>
                  context.read<RoleCubit>().setRole(UserRole.jeeber),
            ),
          ],
        ),
        OmdsSettingsSection(
          title: l10n.settingsAccountSection,
          children: [
            OmdsSettingsRow(
              key: const Key('profile-tab-open-settings'),
              title: l10n.settingsTitle,
              subtitle: l10n.settingsOpenSubtitle,
              leadingIcon: Icons.settings_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openKycFlow(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    router?.goNamed('kyc-status');
  }
}

class _SelectableSettingsRow extends StatelessWidget {
  const _SelectableSettingsRow({
    required this.rowKey,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final Key rowKey;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: ExcludeSemantics(
        child: OmdsSettingsRow(
          key: rowKey,
          title: title,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
