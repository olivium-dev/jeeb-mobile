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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/order_history_screen_fixtures.dart';
import '../domain/order_repository.dart';

const double _kLargeFilterTextScaleThreshold = 1.5;

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
        // jeebers (F6/JEBV4-303 scopes the LIST by active role). A tapped row must
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this screen is designed against. Taller than the 800x600 render
/// surface on purpose: the canvas honours it, the render tests get what the
const Size _orderHistoryScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _orderHistoryScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _orderHistoryScreenFramed(
  Widget screen, {
  Size box = _orderHistoryScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way `OrdersTab` builds it — one [OrderHistoryCubit]
/// over one injected repository, no DI — pinned to a device frame.
Widget _orderHistoryScreenHosted(
  OrderRepository repository, {
  Size box = _orderHistoryScreenPhoneBox,
  OrderDateRange? range,
  bool muteTicker = false,
}) {
  final Widget screen = BlocProvider<OrderHistoryCubit>(
    create: (_) {
      final OrderHistoryCubit cubit = OrderHistoryCubit(
        repository: repository,
      );
      if (range != null) unawaited(cubit.applyDateRange(range));
      return cubit;
    },
    child: const OrderHistoryScreen(),
  );
  return _orderHistoryScreenFramed(
    muteTicker ? TickerMode(enabled: false, child: screen) : screen,
    box: box,
  );
}

/// The reference reading: two live deliveries at different points of the
/// journey, under the unfiltered chip and the three-tab bar.
@JeebPreview(
  group: 'order_history',
  name: 'Active · two live deliveries',
  size: _orderHistoryScreenPhoneBox,
  matrix: true,
)
Widget orderHistoryScreenActive() => _orderHistoryScreenHosted(
      OrderHistoryScreenStaticOrders(
        OrderHistoryScreenOrders.activePopulated,
      ),
    );

/// A read that SUCCEEDED and came back with zero rows.
/// Worth a preview of its own because "No orders yet" is also the exact surface
@JeebPreview(
  group: 'order_history',
  name: 'Empty · no orders yet',
  size: _orderHistoryScreenPhoneBox,
)
Widget orderHistoryScreenEmpty() => _orderHistoryScreenHosted(
      const OrderHistoryScreenStaticOrders(OrderHistoryScreenOrders.none),
    );

/// The cold read failed: an [OmdsErrorState] with a Retry that re-enters
/// `refresh()`.
@JeebPreview(
  group: 'order_history',
  name: 'Error · cold load failed',
  size: _orderHistoryScreenPhoneBox,
)
Widget orderHistoryScreenErrorServer() => _orderHistoryScreenHosted(
      const OrderHistoryScreenFailingOrders(OrderRepositoryErrorKind.server),
    );

/// The first page is still in flight: a centered [OmdsLoadingState] and nothing
/// else.
@JeebPreview(
  group: 'order_history',
  name: 'Loading · first page',
  size: _orderHistoryScreenPhoneBox,
)
Widget orderHistoryScreenLoadingFirstPage() => _orderHistoryScreenHosted(
      const OrderHistoryScreenStalledOrders(),
      muteTicker: true,
    );

/// A date range is applied: the chip flips to selected and reads "Date filter
/// applied", and the list is whatever survived the filter — here one delivery.
@JeebPreview(
  group: 'order_history',
  name: 'Date filter applied',
  size: _orderHistoryScreenPhoneBox,
  matrix: true,
)
Widget orderHistoryScreenDateFilterApplied() => _orderHistoryScreenHosted(
      OrderHistoryScreenStaticOrders(
        OrderHistoryScreenOrders.dateFilteredSlice,
      ),
      range: orderHistoryScreenFilterRange,
    );

/// The layout ceiling on the narrowest phone the app supports.
/// Two full-length Beirut addresses and `LBP 1,335,000.00` — a $15 delivery at
@JeebPreview(
  group: 'order_history',
  name: 'Longest content · compact 320',
  size: _orderHistoryScreenCompactBox,
)
Widget orderHistoryScreenLongestContent() => _orderHistoryScreenHosted(
      OrderHistoryScreenStaticOrders(
        OrderHistoryScreenOrders.longestContent,
      ),
      box: _orderHistoryScreenCompactBox,
    );
