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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/order_history/order_history_screen_preview_test.dart
// ===========================================================================
//
// [OrderHistoryScreen] renders no data of its own: it reads an ambient
// [OrderHistoryCubit] and posts `initialLoad()` for the frame after mount. So
// every preview below provides that cubit over a local fake repository —
// exactly what `OrdersTab` does in production, minus the DI and the Dio — and
// the real cold-load path runs the way it does on a device.
//
// The fakes and the casts are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/order_history_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_08_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". None of those repositories can reach the network — they answer from
// a static list, throw, or never complete.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **This screen does NOT own a Scaffold.** It is a bare `Column` ending in
//    `Expanded(TabBarView)`, so it needs a parent with a BOUNDED height or it
//    cannot lay out at all. [jeebPreviewHost]'s `Scaffold + SafeArea` is that
//    parent — the same shape the shell's `IndexedStack` gives it in production
//    — and nothing here adds a second one.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_orderHistoryScreenFramed] pins the width in the widget tree so the
//    render tests measure a phone rather than the 800 pt test surface, where
//    every squeeze under review disappears. Height is pinned too, but the
//    render surface is 800x600, so a `SizedBox` asking for 844 is enforced down
//    to what the host has; the COMPACT box (320x568) fits and is exact.
//  * **The date filter is seeded through the cubit, not the sheet.**
//    `applyDateRange` is the same call the sheet makes on Apply, so the
//    filtered state is the real post-filter state and not a painted mock.
//
// Two hazards this screen has that the previews expose rather than hide:
//
//  * **Tapping a row is not previewable.** The row's `onTap` is
//    `context.push('/orders/:id')` (or `/jeeber/deliveries/:id/active` when a
//    [RoleCubit] above it says jeeber), which resolves a [GoRouter] that exists
//    above neither a preview card nor a catalog state. Tapping throws. The
//    filter chip is fine by contrast — its sheet is a plain
//    `showModalBottomSheet` + `Navigator.pop`, no router involved — so the one
//    affordance that opens a real flow is also the one that cannot be tried.
//  * **The COMPLETED and CANCELLED tabs cannot be previewed.** `_tabController`
//    is created at index 0 and is only ever driven by the user's tap on the
//    [TabBar]; it does not read `state.activeTab`, so no fixture, cubit seed or
//    ambient state can open this screen on another tab. Everything below is the
//    Active tab. `_emptySubtitle`'s Completed/Cancelled copy therefore has no
//    dev surface at all — see the finding at the end of this note.
//
// The states are the four the Screen Catalog names plus two it does not, and
// both extras are states that break:
//
//   * **Date filter applied.** The one control on this screen that changes
//     LAYOUT with the text scaler.
//   * **Longest content at 320 pt.** The layout ceiling on the narrowest phone
//     the app supports, in a zero-decimal currency.
//
// What the canvas shows that no test asserted before this section landed. Every
// number is measured off the render tree through the REAL Inter and Noto Arabic
// faces — under Flutter's 1-em test face Latin measures ~2x too wide and Arabic
// ~2.4x, so widths taken there report breakages that exist on no device.
//
// * **The filter chip loses its gutter above 1.5x text.** `_FilterBar` swaps to
//   `usesLargeText` above [_kLargeFilterTextScaleThreshold], and that branch
//   sets the row's horizontal padding to ZERO on both sides. Measured on the
//   390 pt frame: at 1x the chip sits 16.0 dp from each edge, at 200% it starts
//   at x=0 — flush against the leading edge — while the cards below it keep
//   their inset, and in AR at 200% it is flush against the RIGHT edge instead.
//   The swap exists to stop the label clipping, and the horizontal
//   `SingleChildScrollView` it adds does achieve that; the gutter is collateral.
//   The same branch also changes the chip's silhouette: `Expanded` makes it
//   full-bleed (358.0 dp of a 390 pt frame) at 1x and the scroll view lets it
//   shrink-wrap (238.9 dp) at 200%, so one control has two shapes.
// * **The EN tab labels clip at 200% and the AR ones do not.** `Tab` lays its
//   label out with `softWrap: false` + `TextOverflow.fade` and this [TabBar] is
//   not scrollable, so a label that outgrows its third of the bar fades away
//   mid-word instead of wrapping. At 200% on 390 pt "Completed" wants 147.0 dp
//   of the 98.0 it is given; the Arabic "منجَزة" wants 85.5 and gets 85.5. The
//   locale that looks fine is the one that is not being squeezed.
// * **The error body is the one branch with no scroll view.** The empty branch
//   is wrapped in `OmdsPullToRefresh → ListView`; the error branch is returned
//   BARE into the `TabBarView`, and `OmdsErrorState` is a `mainAxisSize.min`
//   Column (64 pt icon, title, message, retry) centred in whatever it is given.
//   Nothing scrolls it, so a tab body shorter than the content clips the "Try
//   again" button — the only recovery affordance on a state whose
//   pull-to-refresh is absent. It does NOT clip at the sizes this screen is
//   reviewed at: measured through the real faces on 390 pt, icon-top to
//   button-bottom is 214.0 dp at 1x and 388.0 dp at 200% (296.5 in AR) inside a
//   486 dp body, so the button clears the frame by 51 dp at the ceiling. Add
//   `OmdsErrorState`'s own 20 dp padding and the branch needs ~428 dp of tab
//   area before it starts losing the button. Worth stating plainly because the
//   `OrdersTab` preview section still describes this as overflowing at 1.6x —
//   that reading was taken under Flutter's 1-em test face, where the wrapped
//   message measures roughly twice as tall as it does on a device.
// * **A tab that is switched from the CUBIT desyncs from the TabBar.**
//   `OrderHistoryCubit.selectTab` is public and moves `state.activeTab`, which
//   drives the snackbar listener's `state.currentTab`; the [TabController] that
//   drives what is on screen is never told. Today only `_onTabChanged` calls
//   it, so the two agree — but nothing enforces that, and it is why the
//   Completed/Cancelled bodies have no preview.

/// The phone this screen is designed against. Taller than the 800x600 render
/// surface on purpose: the canvas honours it, the render tests get what the
/// host allows, and both are a phone rather than a desktop-width slab.
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
///
/// [range] seeds the date filter through `applyDateRange`, the same call the
/// filter sheet makes on Apply. It is fire-and-forget because the fakes resolve
/// on the next microtask, long before the first frame is painted; the screen's
/// own `initialLoad()` then finds the tab already loaded and no-ops.
///
/// [muteTicker] freezes indefinite animations. `OmdsLoadingState` renders a
/// [CircularProgressIndicator], which never stops scheduling frames, and the
/// render tests' `pumpAndSettle` would hang on it. Muting the ticker still
/// paints the arc — it just stops it spinning, which is what a static canvas
/// wanted anyway.
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
///
/// Two rows rather than one because a single card cannot show the *rhythm* of
/// the list — the hairline [Divider], the 8 pt vertical padding, and the status
/// chips lining up down the trailing edge.
///
/// This is the one the matrix is for, and there are three separate things to
/// look at in it. The AR rendering mirrors the whole surface: the chip moves to
/// the right edge, the tab indicator runs right-to-left, and each card's
/// leading pickup icon swaps sides — all of which only works because every
/// inset on the path is [EdgeInsetsDirectional]. The 200% rendering is where
/// the [TabBar] gives up: `Tab` lays its label out with `softWrap: false` and
/// `TextOverflow.fade` and there is no scrollable-tabs fallback, so "Completed"
/// fades mid-word — 147.0 dp of label into the 98.0 dp it is given. The Arabic
/// label is short enough to survive (85.5 into 85.5), which is exactly why the
/// EN card is the one to check.
///
/// `REQ-1038` carries no amount, so the T11 / SW-02 em-dash — never a
/// fabricated `$0.00` — is on screen beside a priced row for comparison.
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
///
/// Worth a preview of its own because "No orders yet" is also the exact surface
/// a wrongly-scoped tab strands on (JEBV4-280: a jeeber hitting the customer
/// list got an empty page and this screen). Seeing it rendered is a reminder
/// that the empty state and that bug are indistinguishable — the copy is
/// reassuring and it is the same copy either way.
///
/// Note what this branch has and the error branch below does not: the empty
/// state is wrapped in `OmdsPullToRefresh → ListView`, so it scrolls and can be
/// pulled to retry.
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
///
/// Only a COLD load reaches this surface. A failed refresh or a failed
/// next-page keeps the list on screen and surfaces the same copy in a snackbar
/// instead — that transient path is a state TRANSITION and has no still frame,
/// so no preview can show it.
///
/// **This branch is the one with no scroll view.** `OmdsErrorState` is a
/// `mainAxisSize.min` Column returned bare into the `TabBarView`, so nothing
/// can bring the "Try again" button back into view if the tab body is ever
/// shorter than the content — there is no scroll and, unlike the empty branch,
/// no pull gesture either. On the frames this screen is reviewed at it does not
/// come to that: at 200% text the content measures 388.0 dp inside a 486 dp
/// body and the button clears the bottom by 51. The margin is real but it is
/// margin, not structure; the fix is the `OmdsPullToRefresh → ListView` wrapper
/// the empty branch already has.
///
/// The network branch (`orderHistoryErrorNetwork`, "You appear to be offline.")
/// pairs the SAME title and layout with different body copy; it is not a
/// separate preview because only the sentence changes.
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
///
/// Every customer who opens the Delivery tab sees this — `initialLoad()` is
/// posted for the frame after mount and the first frame is painted before it
/// can return. Note what stays up while it spins: the filter chip and the tab
/// bar are outside the `TabBarView`, so only the list area swaps, and the chip
/// remains tappable over a list that does not exist yet.
///
/// The ticker is muted so a static canvas (and `pumpAndSettle`) has something
/// to settle on; see [_orderHistoryScreenHosted].
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
///
/// **Matrixed because this chip is the only thing on the screen whose LAYOUT
/// changes with the text scaler.** Above [_kLargeFilterTextScaleThreshold]
/// (1.5) `_FilterBar` drops the chip's `Icons.tune` glyph, wraps it in a
/// horizontal `SingleChildScrollView` so the longer label can scroll instead of
/// clipping — and sets the row's horizontal padding to ZERO. The 200% rendering
/// is where to see the cost: measured on 390 pt, the chip moves from 16.0 dp
/// off the leading edge to 0.0 while every card below it keeps its inset, and
/// it goes from full-bleed (358.0 dp) to shrink-wrapped (238.9). The AR card
/// shows the same thing against the right edge.
///
/// The selected palette is the second reason to look: `isSelected` swings
/// `OmdsChip` to `colorScheme.primary`, which is the one chip colour the AR RTL
/// **dark** card of this matrix has to prove readable.
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
///
/// Two full-length Beirut addresses and `LBP 1,335,000.00` — a $15 delivery at
/// the 2026 peg, and the widest money token the app can produce — on a 320 pt
/// frame. Three squeezes meet on the first card and each fails differently: the
/// header Row ellipsizes the date rather than pushing the status chip off the
/// edge, both address lines are `maxLines: 2` + ellipsis (so a real third line
/// of address is silently LOST, not wrapped), and the footer Row gives the tier
/// label an `Expanded` beside an amount with no `Flexible` at all — so the
/// amount takes its natural width first and the label pays for it.
///
/// The second row is short and carries a status this build has never heard of:
/// [OrderRequestStatus.unknown] buckets into Active and renders the localized
/// "In progress" rather than vanishing, which is what keeps a gateway-side
/// status addition visible to the user and to QA.
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
