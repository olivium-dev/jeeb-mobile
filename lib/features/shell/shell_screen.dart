import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/lifecycle/route_visibility.dart';
import '../../core/notifications/application/badge_count_cubit.dart';
import '../../core/role/role_availability_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../customer_profile/domain/customer_profile_view_data.dart';
import '../customer_profile/presentation/customer_profile_screen.dart';
import '../home_client/domain/client_home_repository.dart';
import '../order_history/domain/order_repository.dart';
import 'tab_visibility.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'widgets/jeeber_tab_empty_state.dart';
import 'widgets/shell_header_actions.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    this.homeRepository,
    this.ordersRepository,
  });

  final ClientHomeRepository? homeRepository;

  final OrderRepository? ordersRepository;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const String _jeeberLandingTabId = 'dashboard';

  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final availability = context.watch<RoleAvailabilityCubit?>()?.state;
    final showJeeberContent = _showJeeberContent(availability);
    final requestBadgeCount =
        context.watch<BadgeCountCubit?>()?.state.newRequests ?? 0;
    final tabs = _tabs(
      showJeeberContent: showJeeberContent,
      requestBadgeCount: requestBadgeCount,
    );
    final landingIndex = _landingIndex(tabs, isJeeber: showJeeberContent);
    final safeIndex = (_selectedIndex ?? landingIndex).clamp(0, tabs.length - 1);
    return Scaffold(
      body: SafeArea(
        bottom: false,

        child: RouteVisibilityScope(
          child: _NavBarContentInset(
            child: IndexedStack(
              index: safeIndex,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  TabVisibility(
                    isVisible: i == safeIndex,
                    child: tabs[i].page,
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _JeebBottomBar(
        tabs: tabs,
        selectedIndex: safeIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  int _landingIndex(List<_Tab> tabs, {required bool isJeeber}) {
    if (!isJeeber) return 0;
    final jeeberIndex =
        tabs.indexWhere((t) => t.id == _jeeberLandingTabId);
    return jeeberIndex >= 0 ? jeeberIndex : 0;
  }

  bool _showJeeberContent(RoleAvailability? availability) {
    if (kDebugMode) {
      final seam = DevSeam.current;
      if (seam.feed.isNotEmpty || seam.homeTab == 'unregistered') return true;
    }
    return availability?.roles.contains('jeeber') ?? false;
  }

  List<_Tab> _tabs({
    required bool showJeeberContent,
    required int requestBadgeCount,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      _Tab(
        id: 'requests',
        label: l10n.navRequests,
        icon: Icons.move_to_inbox_outlined,
        selectedIcon: Icons.move_to_inbox,
        page: _HeaderedTab(
          idPrefix: 'orders_home',
          child: HomeTab(repository: widget.homeRepository),
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
        id: _jeeberLandingTabId,
        label: l10n.navDashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        badgeCount: requestBadgeCount,
        page: showJeeberContent
            ? const _HeaderedTab(
                idPrefix: 'delivery_tab',
                child: DashboardTab(),
              )
            : const JeeberTabEmptyState.dashboard(),
      ),
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
        page: const _HeaderedTab(
          idPrefix: 'customer_profile',
          child: _CustomerProfileTabBody(),
        ),
      ),
    ];
  }
}

class _NavBarContentInset extends StatelessWidget {
  const _NavBarContentInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding:
            mq.padding.copyWith(bottom: mq.padding.bottom + Sizes.fiveXLarge),
        viewPadding: mq.viewPadding
            .copyWith(bottom: mq.viewPadding.bottom + Sizes.fiveXLarge),
      ),
      child: child,
    );
  }
}

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

class _CustomerProfileTabBody extends StatelessWidget {
  const _CustomerProfileTabBody();

  @override
  Widget build(BuildContext context) {
    return const CustomerProfileScreen(data: CustomerProfileViewData());
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
    final icon = Icon(
      isSelected ? tab.selectedIcon : tab.icon,
      size: Sizes.xLarge,
      color: color,
    );
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
            if (tab.badgeCount > 0)
              Semantics(
                identifier: 'shell_tab_${tab.id}_badge',
                container: true,
                child: Badge.count(count: tab.badgeCount, child: icon),
              )
            else
              icon,
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
    this.badgeCount = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  final int badgeCount;
}
