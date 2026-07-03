import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/diagnostics/diag.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/session/profile_refresh_signals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile_name/data/dio_display_name_repository.dart';
import '../../../profile_name/domain/display_name_repository.dart';
import '../../application/role_switch_cubit.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../../domain/account_service.dart';
import '../../domain/profile_repository.dart';
import '../widgets/logout_delete_confirm_sheet.dart';
import '../widgets/role_toggle_setting.dart';

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
    this.roleSwitchCubit,
    this.availableRoles = const [],
    this.appVersion = '1.0.0',
  });

  /// Optional injected cubit. Production callers can omit this and let the
  /// screen build a no-op default; widget tests pass in a pre-wired cubit
  /// so they don't have to plumb SharedPreferences.
  final SettingsCubit? cubit;

  /// T-MOB-028: Optional role-switch cubit. When non-null and [availableRoles]
  /// contains both 'client' and 'jeeber', the Active Role toggle is shown.
  final RoleSwitchCubit? roleSwitchCubit;

  /// T-MOB-028: Available role identifiers for the logged-in user. Drives
  /// [RoleToggleSetting] visibility.
  final List<String> availableRoles;

  /// Human-readable app version surfaced in the About section. Defaults to
  /// the pubspec value; production wiring should pass the build-time
  /// resolved string.
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final view = _SettingsView(
      appVersion: appVersion,
      roleSwitchCubit: roleSwitchCubit,
      availableRoles: availableRoles,
    );
    if (cubit != null) {
      return BlocProvider<SettingsCubit>.value(value: cubit!, child: view);
    }
    // Production wiring (Sprint 2 Stream F): resolve the real persistence +
    // account seams from DI instead of self-constructing in-memory fakes. The
    // fakes now live under test/ and are injected via the [cubit] seam above.
    return BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(
        profileRepository: sl<ProfileRepository>(),
        accountService: sl<AccountService>(),
        // Profile-name lane: mirror a saved name to the gateway
        // (`PUT /api/User/profile` `{username}`) and broadcast the change so
        // live greeting surfaces re-pull getMe. Both resolve off the shared DI
        // graph; a bare test host (no Dio) degrades to local-only saves.
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
  const _SettingsView({
    required this.appVersion,
    this.roleSwitchCubit,
    this.availableRoles = const [],
  });

  final String appVersion;
  final RoleSwitchCubit? roleSwitchCubit;
  final List<String> availableRoles;

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
            // Preserve the horizontal gutter AND reserve the system nav-bar
            // inset so the final Account row clears the soft buttons in
            // edge-to-edge mode (this is a pushed full-screen route with no
            // bottom nav bar). See [BottomInsetX.scrollBodyBottomInset].
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
              // T-MOB-028: Role toggle — only shown when both roles available
              // and a RoleSwitchCubit is wired by the host (shell/profile-tab).
              if (roleSwitchCubit != null)
                RoleToggleSetting(
                  availableRoles: availableRoles,
                  cubit: roleSwitchCubit!,
                ),
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
            icon: Icons.chevron_right,
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
            icon: Icons.chevron_right,
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
        Semantics(
          identifier: 'settings-row-notifications-manage',
          button: true,
          child: OmdsSettingsRow(
            key: const Key('settings-row-notifications-manage'),
            title: l10n.notificationPreferencesTitle,
            subtitle: l10n.notificationPreferencesRowSubtitle,
            leadingIcon: Icons.notifications_outlined,
            icon: Icons.chevron_right,
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
        // Dev-only diagnostics export entry (diag-persistence lane). Gated on
        // Diag.enabled (kDebugMode || JEEB_DIAG dart-define) so it NEVER
        // renders in release. Literal English strings by design — a dev tool
        // that never ships, deliberately kept out of the ARB catalogs.
        if (Diag.enabled)
          Semantics(
            identifier: 'settings_open_diagnostics',
            button: true,
            child: OmdsSettingsRow(
              key: const Key('settings-row-diagnostics'),
              title: 'Diagnostics',
              subtitle: 'Session logs · dev builds only',
              leadingIcon: Icons.bug_report_outlined,
              icon: Icons.chevron_right,
              onTap: () => context.pushNamed('settings-diagnostics'),
            ),
          ),
      ],
    );
  }
}

/// Account section — the JM-062 `logout-delete-account` host.
///
/// The Delete-account + Sign-out rows each open the [LogoutDeleteConfirmSheet]
/// (the blueprint `logout-delete-account` confirm surface), whose
/// `logout_confirm_cta` / `delete_confirm_cta` clear the local session and route
/// to splash (`/` → first-run gate → `/login`, D5). This is also the screen the
/// `account-status` (JM-066) `account_status_signout_cta` routes to (`/settings`),
/// so a suspended/locked user reaches sign-out without a dead end.
///
/// Semantics: the section root is tagged `logout_delete_account_root` so the
/// surface is addressable; the confirm CTAs live inside the sheet (the dialog
/// path was retired — `OmdsConfirmationDialog` cannot carry the EXACT confirm-CTA
/// identifiers the JM-062 AC requires).
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
              icon: Icons.chevron_right,
              enabled: !state.isSigningOut,
              onTap: () => _confirmSignOut(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the delete-account confirm sheet (`delete_confirm_cta`). On confirm
  /// the sheet clears the session and routes to splash (D5).
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    await LogoutDeleteConfirmSheet.show(
      context,
      mode: LogoutDeleteMode.delete,
    );
  }

  /// Opens the sign-out confirm sheet (`logout_confirm_cta`). On confirm the
  /// sheet clears the session and routes to splash (D5).
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
      return l10n.accountDeleteSubmitted;
    case SettingsBanner.networkError:
      return l10n.settingsNetworkError;
  }
}
