import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../l10n/app_localizations.dart';
import '../application/order_history_cubit.dart';
import '../application/order_history_state.dart';
import '../domain/order_summary.dart';
import 'order_history_card.dart';
import 'order_history_date_filter_sheet.dart';

/// Text scale above which the compact filter chip switches to a scrollable,
/// icon-free layout to preserve its accessible label without clipping.
const double _kLargeFilterTextScaleThreshold = 1.5;

/// Board gutter for the header, the tab row and the list (`tpl 1417` / `1422` /
/// `1426` all sit at 24px).
const EdgeInsetsGeometry _kBandPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  0,
);

/// The screen the user lands on from the "Delivery" bottom tab. Owns the
/// title + date-range header, the three filter pills (Active / Completed /
/// Cancelled), and the per-tab list with pull-to-refresh + infinite scroll.
///
/// Navigation off this screen is via go_router — `/orders/:id` already
/// exists and renders [DeliveryDetailScreen].
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({
    super.key,
    this.initialTab = OrderHistoryTab.active,
  });

  /// Which filter pill is selected on first render. Catalog/test seam only —
  /// the shell always lands on Active, and no route reads this.
  final OrderHistoryTab initialTab;

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
      initialIndex: widget.initialTab.index,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    // Defer the cubit kick-off until after the first frame so listeners
    // mounted by [BlocProvider] downstream see the initial state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<OrderHistoryCubit>();
      // `selectTab` no-ops on the cubit's own default, and loads whatever tab
      // it does move to — so `initialLoad` covers exactly the default.
      if (widget.initialTab == cubit.state.activeTab) {
        cubit.initialLoad();
      } else {
        cubit.selectTab(widget.initialTab);
      }
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
      // Warm refresh failures only: pagination has its own footer retry.
      listenWhen: (prev, curr) =>
          prev.currentTab.failure != curr.currentTab.failure &&
          curr.currentTab.failure != null &&
          curr.currentTab.status == OrderTabStatus.ready &&
          curr.currentTab.orders.isNotEmpty,
      listener: (context, state) {
        showJeebErrorSnack(
          context,
          failure: state.currentTab.failure!,
          identifier: 'order_history_refresh_failed_snack',
          retryLabel: l10n.actionRetry,
          onRetry: () => context.read<OrderHistoryCubit>().refresh(),
        );
        context.read<OrderHistoryCubit>().acknowledgeTabError();
      },
      builder: (context, state) {
        return Semantics(
          identifier: 'order_history_root',
          container: true,
          // R21/E4 draw the base wash with one quiet orange glow and no orbit
          // rings or twinkles — `content`, and the shell paints no field.
          child: JeebMidnightField(
            variant: JeebFieldVariant.content,
            // The shell owns the Scaffold, so the header text has no Material
            // ancestor of its own — transparent, paints nothing over the field.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _HistoryHeader(
                    range: state.dateRange,
                    onTap: () => _openFilter(state.dateRange),
                  ),
                  // Free-standing content-width pills, not a Material TabBar: the
                  // board (tpl 1422) is a plain `flex; gap:8` with no indicator and
                  // no 48px row. The TabController/TabBarView stay — they carry
                  // swipe, keep-alive retention and `cubit.selectTab`.
                  JeebChipRow.scrollable(
                    padding: _kBandPadding,
                    children: [
                      for (final (index, tab) in OrderHistoryTab.values.indexed)
                        Semantics(
                          // FROZEN: order_history_{active,completed,cancelled}_tab.
                          identifier: 'order_history_${tab.name}_tab',
                          container: true,
                          button: true,
                          child: JeebSelectChip(
                            role: JeebChipRole.filter,
                            label: _tabLabel(tab, l10n),
                            selected: state.activeTab == tab,
                            count: _tabCount(state, tab),
                            onTap: () => _tabController.animateTo(index),
                          ),
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
            ),
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

  /// A count is shown only once it is TRUE: the tab must be fully loaded
  /// (`!hasMore`), or a loaded-lower-bound would read `Completed 20` for 340
  /// orders. A never-selected tab is lazy, so it simply has no number.
  static int? _tabCount(OrderHistoryState state, OrderHistoryTab tab) {
    final tabState = state.tabs[tab]!;
    final isSettled =
        tabState.status == OrderTabStatus.ready &&
        !tabState.hasMore &&
        tabState.orders.isNotEmpty;
    return isSettled ? tabState.orders.length : null;
  }

  static String _tabLabel(OrderHistoryTab tab, AppLocalizations l10n) {
    switch (tab) {
      case OrderHistoryTab.active:
        return l10n.orderHistoryTabActive;
      case OrderHistoryTab.completed:
        return l10n.orderHistoryTabCompleted;
      case OrderHistoryTab.cancelled:
        return l10n.orderHistoryTabCancelled;
    }
  }
}

/// The board's header band (`tpl 1417`): the screen title on the left, the
/// date-range chip on the right.
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.range, required this.onTap});

  final OrderDateRange range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final usesLargeText =
        MediaQuery.textScalerOf(context).scale(1) >
        _kLargeFilterTextScaleThreshold;

    final chip = Semantics(
      // FROZEN wrapper — the sheet is opened by this id in tests and Maestro.
      identifier: 'order_history_filter_chip',
      container: true,
      button: true,
      child: JeebSelectChip(
        key: const Key('order-history-filter-chip'),
        // The kit-normalized nearest scale to the tile's 8/14 · 12.5/w600
        // glass chip; `filter` would render it as large as the tab pills and
        // invert the header's hierarchy. The tile draws NO leading glyph — the
        // old orange `tune` icon was an unbudgeted accent.
        role: JeebChipRole.quickReply,
        label: _rangeLabel(l10n, locale),
        onTap: onTap,
      ),
    );

    final title = Text(
      // Existing key — the board's title IS the shell tab's own name.
      l10n.navDelivery,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.jeebText.h2.copyWith(color: scheme.onSurface),
    );

    if (usesLargeText) {
      // Above 1.5× the two bands cannot share a line: stack them and let the
      // chip scroll, so its full label survives instead of clipping.
      return Padding(
        padding: _kBandPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: Spacing.small),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: chip,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: _kBandPadding,
      child: Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: Spacing.xSmall),
          chip,
        ],
      ),
    );
  }

  /// `Jun 1 – 30` when both ends are set, an open-ended phrasing when only one
  /// is, and the plain call-to-action when the filter is off.
  String _rangeLabel(AppLocalizations l10n, String locale) {
    final from = range.from;
    // The *displayed* end day; `range.to` is the exclusive next midnight.
    final to = range.inclusiveToDay;
    final format = DateFormat.MMMd(locale);
    if (from != null && to != null) {
      return l10n.orderHistoryFilterRange(
        format.format(from),
        format.format(to),
      );
    }
    if (from != null) {
      return l10n.orderHistoryFilterRangeFrom(format.format(from));
    }
    if (to != null) {
      return l10n.orderHistoryFilterRangeTo(format.format(to));
    }
    return l10n.orderHistoryFilterCta;
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

        // F1: a `refreshing` frame with nothing settled behind it is still a
        // first load — without this it falls through to "No orders yet".
        final bool showLoading =
            tabState.status == OrderTabStatus.loadingFirstPage ||
            (tabState.status == OrderTabStatus.refreshing &&
                tabState.orders.isEmpty &&
                !tabState.settled);
        if (showLoading) {
          return _StateBlock(
            key: const Key('order-history-loading'),
            status: JeebEmptyStateStatus.loading,
            headline: l10n.orderHistoryLoadingHeadline,
            identifier: 'order_history_loading',
          );
        }
        // Error branch before empty: a failed read is never "No orders yet".
        if (tabState.status == OrderTabStatus.error) {
          return JeebStateHost(
            key: const Key('order-history-error'),
            onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
            padding: EdgeInsetsDirectional.only(
              bottom: context.scrollBodyBottomInset,
            ),
            child: JeebFailureBlock(
              failure: tabState.failure ?? const UnknownFailure(),
              identifier: 'order_history_error',
              variant: JeebEmptyStateVariant.parcel,
              headlineOverride: l10n.orderHistoryErrorTitle,
              onRetry: () => context.read<OrderHistoryCubit>().refresh(),
              retryIdentifier: 'order_history_retry_cta',
            ),
          );
        }
        if (tabState.orders.isEmpty) {
          final filtered =
              state.dateRange.from != null || state.dateRange.to != null;
          return JeebPullToRefresh(
            onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
            child: _OrdersEmptyView(
              tab: widget.tab,
              filtered: filtered,
              actingAsJeeber: actingAsJeeber,
              onClearRange: () =>
                  context.read<OrderHistoryCubit>().clearDateRange(),
            ),
          );
        }

        final Widget list = ListView.separated(
          key: Key('order-history-list-${widget.tab.name}'),
          controller: _scrollController,
          padding: EdgeInsetsDirectional.only(
            start: Spacing.xLarge,
            end: Spacing.xLarge,
            top: Spacing.medium,
            bottom: context.scrollBodyBottomInset + Spacing.xLarge,
          ),
          itemCount: tabState.orders.length + (tabState.hasMore ? 1 : 0),
          // R7/R12: the outlines are the separation — a divider between two
          // outlined cards draws a third line nobody asked for.
          separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
          itemBuilder: (context, index) {
            if (index >= tabState.orders.length) {
              if (tabState.loadMoreError != null) {
                return _LoadMoreFailedFooter(
                  failure: tabState.loadMoreError!,
                  onRetry: () => context.read<OrderHistoryCubit>().loadMore(),
                );
              }
              return tabState.status == OrderTabStatus.loadingNextPage
                  ? const _NextPageWait()
                  : const SizedBox.shrink();
            }
            final order = tabState.orders[index];
            void openDetail() => context.push(
              actingAsJeeber
                  ? '/jeeber/deliveries/${order.id}/active'
                  : '/orders/${order.id}',
            );
            return OrderHistoryCard(
              order: order,
              onTap: openDetail,
              // TODO(redesign-24): needs gateway trackingId on
              // GET /v1/requests to deep-link `/orders/:id/tracking` —
              // routed to the detail surface instead, not faked.
              onTrack: openDetail,
              // TODO(redesign-24): needs the request description/tier on
              // GET /v1/requests to pre-fill the re-compose — entering the
              // create flow unseeded, not faked.
              onReorder: () =>
                  GoRouter.of(context).pushNamed('client-location'),
            );
          },
        );

        return JeebPullToRefresh(
          onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
          child: tabState.refreshError == null
              ? list
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        Spacing.xLarge,
                        Spacing.medium,
                        Spacing.xLarge,
                        0,
                      ),
                      child: JeebRefreshFailedNote(
                        failure: tabState.refreshError!,
                        identifier: 'order_history_refresh_failed',
                        onDismiss: () => context
                            .read<OrderHistoryCubit>()
                            .acknowledgeRefreshError(widget.tab),
                        onRetry: () =>
                            context.read<OrderHistoryCubit>().refresh(),
                      ),
                    ),
                    Expanded(child: list),
                  ],
                ),
        );
      },
    );
  }
}

/// The next-page wait, in the SAME `parcel` subject and the same breathing
/// skeleton as this screen's three page states — a footer is a smaller wait,
/// not a second loading idiom.
class _NextPageWait extends StatelessWidget {
  const _NextPageWait();

  /// The parcel orbit — 1px of white at 7% — is subpixel at every inline size,
  /// so the kit's 150 buys 60px of footer over this and no more art.
  static const double _illustrationSize = Sizes.tenXLarge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('order-history-loading-more'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.medium),
      child: JeebEmptyState.compact(
        status: JeebEmptyStateStatus.loading,
        variant: JeebEmptyStateVariant.parcel,
        headline: l10n.orderHistoryLoadingMore,
        identifier: 'order_history_loading_more',
        illustrationSize: _illustrationSize,
      ),
    );
  }
}

/// E4 — "Empty ≠ dead". The kit's `parcel` variant IS this tile: the open glass
/// box, the mic glowing inside, a still bare orbit ring, the 3-sparkle ladder.
class _OrdersEmptyView extends StatelessWidget {
  const _OrdersEmptyView({
    required this.tab,
    this.filtered = false,
    this.actingAsJeeber = false,
    this.onClearRange,
  });

  /// The illustration sits high in the tile, not centred in the residual band.
  static const double topGap = 40;

  final OrderHistoryTab tab;

  /// ES-06: a date range is on, so "No orders yet" would be a lie.
  final bool filtered;

  /// ES-07: the tab is shared, so the copy follows the active role.
  final bool actingAsJeeber;

  final VoidCallback? onClearRange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final VoidCallback? clear = onClearRange;
    final bool showClear = filtered && clear != null;
    return ListView(
      padding: EdgeInsetsDirectional.only(
        top: topGap,
        bottom: context.scrollBodyBottomInset + Sizes.sixXLarge,
      ),
      children: [
        JeebEmptyState(
          key: Key('order-history-empty-${tab.name}'),
          identifier: 'order_history_empty_${tab.name}',
          variant: JeebEmptyStateVariant.parcel,
          reason: showClear
              ? JeebEmptyStateReason.filtered
              : JeebEmptyStateReason.nothingYet,
          headline: filtered
              ? l10n.orderHistoryFilterEmptyTitle
              : (actingAsJeeber
                    ? l10n.orderHistoryEmptyTitleJeeber
                    : l10n.orderHistoryEmptyTitle),
          body: filtered
              ? l10n.orderHistoryFilterEmptyBody
              : _emptySubtitle(tab, l10n, actingAsJeeber),
          // Single door: creating a request lives on the mic in My Requests,
          // so this tile stays text-only on every tab.
          secondaryAction: showClear
              ? JeebCtaButton.text(
                  label: l10n.actionClearFilters,
                  identifier: 'order_history_clear_range_cta',
                  expand: false,
                  onTap: clear,
                )
              : null,
        ),
      ],
    );
  }

  static String _emptySubtitle(
    OrderHistoryTab tab,
    AppLocalizations l10n,
    bool actingAsJeeber,
  ) {
    switch (tab) {
      case OrderHistoryTab.active:
        return actingAsJeeber
            ? l10n.orderHistoryEmptyBodyJeeber
            : l10n.orderHistoryEmptyBody;
      case OrderHistoryTab.completed:
        return l10n.orderHistoryEmptyCompleted;
      case OrderHistoryTab.cancelled:
        return l10n.orderHistoryEmptyCancelled;
    }
  }
}

/// EP-15: a dead NEXT page gets a footer the user can act on, not silence.
class _LoadMoreFailedFooter extends StatelessWidget {
  const _LoadMoreFailedFooter({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('order-history-load-more-failed'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.medium),
      child: Semantics(
        identifier: 'order_history_load_more_error',
        container: true,
        liveRegion: true,
        explicitChildNodes: true,
        child: Column(
          children: <Widget>[
            JeebInfoNote.error(text: failureCopy(l10n, failure).body),
            const SizedBox(height: Spacing.small),
            JeebCtaButton.text(
              label: l10n.actionRetry,
              identifier: 'order_history_load_more_retry',
              expand: false,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading and error twins of [_OrdersEmptyView] — same illustration, kit
/// skeleton / danger tint, centred in the residual band.
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    super.key,
    required this.status,
    required this.headline,
    required this.identifier,
  });

  final JeebEmptyStateStatus status;
  final String headline;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return JeebStateHost(
      onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
      padding: EdgeInsetsDirectional.only(
        bottom: context.scrollBodyBottomInset,
      ),
      child: JeebEmptyState(
        status: status,
        variant: JeebEmptyStateVariant.parcel,
        headline: headline,
        identifier: identifier,
      ),
    );
  }
}
