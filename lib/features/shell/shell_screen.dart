import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../l10n/app_localizations.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/profile_tab.dart';

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
      listener: (_, __) => setState(() => _index = 0),
      builder: (context, role) {
        final tabs = _tabsForRole(role);
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
            page: const HomeTab(),
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
            page: const ProfileTab(),
          ),
        ];
      case UserRole.jeeber:
        return [
          _Tab(
            id: 'dashboard',
            label: l10n.navDashboard,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            page: const DashboardTab(),
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
            page: const ProfileTab(),
          ),
        ];
    }
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
      identifier: '_request_empty_state_nav_${tab.id}',
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
