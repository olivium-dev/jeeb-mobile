import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/diagnostics/diag.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/session/profile_refresh_signals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile_name/data/dio_display_name_repository.dart';
import '../../../profile_name/domain/display_name_repository.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../../domain/account_deletion_policy.dart';
import '../../domain/account_service.dart';
import '../../domain/profile_repository.dart';
import '../widgets/logout_delete_confirm_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.cubit,
    this.appVersion = '1.0.0',
  });

  final SettingsCubit? cubit;

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final view = _SettingsView(appVersion: appVersion);
    if (cubit != null) {
      return BlocProvider<SettingsCubit>.value(value: cubit!, child: view);
    }
    return BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(
        profileRepository: sl<ProfileRepository>(),
        accountService: sl<AccountService>(),
        displayNameRepository: _resolveDisplayNameRepository(),
        refreshSignals: _resolveProfileRefreshSignals(),
      )..load(),
      child: view,
    );
  }

  static DisplayNameRepository? _resolveDisplayNameRepository() {
    if (!sl.isRegistered<Dio>()) return null;
    return DioDisplayNameRepository(sl<Dio>());
  }

  static ProfileRefreshSignals? _resolveProfileRefreshSignals() {
    if (!sl.isRegistered<ProfileRefreshSignals>()) return null;
    return sl<ProfileRefreshSignals>();
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
            onBackPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
          body: ListView(
            key: const Key('settings-screen-list'),
            padding: EdgeInsets.only(
              left: Spacing.medium,
              right: Spacing.medium,
              bottom: context.scrollBodyBottomInset,
            ),
            children: [
              _ProfileSection(state: state),
              _AddressesSection(),
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
        Semantics(
          identifier: 'settings-profile-row',
          button: true,
          child: OmdsSettingsRow(
            key: const Key('settings-row-profile'),
            title: displayName,
            subtitle: state.profile.phoneE164.isEmpty
                ? l10n.profileEditSubtitle
                : state.profile.phoneE164,
            leadingIcon: Icons.person_outline,
            onTap: () => context.pushNamed('settings-profile'),
          ),
        ),
        Semantics(
          identifier: 'settings-row-become-jeeber',
          button: true,
          child: OmdsSettingsRow(
            key: const Key('settings-row-become-jeeber'),
            title: l10n.becomeJeeberCardTitle,
            subtitle: l10n.becomeJeeberCardSubtitle,
            leadingIcon: Icons.badge_outlined,
            icon: DirectionalIcons.disclosure(context),
            onTap: () => context.pushNamed('kyc-status'),
          ),
        ),
      ],
    );
  }
}

class _AddressesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      title: l10n.savedAddressesTitle,
      children: [
        Semantics(
          identifier: 'settings_open_addresses',
          button: true,
          child: OmdsSettingsRow(
            key: const Key('settings-row-addresses'),
            title: l10n.savedAddressesTitle,
            subtitle: l10n.savedAddressesSubtitle,
            leadingIcon: Icons.location_on_outlined,
            icon: DirectionalIcons.disclosure(context),
            onTap: () => context.pushNamed('settings-addresses'),
          ),
        ),
      ],
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
          identifier: 'settings_language_en_option',
          title: l10n.settingsLanguageEnglish,
          selected: locale.languageCode == 'en',
          onTap: () =>
              context.read<LocaleCubit>().setLocale(const Locale('en')),
        ),
        _LanguageRow(
          rowKey: const Key('settings-row-language-ar'),
          identifier: 'settings_language_ar_option',
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
    required this.identifier,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final Key rowKey;
  final String identifier;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      label: title,
      button: true,
      container: true,
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
        Semantics(
          identifier: 'settings_notifications_offers_toggle',
          toggled: state.notifications.offers,
          container: true,
          child: OmdsSettingsSwitchRow(
            key: const Key('settings-row-notifications-offers'),
            title: l10n.notificationCategoryOffers,
            subtitle: l10n.notificationCategoryOffersSubtitle,
            value: state.notifications.offers,
            onChanged: (v) =>
                cubit.setNotification(NotificationCategory.offers, v),
          ),
        ),
        Semantics(
          identifier: 'settings_notifications_chat_toggle',
          toggled: state.notifications.chat,
          container: true,
          child: OmdsSettingsSwitchRow(
            key: const Key('settings-row-notifications-chat'),
            title: l10n.notificationCategoryChat,
            subtitle: l10n.notificationCategoryChatSubtitle,
            value: state.notifications.chat,
            onChanged: (v) =>
                cubit.setNotification(NotificationCategory.chat, v),
          ),
        ),
        Semantics(
          identifier: 'settings_notifications_status_toggle',
          toggled: state.notifications.status,
          container: true,
          child: OmdsSettingsSwitchRow(
            key: const Key('settings-row-notifications-status'),
            title: l10n.notificationCategoryStatus,
            subtitle: l10n.notificationCategoryStatusSubtitle,
            value: state.notifications.status,
            onChanged: (v) =>
                cubit.setNotification(NotificationCategory.status, v),
          ),
        ),
        Semantics(
          identifier: 'settings_notifications_ratings_toggle',
          toggled: state.notifications.ratingReminders,
          container: true,
          child: OmdsSettingsSwitchRow(
            key: const Key('settings-row-notifications-ratings'),
            title: l10n.notificationCategoryRatingReminders,
            subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
            value: state.notifications.ratingReminders,
            onChanged: (v) => cubit.setNotification(
                NotificationCategory.ratingReminders, v),
          ),
        ),
        OmdsSettingsRow(
          key: const Key('settings-row-notifications-otp'),
          title: l10n.notificationCategoryOtp,
          subtitle: l10n.notificationCategoryOtpAlwaysOn,
          leadingIcon: Icons.lock_outline,
          icon: Icons.lock_outline,
        ),
        Semantics(
          identifier: 'settings-row-notifications-manage',
          button: true,
          child: OmdsSettingsRow(
            key: const Key('settings-row-notifications-manage'),
            title: l10n.notificationPreferencesTitle,
            subtitle: l10n.notificationPreferencesRowSubtitle,
            leadingIcon: Icons.notifications_outlined,
            icon: DirectionalIcons.disclosure(context),
            onTap: () => context.pushNamed('settings-notifications'),
          ),
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
        // Diag.enabled (kDebugMode || JEEB_DIAG dart-define) so it NEVER
        if (Diag.enabled)
          Semantics(
            identifier: 'settings_open_diagnostics',
            button: true,
            child: OmdsSettingsRow(
              key: const Key('settings-row-diagnostics'),
              title: 'Diagnostics',
              subtitle: 'Session logs · dev builds only',
              leadingIcon: Icons.bug_report_outlined,
              icon: DirectionalIcons.disclosure(context),
              onTap: () => context.pushNamed('settings-diagnostics'),
            ),
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
    return Semantics(
      identifier: 'logout_delete_account_root',
      container: true,
      explicitChildNodes: true,
      child: OmdsSettingsSection(
        title: l10n.settingsAccountSection,
        children: [
          Semantics(
            identifier: 'settings_delete_account_row',
            button: true,
            child: OmdsSettingsRow(
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
          ),
          Semantics(
            identifier: 'settings_sign_out_row',
            button: true,
            child: OmdsSettingsRow(
              key: const Key('settings-row-sign-out'),
              title: l10n.appBarSignOut,
              leadingIcon: Icons.logout,
              icon: DirectionalIcons.disclosure(context),
              enabled: !state.isSigningOut,
              onTap: () => _confirmSignOut(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    await LogoutDeleteConfirmSheet.show(
      context,
      mode: LogoutDeleteMode.delete,
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    await LogoutDeleteConfirmSheet.show(
      context,
      mode: LogoutDeleteMode.logout,
    );
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
      return l10n.accountDeleteSubmitted(kAccountPurgeGraceDays);
    case SettingsBanner.networkError:
      return l10n.settingsNetworkError;
  }
}
