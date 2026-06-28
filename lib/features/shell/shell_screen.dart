import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/role/role_availability_cubit.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../l10n/app_localizations.dart';
import '../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../customer_profile/presentation/customer_profile_screen.dart';
import 'tab_visibility.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'widgets/jeeber_tab_empty_state.dart';
import 'widgets/shell_header_actions.dart';

/// Unified bottom-nav shell implementing the UX LAW (consolidated-lessons §12):
/// **a jeeber is also a user.**
///
/// There is NO role switch and NO role-gated tab set. EVERY user sees the same
/// five additive destinations:
///
///   Requests · Delivery · Jeeber · Earnings · Profile
///
/// The first two + Profile are the regular-user surfaces; **Jeeber** (the
/// availability + request feed) and **Earnings** are the jeeber surfaces, added
/// to every user's shell. A regular (non-jeeber) user sees the SAME jeeber-tab
/// scaffolding but with EMPTY STATES ([JeeberTabEmptyState]) inviting them to
/// become a jeeber — never a mode-switch. Whether the live jeeber body or the
/// empty state renders is decided purely by the signed-in user's
/// `available_roles` (getMe → [RoleAvailabilityCubit]); it is additive and
/// reactive, so a user who completes jeeber onboarding lights up the live
/// bodies in place without any in-app role flip.
///
/// The bottom bar uses the surface color with a soft top shadow, the Jeeb
/// navy/brown color scheme, and per-tab stable Semantics ids (`shell_tab_*`)
/// so QA can target tabs without matching localized labels.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  /// The tab the user explicitly tapped. `null` until the first manual tap, so
  /// before any navigation the shell follows the role-driven LANDING tab (a
  /// jeeber lands on Dashboard, a client on Requests). After a tap we honor the
  /// user's choice and never auto-move again — this is initial FOCUS, never a
  /// mode-switch (every tab stays present + selectable for every user).
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    // The tab SET never changes — additive, not role-gated. Only the jeeber
    // tab BODIES (live vs empty state) react to the user's available roles.
    final availability = context.watch<RoleAvailabilityCubit?>()?.state;
    final activeRole = context.watch<RoleCubit?>()?.state;
    final tabs = _tabs(showJeeberContent: _showJeeberContent(availability));
    final safeIndex = _effectiveIndex(tabs, activeRole);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _ShellBody(tabs: tabs, selectedIndex: safeIndex),
      ),
      bottomNavigationBar: _JeebBottomBar(
        tabs: tabs,
        selectedIndex: safeIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  /// The page to show: the user's explicit pick once they've tapped, otherwise
  /// the role-driven landing tab. Always clamped to a valid tab.
  int _effectiveIndex(List<_Tab> tabs, UserRole? role) {
    final index = _selectedIndex ?? _landingIndex(tabs, role);
    return index.clamp(0, tabs.length - 1);
  }

  /// DEFECT-C: the tab a freshly-resolved user lands on. A `jeeber` active_role
  /// (from getMe → [RoleCubit], reconciled post-login by `RoleSync`) lands on
  /// the Dashboard surface so Karim opens onto his jeeber feed, not the client
  /// Requests default; everyone else lands on Requests. Reactive: the moment
  /// `RoleSync` flips the role to jeeber the landing tab follows, with no manual
  /// role flip and no tab ever hidden.
  int _landingIndex(List<_Tab> tabs, UserRole? role) {
    if (role != UserRole.jeeber) return 0;
    final dashboard = tabs.indexWhere((t) => t.id == 'dashboard');
    return dashboard < 0 ? 0 : dashboard;
  }

  /// True when the Jeeber + Earnings tabs should render their LIVE bodies
  /// (availability toggle / feed / earnings dashboard) rather than the
  /// [JeeberTabEmptyState] invitation.
  ///
  /// Source of truth is the signed-in user's `available_roles` from getMe
  /// ([RoleAvailabilityCubit]) — a `jeeber` membership lights up the live
  /// bodies. Never a hardcoded id and never an in-app role flip.
  ///
  /// Debug-only: the dev seam can force the live jeeber bodies so a single
  /// capture APK renders screens 19/23-26 deterministically (the register
  /// prompt via `jeeb.home_tab=unregistered`, the feed variants via
  /// `jeeb.feed=<view>`) without a real getMe round-trip. Always the real
  /// available-roles signal in release.
  bool _showJeeberContent(RoleAvailability? availability) {
    if (kDebugMode) {
      final seam = DevSeam.current;
      if (seam.feed.isNotEmpty || seam.homeTab == 'unregistered') return true;
    }
    return availability?.roles.contains('jeeber') ?? false;
  }

  List<_Tab> _tabs({required bool showJeeberContent}) {
    final l10n = AppLocalizations.of(context);
    return [
      _Tab(
        id: 'requests',
        label: l10n.navRequests,
        icon: Icons.move_to_inbox_outlined,
        selectedIcon: Icons.move_to_inbox,
        // Persistent header wallet chip + bell on the Requests header
        // (`orders_home_wallet_chip`/`orders_home_bell`), overlaid by the shell
        // so the per-screen HomeTab surface stays untouched.
        page: const _HeaderedTab(
          idPrefix: 'orders_home',
          child: HomeTab(),
        ),
      ),
      _Tab(
        id: 'delivery',
        label: l10n.navDelivery,
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        page: const OrdersTab(),
      ),
      // ADDITIVE jeeber tab #1 — the Jeeber dashboard (availability + feed).
      // A jeeber sees the live [DashboardTab] (with the persistent header
      // actions); a regular user sees the [JeeberTabEmptyState] invitation.
      _Tab(
        id: 'dashboard',
        label: l10n.navDashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: showJeeberContent
            ? const _HeaderedTab(
                idPrefix: 'delivery_tab',
                child: DashboardTab(),
              )
            : const JeeberTabEmptyState.dashboard(),
      ),
      // ADDITIVE jeeber tab #2 — Earnings. A jeeber sees the live earnings
      // dashboard; a regular user sees the same become-a-jeeber empty state.
      _Tab(
        id: 'earnings',
        label: l10n.navEarnings,
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        page: showJeeberContent
            ? const EarningsTab()
            : const JeeberTabEmptyState.earnings(),
      ),
      _Tab(
        id: 'profile',
        label: l10n.navProfile,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        // The real CustomerProfileScreen surface + header actions. Shared by
        // every user (a jeeber's per-role rating/rows are the profile screen's
        // own concern). Header ids stay `customer_profile_*` (screen-scoped).
        page: const _HeaderedTab(
          idPrefix: 'customer_profile',
          child: _CustomerProfileTabBody(),
        ),
      ),
    ];
  }
}

/// The shell page stack. Keeps every tab mounted via [IndexedStack] and wraps
/// each child in a [TabVisibility] so a body can react to (re)becoming the
/// selected page (e.g. ClientHomeScreen silently re-pulls on refocus);
/// `updateShouldNotify` only fires for the tab whose visibility flips.
class _ShellBody extends StatelessWidget {
  const _ShellBody({required this.tabs, required this.selectedIndex});

  final List<_Tab> tabs;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        for (var i = 0; i < tabs.length; i++)
          TabVisibility(
            isVisible: i == selectedIndex,
            child: tabs[i].page,
          ),
      ],
    );
  }
}

/// Overlays the shell-owned [ShellHeaderActions] (wallet chip + bell) on the
/// top-right of a tab body without touching the per-screen surface. A `Stack`
/// keeps the actions persistent above whatever the [child] renders (a greeting
/// header or an app bar), so the per-screen surfaces own the body while the
/// shell owns the header actions; the `idPrefix` scopes the ids per screen
/// (`orders_home` / `customer_profile` / `delivery_tab`).
class _HeaderedTab extends StatelessWidget {
  const _HeaderedTab({required this.idPrefix, required this.child});

  final String idPrefix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        PositionedDirectional(
          top: 0,
          end: Spacing.xSmall,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: ShellHeaderActions(idPrefix: idPrefix),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Profile tab body: the real [CustomerProfileScreen].
///
/// Per the UX LAW there is no in-app role *switch* — the jeeber surfaces are
/// additive tabs, not a mode the user flips into from here — so the Profile tab
/// no longer hosts a role toggle. Debug uses the fixture profile view data so
/// the tab renders deterministically.
class _CustomerProfileTabBody extends StatelessWidget {
  const _CustomerProfileTabBody();

  @override
  Widget build(BuildContext context) {
    return const CustomerProfileScreen(
      data: DevCustomerProfileFixtures.sample,
    );
  }
}

class _JeebBottomBar extends StatelessWidget {
  const _JeebBottomBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_Tab> tabs;
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Sizes.fiveXLarge,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _BarItem(
                  tab: tabs[i],
                  isSelected: i == selectedIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final _Tab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final color = isSelected ? colorScheme.primary : colorScheme.outline;
    return Semantics(
      identifier: 'shell_tab_${tab.id}',
      button: true,
      selected: isSelected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? tab.selectedIcon : tab.icon,
              size: Sizes.xLarge,
              color: color,
            ),
            const SizedBox(height: Sizes.threeXSmall),
            Text(
              tab.label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  /// Stable, locale-independent id used for the tab's Semantics identifier so
  /// QA (Maestro) can target tabs without matching on localized labels.
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
