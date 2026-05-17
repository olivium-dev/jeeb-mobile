import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/locale/locale_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../../data/in_memory_profile_repository.dart';
import '../../domain/account_service.dart';
import 'profile_edit_screen.dart';

/// Settings screen (T-mobile-031).
///
/// Sections:
///   - Profile — name + avatar editor entry
///   - Language — EN / AR selector (drives the global [LocaleCubit])
///   - Notifications — switch-row toggles per category
///   - About — app name + version row
///   - Account — delete-account (destructive) + sign-out
///
/// Theme follows system: the `MaterialApp.themeMode` is fixed to
/// [ThemeMode.system] at app root, so this screen has no theme switcher.
///
/// Talks to a single [SettingsCubit] hosted at the route. Hosting it here
/// keeps the dependency on the persistence + account-service seams scoped
/// to the route and out of the global widget tree.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.cubit,
    this.appVersion = '1.0.0',
  });

  /// Optional injected cubit. Production callers can omit this and let the
  /// screen build a no-op default; widget tests pass in a pre-wired cubit
  /// so they don't have to plumb SharedPreferences.
  final SettingsCubit? cubit;

  /// Human-readable app version surfaced in the About section. Defaults to
  /// the pubspec value; production wiring should pass the build-time
  /// resolved string.
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider<SettingsCubit>.value(
        value: cubit!,
        child: _SettingsView(appVersion: appVersion),
      );
    }
    return BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
      )..load(),
      child: _SettingsView(appVersion: appVersion),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.appVersion});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) => prev.banner != curr.banner,
      listener: (context, state) {
        final message = _bannerMessage(state.banner, l10n);
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          context.read<SettingsCubit>().dismissBanner();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: OMDSAppBar(
            title: l10n.settingsTitle,
            showBackButton: true,
          ),
          body: ListView(
            key: const Key('settings-screen-list'),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
            children: [
              _ProfileSection(state: state),
              _LanguageSection(),
              _NotificationsSection(state: state),
              _AboutSection(appVersion: appVersion),
              _AccountSection(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayName = state.profile.name ?? l10n.profileNamePlaceholder;
    return OmdsSettingsSection(
      title: l10n.settingsProfileSection,
      children: [
        OmdsSettingsRow(
          key: const Key('settings-row-profile'),
          title: displayName,
          subtitle: state.profile.phoneE164.isEmpty
              ? l10n.profileEditSubtitle
              : state.profile.phoneE164,
          leadingIcon: Icons.person_outline,
          onTap: () => _openProfileEdit(context),
        ),
      ],
    );
  }

  void _openProfileEdit(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const ProfileEditScreen(),
        ),
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    return OmdsSettingsSection(
      title: l10n.settingsLanguage,
      children: [
        _LanguageRow(
          rowKey: const Key('settings-row-language-en'),
          title: l10n.settingsLanguageEnglish,
          selected: locale.languageCode == 'en',
          onTap: () =>
              context.read<LocaleCubit>().setLocale(const Locale('en')),
        ),
        _LanguageRow(
          rowKey: const Key('settings-row-language-ar'),
          title: l10n.settingsLanguageArabic,
          selected: locale.languageCode == 'ar',
          onTap: () =>
              context.read<LocaleCubit>().setLocale(const Locale('ar')),
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
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

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    return OmdsSettingsSection(
      title: l10n.settingsNotificationsSection,
      children: [
        OmdsSettingsSwitchRow(
          key: const Key('settings-row-notifications-offers'),
          title: l10n.notificationCategoryOffers,
          subtitle: l10n.notificationCategoryOffersSubtitle,
          value: state.notifications.offers,
          onChanged: (v) =>
              cubit.setNotification(NotificationCategory.offers, v),
        ),
        OmdsSettingsSwitchRow(
          key: const Key('settings-row-notifications-chat'),
          title: l10n.notificationCategoryChat,
          subtitle: l10n.notificationCategoryChatSubtitle,
          value: state.notifications.chat,
          onChanged: (v) =>
              cubit.setNotification(NotificationCategory.chat, v),
        ),
        OmdsSettingsSwitchRow(
          key: const Key('settings-row-notifications-status'),
          title: l10n.notificationCategoryStatus,
          subtitle: l10n.notificationCategoryStatusSubtitle,
          value: state.notifications.status,
          onChanged: (v) =>
              cubit.setNotification(NotificationCategory.status, v),
        ),
        OmdsSettingsSwitchRow(
          key: const Key('settings-row-notifications-ratings'),
          title: l10n.notificationCategoryRatingReminders,
          subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
          value: state.notifications.ratingReminders,
          onChanged: (v) => cubit.setNotification(
              NotificationCategory.ratingReminders, v),
        ),
        OmdsSettingsRow(
          key: const Key('settings-row-notifications-otp'),
          title: l10n.notificationCategoryOtp,
          subtitle: l10n.notificationCategoryOtpAlwaysOn,
          leadingIcon: Icons.lock_outline,
          icon: Icons.lock_outline,
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.appVersion});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      title: l10n.settingsAboutSection,
      children: [
        OmdsSettingsRow(
          key: const Key('settings-row-app-version'),
          title: l10n.settingsAppVersion,
          subtitle: appVersion,
          leadingIcon: Icons.info_outline,
          icon: Icons.info_outline,
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsSettingsSection(
      title: l10n.settingsAccountSection,
      children: [
        OmdsSettingsRow(
          key: const Key('settings-row-delete-account'),
          title: l10n.accountDeleteRow,
          subtitle: state.deletionPending
              ? l10n.accountDeletePending
              : l10n.accountDeleteSubtitle,
          leadingIcon: Icons.delete_outline,
          leadingIconColor: colorScheme.error,
          titleStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: state.deletionPending
                    ? colorScheme.onSurface
                    : colorScheme.error,
              ),
          enabled: !state.deletionPending && !state.isDeletingAccount,
          onTap: () => _confirmDeleteAccount(context),
        ),
        OmdsSettingsRow(
          key: const Key('settings-row-sign-out'),
          title: l10n.appBarSignOut,
          leadingIcon: Icons.logout,
          icon: Icons.chevron_right,
          enabled: !state.isSigningOut,
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.accountDeleteDialogTitle,
      content: l10n.accountDeleteDialogBody,
      confirmText: l10n.accountDeleteConfirm,
      cancelText: l10n.actionCancel,
      isDestructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed) return;
    await cubit.requestAccountDeletion();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.signOutDialogTitle,
      content: l10n.signOutDialogBody,
      confirmText: l10n.appBarSignOut,
      cancelText: l10n.actionCancel,
      isDestructive: true,
      icon: Icons.logout,
    );
    if (!confirmed) return;
    await cubit.signOut();
  }
}

String? _bannerMessage(SettingsBanner banner, AppLocalizations l10n) {
  switch (banner) {
    case SettingsBanner.none:
      return null;
    case SettingsBanner.profileSaved:
      return l10n.profileSaved;
    case SettingsBanner.signedOut:
      return l10n.signOutCompleted;
    case SettingsBanner.accountDeletionRequested:
      return l10n.accountDeleteSubmitted;
    case SettingsBanner.networkError:
      return l10n.settingsNetworkError;
  }
}
