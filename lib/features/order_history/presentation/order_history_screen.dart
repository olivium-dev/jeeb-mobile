import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../application/order_history_cubit.dart';
import '../application/order_history_state.dart';
import '../domain/order_summary.dart';
import 'order_history_card.dart';
import 'order_history_date_filter_sheet.dart';

/// Text scale above which the compact filter chip switches to a scrollable,
/// icon-free layout to preserve its accessible label without clipping.
const double _kLargeFilterTextScaleThreshold = 1.5;

/// The screen the user lands on from the "Orders" bottom tab. Owns the
/// TabBar (Active / Completed / Cancelled), the date filter affordance,
/// and the per-tab list with pull-to-refresh + infinite scroll.
///
/// Navigation off this screen is via go_router — `/orders/:id` already
/// exists and renders [DeliveryDetailScreen].
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: OrderHistoryTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    // Defer the cubit kick-off until after the first frame so listeners
    // mounted by [BlocProvider] downstream see the initial state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrderHistoryCubit>().initialLoad();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = OrderHistoryTab.values[_tabController.index];
    context.read<OrderHistoryCubit>().selectTab(tab);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<OrderHistoryCubit, OrderHistoryState>(
      listenWhen: (prev, curr) =>
          prev.currentTab.errorKind != curr.currentTab.errorKind &&
          curr.currentTab.errorKind != null &&
          curr.currentTab.status == OrderTabStatus.ready,
      listener: (context, state) {
        // Transient errors (failed pagination or refresh) — the list stays
        // visible, we just nudge the user with a snackbar.
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(_errorMessage(state.currentTab.errorKind!, l10n)),
          ),
        );
      },
      builder: (context, state) {
        return Semantics(
          identifier: 'order_history_root',
          container: true,
          child: Column(
            children: [
              _FilterBar(
                range: state.dateRange,
                onTap: () => _openFilter(state.dateRange),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Semantics(
                    identifier: 'order_history_active_tab',
                    container: true,
                    button: true,
                    child: Tab(text: l10n.orderHistoryTabActive),
                  ),
                  Semantics(
                    identifier: 'order_history_completed_tab',
                    container: true,
                    button: true,
                    child: Tab(text: l10n.orderHistoryTabCompleted),
                  ),
                  Semantics(
                    identifier: 'order_history_cancelled_tab',
                    container: true,
                    button: true,
                    child: Tab(text: l10n.orderHistoryTabCancelled),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final tab in OrderHistoryTab.values)
                      _OrderTabView(tab: tab, key: ValueKey(tab)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFilter(OrderDateRange current) async {
    final result = await showOrderHistoryDateFilterSheet(
      context: context,
      initial: current,
    );
    if (result != null && mounted) {
      await context.read<OrderHistoryCubit>().applyDateRange(result);
    }
  }

  static String _errorMessage(OrderTabErrorKind kind, AppLocalizations l10n) {
    switch (kind) {
      case OrderTabErrorKind.network:
        return l10n.orderHistoryErrorNetwork;
      case OrderTabErrorKind.server:
        return l10n.orderHistoryErrorServer;
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.range, required this.onTap});

  final OrderDateRange range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usesLargeText =
        MediaQuery.textScalerOf(context).scale(1) >
        _kLargeFilterTextScaleThreshold;
    final label = range.isEmpty
        ? l10n.orderHistoryFilterCta
        : l10n.orderHistoryFilterActive;
    final chip = Semantics(
      identifier: 'order_history_filter_chip',
      container: true,
      button: true,
      child: OmdsChip(
        key: const Key('order-history-filter-chip'),
        label: label,
        icon: usesLargeText ? null : const Icon(Icons.tune, size: Sizes.medium),
        isSelected: !range.isEmpty,
        onTap: onTap,
      ),
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        usesLargeText ? 0 : Spacing.medium,
        Spacing.small,
        usesLargeText ? 0 : Spacing.medium,
        Spacing.twoXSmall,
      ),
      child: Row(
        children: [
          Expanded(
            child: usesLargeText
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: chip,
                  )
                : chip,
          ),
        ],
      ),
    );
  }
}

/// Renders a single tab's list. Watches the cubit and short-circuits to
/// the matching loading/empty/error widget depending on tab state.
class _OrderTabView extends StatefulWidget {
  const _OrderTabView({required this.tab, super.key});

  final OrderHistoryTab tab;

  @override
  State<_OrderTabView> createState() => _OrderTabViewState();
}

class _OrderTabViewState extends State<_OrderTabView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Pre-fetch when the user is within one viewport of the bottom —
    // gives the network call time to land before the spinner shows.
    if (pos.pixels >= pos.maxScrollExtent - pos.viewportDimension) {
      context.read<OrderHistoryCubit>().loadMore();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<OrderHistoryCubit, OrderHistoryState>(
      buildWhen: (prev, curr) => prev.tabs[widget.tab] != curr.tabs[widget.tab],
      builder: (context, state) {
        final tabState = state.tabs[widget.tab]!;
        final l10n = AppLocalizations.of(context);
        // BUG-A (courier progression): the Delivery tab is SHARED by clients and
        // jeebers (F6/JEBV4-303 scopes the LIST by active role). A tapped row must
        // route to the surface that matches the ACTIVE role: a client opens the
        // read-only customer delivery detail (`/orders/:id`); an ACTIVE jeeber opens
        // the jeeber active-delivery screen (`/jeeber/deliveries/:id/active`) — the
        // Ordered→Picked→InTransit→AtDoor→Done stepper with the Mark-as controls.
        // Before this, every row went to `/orders/:id`, so a matched jeeber landed
        // on the customer's Live-tracking/Verify-OTP detail with NO way to advance
        // the delivery (it stayed at Ordered). Nullable read keeps bare widget tests
        // (no RoleCubit ancestor) on the unchanged customer path.
        final actingAsJeeber =
            context.watch<RoleCubit?>()?.state == UserRole.jeeber;

        if (tabState.status == OrderTabStatus.loadingFirstPage) {
          return const Center(
            key: Key('order-history-loading'),
            child: OmdsLoadingState(),
          );
        }
        if (tabState.status == OrderTabStatus.error) {
          return OmdsErrorState(
            key: const Key('order-history-error'),
            title: l10n.orderHistoryErrorTitle,
            message: tabState.errorKind == OrderTabErrorKind.network
                ? l10n.orderHistoryErrorNetwork
                : l10n.orderHistoryErrorServer,
            retryLabel: l10n.orderHistoryErrorRetry,
            onRetry: () => context.read<OrderHistoryCubit>().refresh(),
          );
        }
        if (tabState.orders.isEmpty) {
          return OmdsPullToRefresh(
            onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Sizes.sixXLarge,
                  ),
                  child: OmdsEmptyState(
                    key: Key('order-history-empty-${widget.tab.name}'),
                    icon: Icons.receipt_long_outlined,
                    title: l10n.orderHistoryEmptyTitle,
                    subtitle: _emptySubtitle(widget.tab, l10n),
                  ),
                ),
              ],
            ),
          );
        }

        return OmdsPullToRefresh(
          onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
          child: ListView.separated(
            key: Key('order-history-list-${widget.tab.name}'),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
            itemCount: tabState.orders.length + (tabState.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index >= tabState.orders.length) {
                return Padding(
                  key: const Key('order-history-loading-more'),
                  padding: const EdgeInsets.symmetric(vertical: Spacing.medium),
                  child: Center(
                    child: tabState.status == OrderTabStatus.loadingNextPage
                        ? const OmdsLoadingState()
                        : const SizedBox.shrink(),
                  ),
                );
              }
              final order = tabState.orders[index];
              return OrderHistoryCard(
                order: order,
                onTap: () => context.push(
                  actingAsJeeber
                      ? '/jeeber/deliveries/${order.id}/active'
                      : '/orders/${order.id}',
                ),
              );
            },
          ),
        );
      },
    );
  }

  static String _emptySubtitle(OrderHistoryTab tab, AppLocalizations l10n) {
    switch (tab) {
      case OrderHistoryTab.active:
        return l10n.orderHistoryEmptyActive;
      case OrderHistoryTab.completed:
        return l10n.orderHistoryEmptyCompleted;
      case OrderHistoryTab.cancelled:
        return l10n.orderHistoryEmptyCancelled;
    }
  }
}
