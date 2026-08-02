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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../devtool/catalog/fixtures/settings_screen_fixtures.dart';
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/settings/settings_screen_preview_test.dart
// ===========================================================================
//
// [SettingsScreen] is six sections of rows over ONE [SettingsCubit], and
// `cubit:` is a shipped constructor seam, so every state below is that cubit
// parked somewhere. The cubits, the fakes behind them and the seating are NOT
// declared here: they live in
// `lib/devtool/catalog/fixtures/settings_screen_fixtures.dart`, shared with the
// on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_10_entries.dart`), so the designer's browser
// and this canvas cannot drift into showing two different "Maya Haddad". None
// of those fakes can reach the network — they answer from a field or never
// complete — and no state below calls a repository at all. The guard in
// [jeebPreviewHost] is the net here, not the plan.
//
// Four things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + OMDSAppBar` paints inside it. That is the same
//    nesting the Screen Catalog produces.
//  * **The width is pinned in the TREE, not just in `size:`.** `size:` boxes
//    the canvas; [SettingsScreenPreviewHost] pins the same width in the widget
//    tree so the render tests break lines where the canvas breaks them. Width
//    is the whole game on a settings list — every row is title + subtitle
//    against a leading icon and a trailing chevron — so height is deliberately
//    left to the host, which is a scrolling [ListView] either way.
//  * **A [LocaleCubit] ancestor is mandatory, not optional.** [_LanguageSection]
//    calls `context.watch<LocaleCubit>()` on EVERY build, so a bare
//    `SettingsScreen` throws in the canvas. The host provides one over
//    in-memory prefs, seeded from the ambient locale — which is why the AR card
//    of a matrix checks "العربية" and the EN card checks "English".
//  * **Tapping is not previewing.** Every row calls `context.pushNamed(...)`
//    and the two Account rows push [LogoutDeleteConfirmSheet], which resolves
//    its session terminator from DI. There is no [GoRouter] above a preview
//    card, so those taps throw. Everything else is inert by construction.
//
// Three things these previews surfaced, all in the screen rather than in the
// previews — see the notes on the individual states:
//
//  * **Two of the six states below cannot occur in the shipped app.** The
//    delete + sign-out rows open [LogoutDeleteConfirmSheet], which terminates
//    the session through its own `AccountSessionTerminator` and never calls
//    `SettingsCubit.requestAccountDeletion()` / `signOut()`. Nothing else on
//    this route calls them either, so `deletionPending`, `isDeletingAccount`
//    and `isSigningOut` — and with them every non-`none` [SettingsBanner] —
//    are set by no production path. The E20 (JEBV4-215) pending copy is
//    reachable from a fixture and from `test/settings_screen_test.dart`, and
//    from nowhere a user can stand.
//  * **The cold read has no affordance.** `isLoading` is read by nothing in
//    [_SettingsView]: during the load the list is fully painted and fully
//    tappable, and the profile row shows the same "Add your name" placeholder
//    a user with no name saved gets. Compare [settingsScreenColdLoad] with
//    [settingsScreenPhoneOnly] — the ONLY difference is the subtitle, and it
//    differs because the phone is not loaded yet, not by design.
//  * **A failed read has no affordance either, and cannot retry.**
//    `SettingsCubit.load()` does not catch, so a throwing repository escapes
//    as an unhandled Future error from `..load()` and leaves `isLoading`
//    latched — which `load()`'s own `if (state.isLoading) return;` guard then
//    treats as "already loading" forever. The rendering is
//    [settingsScreenColdLoad], permanently. There is no fixture for it here
//    because there is nothing different to look at, which is the point.

/// The phone this list is designed against.
const double _settingsScreenPhoneWidth = 390;

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
/// foreground app. Every row here is a [ListTile] whose title column has to
/// share the width with a leading icon and a trailing chevron, so this is where
/// the two-line rows start wrapping to three.
const double _settingsScreenCompactWidth = 320;

const Size _settingsScreenPhoneBox = Size(_settingsScreenPhoneWidth, 844);
const Size _settingsScreenCompactBox = Size(_settingsScreenCompactWidth, 568);

/// Seats [SettingsScreen] over a fixture cubit at a pinned device width.
///
/// `appVersion` is deliberately left at its default so the About row reads the
/// same here as in the Screen Catalog.
Widget _settingsScreenHosted(
  SettingsCubit Function() create, {
  double width = _settingsScreenPhoneWidth,
}) {
  return SettingsScreenPreviewHost(
    create: create,
    width: width,
    builder: (SettingsCubit cubit) => SettingsScreen(cubit: cubit),
  );
}

/// The reference reading, and the Screen Catalog's "Loaded — Profile": a
/// customer with a name and a phone on file, hydrated through the real
/// `load()` path.
///
/// The matrix is on because this list is nothing but rows of directional
/// chrome — a leading icon, a title/subtitle column and a trailing chevron —
/// and all three of those mirror in AR. It is also where the 200% rendering is
/// worth reading: the row titles and subtitles are the app's longest routine
/// copy, and [OmdsSettingsRow] gives its title [Text] no `maxLines` and no
/// `overflow`, so they wrap rather than ellipsize and every row grows.
@JeebPreview(
  group: 'settings',
  name: 'Loaded · name + phone',
  size: _settingsScreenPhoneBox,
  matrix: true,
)
Widget settingsScreenLoaded() =>
    _settingsScreenHosted(SettingsScreenPreviewFixtures.loadedProfile);

/// Signed in, never finished the profile step: the phone is all Jeeb knows.
///
/// The profile row falls back to the localized "Add your name" placeholder as
/// its TITLE and shows the registration phone underneath. Worth its own card
/// because it is the state most freshly-registered users see, and because it
/// is one subtitle away from the cold-load rendering below.
@JeebPreview(
  group: 'settings',
  name: 'Empty · phone only, no name',
  size: _settingsScreenPhoneBox,
)
Widget settingsScreenPhoneOnly() =>
    _settingsScreenHosted(SettingsScreenPreviewFixtures.phoneOnly);

/// The cold read still in flight — `isLoading: true`, nothing hydrated.
///
/// Read this next to [settingsScreenPhoneOnly]. Nothing in [_SettingsView]
/// reads `isLoading`: there is no shimmer, no spinner and no disabled state,
/// so a list that knows nothing yet is indistinguishable from a list that has
/// loaded and found nothing — and the Profile row is tappable throughout,
/// pushing `settings-profile` while the read is still outstanding.
///
/// This is also exactly what a FAILED read looks like forever (see the note
/// above the sizes): `load()` neither catches nor clears `isLoading`.
@JeebPreview(
  group: 'settings',
  name: 'Loading · cold read in flight',
  size: _settingsScreenPhoneBox,
)
Widget settingsScreenColdLoad() =>
    _settingsScreenHosted(SettingsScreenPreviewFixtures.coldLoad);

/// E20 (JEBV4-215), and the Screen Catalog's "Loaded — Deletion Pending": the
/// delete request has been accepted, so the row latches to the scheduled-purge
/// copy, loses its destructive red and stops being tappable.
///
/// The one state where the Account section's two rows disagree — delete is
/// disabled, sign-out is not — which is the whole point of the copy: the
/// account is scheduled, and signing in again is how you cancel.
///
/// **No production path sets this.** See the note above the sizes; the row is
/// reachable only from a fixture and from `test/settings_screen_test.dart`.
@JeebPreview(
  group: 'settings',
  name: 'Deletion pending · row latched',
  size: _settingsScreenPhoneBox,
)
Widget settingsScreenDeletionPending() =>
    _settingsScreenHosted(SettingsScreenPreviewFixtures.deletionPending);

/// Both destructive requests in flight at once.
///
/// The screen's only in-flight feedback: the two Account rows grey out (title,
/// subtitle, leading icon and chevron all drop to 38% opacity) and their taps
/// go dead. There is no spinner and no banner, so on a slow connection this
/// reads as "the rows are broken" rather than "your request is going".
///
/// Also unreachable in the shipped app — the sheet owns both actions and
/// carries its own in-flight state on the CTA.
@JeebPreview(
  group: 'settings',
  name: 'Destructive actions in flight',
  size: _settingsScreenPhoneBox,
)
Widget settingsScreenDestructiveInFlight() =>
    _settingsScreenHosted(SettingsScreenPreviewFixtures.destructiveInFlight);

/// Layout ceiling: the longest name on file, every notification opted out, on
/// the narrowest phone the app supports.
///
/// A full Lebanese name with two family particles is ordinary here and roughly
/// triples the reference title. [OmdsSettingsRow] renders that title in a
/// [Column] inside a [ListTile] with no `maxLines`, so it wraps and the row
/// grows — read the 200% card of this matrix, where the same wrap happens to
/// every row at once and the switch rows have to hold a two-line title, a
/// two-line subtitle and a [Switch] across 320 pt.
@JeebPreview(
  group: 'settings',
  name: 'Longest content · compact 320',
  size: _settingsScreenCompactBox,
  matrix: true,
)
Widget settingsScreenLongestContentCompact() => _settingsScreenHosted(
      SettingsScreenPreviewFixtures.longestContent,
      width: _settingsScreenCompactWidth,
    );
