import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../core/role/widgets/role_toggle.dart';
import '../../l10n/app_localizations.dart';
import 'tabs/chat_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/profile_tab.dart';

/// Role-aware bottom-nav shell.
///
/// - [UserRole.client]: Home / Orders / Chat / Profile
/// - [UserRole.jeeber]: Dashboard / Earnings / Chat / Profile
///
/// The selected tab is local state; switching roles via Profile clamps the
/// index to 0 so we never land on a tab that just disappeared.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RoleCubit, UserRole>(
      listenWhen: (prev, curr) => prev != curr,
      listener: (_, __) => setState(() => _index = 0),
      builder: (context, role) {
        final tabs = _tabsForRole(role, l10n);
        final safeIndex = _index.clamp(0, tabs.length - 1);
        return Scaffold(
          appBar: OMDSAppBar(title: tabs[safeIndex].label),
          body: Column(
            children: [
              if (safeIndex == 0) const RoleToggle(),
              Expanded(
                child: IndexedStack(
                  index: safeIndex,
                  children: tabs.map((t) => t.page).toList(growable: false),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final tab in tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                  tooltip: tab.label,
                ),
            ],
          ),
        );
      },
    );
  }

  List<_Tab> _tabsForRole(UserRole role, AppLocalizations l10n) {
    switch (role) {
      case UserRole.client:
        return [
          _Tab(
            label: l10n.navHome,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            page: const HomeTab(),
          ),
          _Tab(
            label: l10n.navOrders,
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            page: const OrdersTab(),
          ),
          _Tab(
            label: l10n.navChat,
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            page: const ChatTab(),
          ),
          _Tab(
            label: l10n.navProfile,
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            page: const ProfileTab(),
          ),
        ];
      case UserRole.jeeber:
        return [
          _Tab(
            label: l10n.navDashboard,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            page: const DashboardTab(),
          ),
          _Tab(
            label: l10n.navEarnings,
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments,
            page: const EarningsTab(),
          ),
          _Tab(
            label: l10n.navChat,
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            page: const ChatTab(),
          ),
          _Tab(
            label: l10n.navProfile,
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            page: const ProfileTab(),
          ),
        ];
    }
  }
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
