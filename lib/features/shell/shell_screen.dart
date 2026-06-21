import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/di/injection_container.dart';
import '../../core/role/role_availability_cubit.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../l10n/app_localizations.dart';
import '../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../customer_profile/presentation/customer_profile_screen.dart';
import '../settings/application/role_switch_cubit.dart';
import '../settings/data/repositories/dio_role_switch_repository.dart';
import '../settings/domain/role_switch_repository.dart';
import '../settings/presentation/widgets/role_toggle_setting.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'widgets/shell_header_actions.dart';

/// Role-aware bottom-nav shell matching the Figma design (node 56535:2151).
///
/// Figma shows 3 tabs:
/// - [UserRole.client]: Requests / Delivery / Profile
/// - [UserRole.jeeber]: Dashboard / Earnings / Profile
///
/// The bottom bar uses a white background with backdrop blur,
/// Urbanist font for labels, and the Jeeb navy/brown color scheme.
///
/// Reuses Salehly's role-toggle pattern: mode is session-local state
/// toggled from the Profile tab, resetting to tab 0 on switch.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoleCubit, UserRole>(
      listenWhen: (prev, curr) => prev != curr,
      listener: (_, _) => setState(() => _index = 0),
      builder: (context, role) {
        final tabs = _tabsForRole(_effectiveRole(role));
        final safeIndex = _index.clamp(0, tabs.length - 1);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: safeIndex,
              children: tabs.map((t) => t.page).toList(growable: false),
            ),
          ),
          bottomNavigationBar: _JeebBottomBar(
            tabs: tabs,
            selectedIndex: safeIndex,
            onTap: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }

  /// Debug-only: the dev seam can force the jeeber role so the Delivery-tab
  /// upsell (screen 19, hosted by [DashboardTab]) renders deterministically for
  /// capture without a UI role toggle. Always the cubit's role in release.
  UserRole _effectiveRole(UserRole role) {
    if (kDebugMode && DevSeam.current.homeTab == 'unregistered') {
      return UserRole.jeeber;
    }
    return role;
  }

  List<_Tab> _tabsForRole(UserRole role) {
    final l10n = AppLocalizations.of(context);
    switch (role) {
      case UserRole.client:
        return [
          _Tab(
            id: 'requests',
            label: l10n.navRequests,
            icon: Icons.move_to_inbox_outlined,
            selectedIcon: Icons.move_to_inbox,
            // S3 (W1-INT): persistent header wallet chip + bell on the
            // Requests header (JM-023; `orders_home_wallet_chip`/
            // `orders_home_bell`). Overlaid by the shell so the per-screen
            // HomeTab surface (JM-023's) stays untouched.
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
          _Tab(
            id: 'profile',
            label: l10n.navProfile,
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            // S3 (W1-INT, JM-035): swap the dev `ProfileTab` surface for the
            // REAL CustomerProfileScreen, plus the persistent header wallet
            // chip + bell (`customer_profile_wallet_chip`/`_bell`). The JM-035
            // engineer wires the real getMe-backed view data + the row
            // navigations + avatar/name/rating ids; the integrator owns this
            // tab-body swap + the header actions. Debug renders the fixture
            // view data (release will resolve the real profile cubit, JM-035).
            page: const _HeaderedTab(
              idPrefix: 'customer_profile',
              child: _CustomerProfileTabBody(),
            ),
          ),
        ];
      case UserRole.jeeber:
        return [
          _Tab(
            id: 'dashboard',
            label: l10n.navDashboard,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            // S3 (W2-INT, JM-036): the DELIVERY tab (jeeber Dashboard) gets the
            // persistent header wallet chip + bell — `delivery_tab_wallet_chip`
            // → wallet-hub (honest, the `/wallet` route exists) and
            // `delivery_tab_bell` → notifications (guarded coming-soon until
            // JM-057/W4). The DashboardTab body itself gates register-prompt vs
            // feed off real `user.kycStatus` (JeeberKycStatusGate).
            page: const _HeaderedTab(
              idPrefix: 'delivery_tab',
              child: DashboardTab(),
            ),
          ),
          _Tab(
            id: 'earnings',
            label: l10n.navEarnings,
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments,
            page: const EarningsTab(),
          ),
          _Tab(
            id: 'profile',
            label: l10n.navProfile,
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            // Jeeber profile also gets the real CustomerProfileScreen surface +
            // header actions (the jeeber profile reuses the customer profile
            // shell; the per-role rating/rows are JM-035's). Header ids stay
            // `customer_profile_*` (the screen-scoped id, not role-scoped).
            page: const _HeaderedTab(
              idPrefix: 'customer_profile',
              child: _CustomerProfileTabBody(),
            ),
          ),
        ];
    }
  }
}

/// Overlays the shell-owned [ShellHeaderActions] (wallet chip + bell) on the
/// top-right of a tab body without touching the per-screen surface. A `Stack`
/// keeps the actions persistent above whatever the [child] renders (a greeting
/// header or an app bar), so the per-screen engineers (JM-023 / JM-035 / JM-036)
/// own the body while the integrator owns the header actions (S3). Used on the
/// customer Requests + Profile headers and the jeeber DELIVERY (Dashboard)
/// header; the `idPrefix` scopes the ids per screen (`orders_home` /
/// `customer_profile` / `delivery_tab`).
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

/// The Profile tab body: the real [CustomerProfileScreen] (JM-035), with the
/// DEFECT-C in-app role toggle mounted ABOVE it for dual-role users.
///
/// The shell renders THIS for the Profile tab in both roles. Before DEFECT-C
/// the role toggle ([RoleToggleSetting]) lived only in the unreachable
/// `ProfileTab`/`SettingsScreen` surface, so a dual-role user had no UI path to
/// driver mode. We now mount it here, gated on [RoleAvailabilityCubit.isDualRole]
/// (populated from getMe `available_roles` by [RoleSync]). The toggle is
/// server-backed: selecting Jeeber POSTs `/v1/users/me/role/switch` (keeping the
/// OTP session, per the iter5 DEFECT-1 fix), then mirrors to [RoleCubit] so the
/// shell rebuilds onto the jeeber surface — and is fully reversible back to
/// client. Single-role clients see no toggle (the section renders nothing).
///
/// Debug uses the fixture profile view data so the tab renders deterministically.
class _CustomerProfileTabBody extends StatelessWidget {
  const _CustomerProfileTabBody();

  @override
  Widget build(BuildContext context) {
    // Optional provider: a bare shell harness (e.g. shell_role_tabs_test) may
    // not register RoleAvailabilityCubit. When absent, render the profile alone
    // (no toggle) — the toggle is an additive dual-role affordance, never a
    // hard dependency of the Profile tab.
    final availabilityCubit = context.watch<RoleAvailabilityCubit?>();
    const profile = CustomerProfileScreen(
      data: DevCustomerProfileFixtures.sample,
    );
    final availability = availabilityCubit?.state;
    if (availability == null || !availability.isDualRole) return profile;
    return Column(
      children: [
        _ShellRoleToggle(availableRoles: availability.roles),
        const Expanded(child: profile),
      ],
    );
  }
}

/// Hosts the server-backed [RoleToggleSetting] for the dual-role user, wired to
/// a fresh [RoleSwitchCubit] over the shared Dio. Seeds the cubit's active role
/// from the current [RoleCubit] state so the segmented control reflects the
/// surface the user is on. On selection the cubit POSTs the role switch and
/// (via the widget's existing `_switchRole`) mirrors to [RoleCubit], flipping
/// the shell to the matching surface.
class _ShellRoleToggle extends StatefulWidget {
  const _ShellRoleToggle({required this.availableRoles});

  final List<String> availableRoles;

  @override
  State<_ShellRoleToggle> createState() => _ShellRoleToggleState();
}

class _ShellRoleToggleState extends State<_ShellRoleToggle> {
  late final RoleSwitchCubit _cubit = RoleSwitchCubit(
    repository: _resolveRepository(),
    initialRole:
        context.read<RoleCubit>().state == UserRole.jeeber ? 'jeeber' : 'client',
  );

  RoleSwitchRepository _resolveRepository() {
    // Mirror CustomerProfileScreen: self-provide over the shared Dio without a
    // DI registration. Falls back to a no-op repo in bare widget tests (no DI).
    if (sl.isRegistered<Dio>()) {
      return DioRoleSwitchRepository(sl<Dio>());
    }
    return const _NoopRoleSwitchRepository();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RoleToggleSetting(
        availableRoles: widget.availableRoles,
        cubit: _cubit,
      ),
    );
  }
}

/// Inert role-switch repository for the no-DI (bare widget test) fall-through —
/// reports success without a network call so the toggle still mirrors to
/// [RoleCubit]. Production always resolves the Dio-backed repo.
class _NoopRoleSwitchRepository implements RoleSwitchRepository {
  const _NoopRoleSwitchRepository();

  @override
  Future<RoleSwitchResult> switchRole(String role) async =>
      RoleSwitchResult.success;
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
