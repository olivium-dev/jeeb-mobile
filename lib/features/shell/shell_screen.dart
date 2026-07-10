import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../core/session/jeeber_kyc_status_gate.dart';
import '../../l10n/app_localizations.dart';
import '../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../customer_profile/domain/customer_profile_repository.dart';
import '../customer_profile/presentation/customer_profile_screen.dart';
import '../earnings/domain/earnings_repository.dart';
import '../home_client/domain/client_home_repository.dart';
import '../jeeber_home/domain/services/availability_gateway.dart';
import '../jeeber_request_feed/data/request_feed_repository.dart';
import '../order_history/domain/order_repository.dart';
import '../rate_app/domain/app_review_launcher.dart';
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
  const ShellScreen({
    super.key,
    this.homeTabRepository,
    this.homeTabGreetingRepository,
    this.ordersRepository,
    this.profileRepository,
    this.profileReviewLauncher,
    this.dashboardKycStatusGate,
    this.dashboardAvailabilityGateway,
    this.dashboardRequestFeedRepository,
    this.dashboardGreetingRepository,
    this.earningsRepository,
    this.earningsJeeberId,
  });

  // ── DT-04 catalog / test seams ────────────────────────────────────────
  // Every field below is additive and forwarded 1:1 to the tab it names;
  // `null` (the default for every real call site) reproduces the exact
  // pre-existing behaviour of that tab. They exist solely so the Dev Tool
  // Screen Catalog (DT-04) can preview the real [ShellScreen] with local
  // fakes and NO network, without touching any tab's own resolution logic.

  /// Forwarded to [HomeTab.repository].
  final ClientHomeRepository? homeTabRepository;

  /// Forwarded to [HomeTab.greetingRepository].
  final CustomerProfileRepository? homeTabGreetingRepository;

  /// Forwarded to [OrdersTab.repository].
  final OrderRepository? ordersRepository;

  /// Forwarded to the Profile tab's [CustomerProfileScreen.repository].
  final CustomerProfileRepository? profileRepository;

  /// Forwarded to the Profile tab's [CustomerProfileScreen.reviewLauncher].
  final AppReviewLauncher? profileReviewLauncher;

  /// Forwarded to [DashboardTab.kycStatusGate].
  final JeeberKycStatusGate? dashboardKycStatusGate;

  /// Forwarded to [DashboardTab.availabilityGateway].
  final AvailabilityGateway? dashboardAvailabilityGateway;

  /// Forwarded to [DashboardTab.requestFeedRepository].
  final RequestFeedRepository? dashboardRequestFeedRepository;

  /// Forwarded to [DashboardTab.greetingRepository].
  final CustomerProfileRepository? dashboardGreetingRepository;

  /// Forwarded to [EarningsTab.repository].
  final EarningsRepository? earningsRepository;

  /// Forwarded to [EarningsTab.jeeberId].
  final String? earningsJeeberId;

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
            page: _HeaderedTab(
              idPrefix: 'orders_home',
              child: HomeTab(
                repository: widget.homeTabRepository,
                greetingRepository: widget.homeTabGreetingRepository,
              ),
            ),
          ),
          _Tab(
            id: 'delivery',
            label: l10n.navDelivery,
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            page: OrdersTab(repository: widget.ordersRepository),
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
            page: _HeaderedTab(
              idPrefix: 'customer_profile',
              child: _CustomerProfileTabBody(
                repository: widget.profileRepository,
                reviewLauncher: widget.profileReviewLauncher,
              ),
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
            page: _HeaderedTab(
              idPrefix: 'delivery_tab',
              child: DashboardTab(
                kycStatusGate: widget.dashboardKycStatusGate,
                availabilityGateway: widget.dashboardAvailabilityGateway,
                requestFeedRepository: widget.dashboardRequestFeedRepository,
                greetingRepository: widget.dashboardGreetingRepository,
              ),
            ),
          ),
          _Tab(
            id: 'earnings',
            label: l10n.navEarnings,
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments,
            page: EarningsTab(
              repository: widget.earningsRepository,
              jeeberId: widget.earningsJeeberId,
            ),
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
            page: _HeaderedTab(
              idPrefix: 'customer_profile',
              child: _CustomerProfileTabBody(
                repository: widget.profileRepository,
                reviewLauncher: widget.profileReviewLauncher,
              ),
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

/// The Profile tab body: the real [CustomerProfileScreen] (JM-035). Debug uses
/// the fixture view data so the tab renders deterministically; the JM-035
/// engineer swaps in the real getMe-backed cubit/repository (the integrator
/// does NOT build that here). Release renders the same fixture shell until
/// JM-035 wires the data source (no PII leak — the fixture is sample data).
class _CustomerProfileTabBody extends StatelessWidget {
  const _CustomerProfileTabBody({this.repository, this.reviewLauncher});

  /// DT-04 catalog / test seam — forwarded to
  /// [CustomerProfileScreen.repository]. `null` reproduces the existing
  /// self-provided resolution.
  final CustomerProfileRepository? repository;

  /// DT-04 catalog / test seam — forwarded to
  /// [CustomerProfileScreen.reviewLauncher]. `null` reproduces the existing
  /// self-provided resolution.
  final AppReviewLauncher? reviewLauncher;

  @override
  Widget build(BuildContext context) {
    return CustomerProfileScreen(
      data: DevCustomerProfileFixtures.sample,
      repository: repository,
      reviewLauncher: reviewLauncher,
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
