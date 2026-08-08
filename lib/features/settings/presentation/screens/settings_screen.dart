import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/role/role_availability_cubit.dart';
import '../../../../core/session/profile_refresh_signals.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../customer_profile/data/dio_customer_profile_repository.dart';
import '../../../customer_profile/domain/customer_profile_repository.dart';
import '../../../profile_name/data/dio_display_name_repository.dart';
import '../../../profile_name/domain/display_name_repository.dart';
import '../../application/settings_cubit.dart';
import '../../application/settings_state.dart';
import '../../domain/account_deletion_policy.dart';
import '../../domain/account_service.dart';
import '../../domain/avatar_cache_evictor.dart';
import '../../domain/avatar_repository.dart';
import '../../domain/jeeber_unregister_service.dart';
import '../../domain/profile_repository.dart';
import '../widgets/settings_become_jeeber_card.dart';
import '../widgets/settings_footer.dart';
import '../widgets/settings_identity_card.dart';
import '../widgets/settings_language_toggle.dart';
import '../widgets/settings_more_card.dart';
import '../widgets/settings_notifications_card.dart';

/// Settings screen (T-mobile-031, MIDNIGHT R22).
///
/// Bands, top to bottom:
///   - in-body top bar (Ø40 glass back circle + title)
///   - glass identity card — name, phone, edit-profile entry
///   - Become-a-Jeeber growth card — the page's ONE lit frame
///   - LANGUAGE — EN / AR pill (drives the global [LocaleCubit])
///   - NOTIFICATIONS — one-line toggles + the always-on security-codes line
///   - MORE — addresses, notification preferences, dev diagnostics
///   - a real empty band, then the docked footer: sign out, delete, version
///
/// Field: `content` variant, orange glow top-end — the tile's only radial
/// (`radial-gradient(480px 380px at 88% -6%)`), and it declares no periwinkle.
/// R22 is board-still: nothing on this screen animates.
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

  /// Human-readable app version surfaced in the footer. Defaults to
  /// the pubspec value; production wiring should pass the build-time
  /// resolved string.
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final view = _SettingsView(appVersion: appVersion);
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
        // F5: avatar write path, cache-evict seam, remote-aware load() —
        // same DI-graph-or-degrade shape as the name lane above.
        avatarRepository: _resolveAvatarRepository(),
        avatarCacheEvictor: _resolveAvatarCacheEvictor(),
        remoteProfileRepository: _resolveRemoteProfileRepository(),
        refreshSignals: _resolveProfileRefreshSignals(),
        // F3: unregister-role write path, same DI-graph-or-degrade shape.
        jeeberUnregisterService: _resolveJeeberUnregisterService(),
      )..load(),
      child: view,
    );
  }

  static DisplayNameRepository? _resolveDisplayNameRepository() {
    if (!sl.isRegistered<Dio>()) return null;
    return DioDisplayNameRepository(sl<Dio>());
  }

  static AvatarRepository? _resolveAvatarRepository() {
    if (!sl.isRegistered<AvatarRepository>()) return null;
    return sl<AvatarRepository>();
  }

  static AvatarCacheEvictor? _resolveAvatarCacheEvictor() {
    if (!sl.isRegistered<AvatarCacheEvictor>()) return null;
    return sl<AvatarCacheEvictor>();
  }

  static CustomerProfileRepository? _resolveRemoteProfileRepository() {
    if (!sl.isRegistered<Dio>()) return null;
    return DioCustomerProfileRepository(sl<Dio>());
  }

  static ProfileRefreshSignals? _resolveProfileRefreshSignals() {
    if (!sl.isRegistered<ProfileRefreshSignals>()) return null;
    return sl<ProfileRefreshSignals>();
  }

  static JeeberUnregisterService? _resolveJeeberUnregisterService() {
    if (!sl.isRegistered<JeeberUnregisterService>()) return null;
    return sl<JeeberUnregisterService>();
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
        return JeebMidnightField(
          variant: JeebFieldVariant.content,
          // R22 declares .20 against the ratified single .24.
          glowColor: context.jeebRoles.accent.withValues(alpha: 0.20),
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              // The list reserves the nav-bar inset itself so the footer can
              // scroll clear of the soft buttons in edge-to-edge mode.
              bottom: false,
              child: Column(
                children: [
                  JeebTopBar.back(
                    title: l10n.settingsTitle,
                    identifier: 'settings_back',
                    // The `/settings` route has no forward-nav entry point
                    // (ORPHAN, JEBV4-227), so this screen can be reached with
                    // an empty Navigator stack: pop when we can, else go to the
                    // shell — never pop the last page (black surface).
                    onLeadingPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  // The board's `flex: 1` — the empty band is real, never
                  // filled.
                  Expanded(child: _SettingsBody(state: state)),
                  SafeArea(
                    top: false,
                    child: Padding(
                      // The board's 24px gutter (`tpl 1402`).
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: Spacing.xLarge,
                      ),
                      child: SettingsFooter(
                        state: state,
                        appVersion: appVersion,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The scrolling half of the screen: everything above the docked footer.
///
/// The footer is **docked outside this list** (plan R1: `column → content →
/// flex:1 → docked footer`). The alternative — a `Spacer` inside an
/// `IntrinsicHeight` in the scroll body — measurably overflows: `ListTile`
/// computes its intrinsic height from the *full* width, ignoring its content
/// padding and trailing switch, so a toggle title that wraps (AR, or any large
/// text scale) is under-reported and the column is laid out too short.
class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    // F3: Become-a-Jeeber vs Unregister-as-Jeeber bifurcate on LIVE role
    // presence (`RoleAvailabilityCubit`, app-root, kept fresh by `RoleSync`
    // on auth + resume) — not raw KYC status, per the corrected F3 design.
    // Nullable-read: a harness with no cubit provided (tests, bare hosts)
    // degrades to "not a jeeber", i.e. today's unconditional become-jeeber
    // card, so this is additive-only for every existing caller.
    final roles = context.watch<RoleAvailabilityCubit?>()?.state.roles;
    final isJeeber = roles?.contains('jeeber') ?? false;
    return ListView(
      key: const Key('settings-screen-list'),
      // Preserve the horizontal gutter AND reserve the system nav-bar inset so
      // the last row scrolls clear of the soft buttons in edge-to-edge mode
      // (this is a pushed full-screen route with no bottom nav bar). See
      // [BottomInsetX.scrollBodyBottomInset]. Symmetric, so the non-directional
      // EdgeInsets this contract pins mirrors as a no-op.
      padding: EdgeInsets.only(
        left: Spacing.medium,
        right: Spacing.medium,
        bottom: context.scrollBodyBottomInset,
      ),
      children: [
        Padding(
          // 16 (list) + 8 = the board's 24px gutter.
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.xSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.medium),
              SettingsIdentityCard(state: state),
              if (!isJeeber) ...[
                const SizedBox(height: Spacing.small),
                const SettingsBecomeJeeberCard(),
              ],
              // The board opens each labelled band with 20 (`tpl 1370`/`1377`),
              // not the 16 that separates the two cards above.
              const SizedBox(height: Spacing.large),
              const SettingsLanguageToggle(),
              const SizedBox(height: Spacing.large),
              SettingsNotificationsCard(state: state),
              const SizedBox(height: Spacing.large),
              SettingsMoreCard(showUnregisterRow: isJeeber),
            ],
          ),
        ),
      ],
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
    case SettingsBanner.jeeberUnregistered:
      return l10n.jeeberUnregisterSuccess;
    case SettingsBanner.jeeberUnregisterActiveDelivery:
      return l10n.jeeberUnregisterActiveDelivery;
    case SettingsBanner.jeeberUnregisterPositiveBalance:
      return l10n.jeeberUnregisterPositiveBalance;
    case SettingsBanner.jeeberUnregisterUnavailable:
      return l10n.jeeberUnregisterUnavailable;
  }
}
