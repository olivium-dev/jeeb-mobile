/// Widget previews for [OrdersTab] — run with `flutter widget-preview start`.
///
/// [OrdersTab] draws nothing itself: it is the shell's container for the
/// Delivery tab, wiring an [OrderHistoryCubit] over an [OrderRepository] and
/// mounting `OrdersResumeRefetcher → OrderHistoryScreen` underneath. So every
/// preview here is *state*, seeded through the one seam the tab already exposes
/// for exactly this purpose — its `repository` parameter, which the tab
/// documents as the widget-test / DT-04-catalog override and which wins over
/// the role-aware Dio resolution below it. Nothing here touches DI, so
/// `sl.isRegistered<OrderRepository>()` is never consulted and
/// [DioOrderRepository] is never constructed.
///
/// [OrderHistoryCubit] takes no `seed:`, so each state supplies a tiny local
/// fake repository with canned data: one that resolves, one that never
/// completes, one that throws. All three are network-free by construction, not
/// merely by the guard in [jeebPreviewHost].
///
/// Fixture values are lifted from
/// `test/features/order_history/orders_stale_status_chip_test.dart` — the same
/// `order-cod-001` / Hamra → Achrafieh / Express / $6.00 row that file scripts
/// through the live-COD-run status progression — so the preview and the
/// regression test describe the same screen.
///
/// **Why there is no jeeber-scoped preview.** The tab's headline behaviour
/// (JEBV4-280 / F6) is role-aware: an ACTIVE jeeber gets
/// `/v1/deliveries?role=jeeber` instead of `/v1/requests`. That axis is not
/// previewable from here and deliberately is not faked: the role is read from
/// [RoleCubit], whose constructor requires a real `SharedPreferences` — a
/// platform plugin the preview canvas has no binding for. It would also show
/// nothing new, because `repository` (which every preview below must pass to
/// stay off the network) short-circuits the role resolution entirely; the only
/// role-dependent difference left is the *route* a tapped row pushes, which is
/// invisible in a still frame. `orders_stale_status_chip_test.dart` and the
/// role-bleed tests own that axis.
///
/// **The box.** In production the shell hosts this tab inside an `IndexedStack`
/// (`shell_screen.dart`) at full body size, so it lays out against phone width
/// and BOUNDED height — `OrderHistoryScreen` is a `Column` ending in
/// `Expanded(TabBarView)` and cannot survive an unbounded vertical axis. The
/// canvas box supplies both, and [jeebPreviewHost]'s `Scaffold` + `SafeArea` is
/// the same bounded parent the shell provides. Nothing is wrapped in a scroll
/// view here for that reason — unlike `in_progress_tab_preview.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/order_history/domain/order_repository.dart';
import '../../features/order_history/domain/order_summary.dart';
import '../../features/shell/tabs/orders_tab.dart';

/// Phone width, matching the shell body the tab is a child of in production.
const double _phoneWidth = 390;

/// A list box tall enough to show the filter chip, the three-tab bar and two
/// full cards without the ListView taking over — which is the point, since the
/// thing that goes wrong between rows is the rhythm (divider, padding, the
/// status chips lining up down the trailing edge).
const Size _listBox = Size(_phoneWidth, 700);

/// The placeholder states are a single centred block; they need height for the
/// EN 200%-text rendering of the matrix to grow into, not for more rows.
const Size _emptyBox = Size(_phoneWidth, 620);
const Size _errorBox = Size(_phoneWidth, 560);
const Size _loadingBox = Size(_phoneWidth, 400);

/// Canned snapshot, resolved on the next microtask like a real (fast) load.
///
/// Filters by [OrderHistoryTab] the way the gateway's `status` filter does, so
/// tapping Completed/Cancelled in the canvas shows that tab's real content
/// rather than the Active list repeated three times.
class _SeededOrderRepository implements OrderRepository {
  const _SeededOrderRepository(this.orders);

  final List<OrderSummary> orders;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    return OrderPage(
      items: orders
          .where((OrderSummary o) => o.status.tab == tab)
          .toList(growable: false),
      page: page,
      hasMore: false,
    );
  }
}

/// A first page that never returns — the tab stays in
/// [OrderTabStatus.loadingFirstPage] forever, which is the only way to hold the
/// spinner still long enough to look at it.
class _NeverResolvingOrderRepository implements OrderRepository {
  const _NeverResolvingOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) =>
      Completer<OrderPage>().future;
}

/// A first page that fails.
///
/// It MUST throw [OrderRepositoryException] and nothing else: that is the only
/// type `OrderHistoryCubit` catches, so any other error escapes the cubit and
/// takes the preview down instead of rendering the error state the preview is
/// for. Failing on the FIRST call matters too — the cubit only flips to
/// [OrderTabStatus.error] on a cold load; a fake that succeeded once and then
/// threw would keep the list on screen with a snackbar over it.
class _FailingOrderRepository implements OrderRepository {
  const _FailingOrderRepository(this.kind);

  final OrderRepositoryErrorKind kind;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async =>
      throw OrderRepositoryException(kind);
}

/// The tab exactly as `shell_screen.dart` mounts it, with its own repository
/// override supplying the state. No `BlocProvider` here on purpose — the tab
/// owns its cubit, and reproducing that is half of what this file previews.
Widget _hosted(OrderRepository repository) =>
    OrdersTab(repository: repository);

/// One history row, shaped like `_order` in
/// `test/features/order_history/orders_stale_status_chip_test.dart`.
OrderSummary _row({
  required String id,
  required String pickupAddress,
  required String dropoffAddress,
  OrderRequestStatus status = OrderRequestStatus.enRoute,
  OrderTier tier = OrderTier.express,
  int? amountMinor = 600,
  String currency = 'USD',
  DateTime? createdAt,
}) =>
    OrderSummary(
      id: id,
      createdAt: createdAt ?? DateTime.utc(2026, 7, 31, 19, 40),
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      status: status,
      tier: tier,
      amountMinor: amountMinor,
      currency: currency,
    );

/// The happy path: two live deliveries at different points of the journey.
///
/// Two rows rather than one because a single card cannot show the *rhythm* of
/// the list — the hairline `Divider`, the 8 pt vertical padding, and the status
/// chips lining up down the trailing edge (which is the left edge in the AR RTL
/// rendering, and the first thing that stops mirroring if a `Row` ever picks up
/// a non-directional `EdgeInsets`).
///
/// The two statuses are the pair the live COD run actually walked through, so
/// both the `matched` and `enRoute` chip labels — and the identical
/// `primaryContainer` palette they share as Active-tab statuses — are on screen
/// at once.
@JeebPreview(group: 'shell', name: 'Active · two live deliveries', size: _listBox)
Widget ordersTabActiveRows() => _hosted(
      _SeededOrderRepository(<OrderSummary>[
        _row(
          id: 'order-cod-001',
          pickupAddress: 'Hamra',
          dropoffAddress: 'Achrafieh',
        ),
        _row(
          id: 'order-cod-002',
          pickupAddress: 'Mar Mikhael',
          dropoffAddress: 'Badaro',
          status: OrderRequestStatus.matched,
          tier: OrderTier.flash,
          amountMinor: 1250,
        ),
      ]),
    );

/// Nothing in this bucket.
///
/// Worth a preview of its own because "No orders yet" is the exact string a
/// wrongly-scoped tab strands on (JEBV4-280: a jeeber hitting the customer list
/// got an empty page and this screen). Seeing it rendered is a reminder that
/// the empty state is indistinguishable from the bug — the copy is reassuring
/// and it is the same copy either way.
///
/// The subtitle is per-tab (`orderHistoryEmptyActive` here), so this is also
/// where a copy drift between the three tabs' subtitles would show up.
@JeebPreview(group: 'shell', name: 'Empty · no orders yet', size: _emptyBox)
Widget ordersTabEmpty() =>
    _hosted(const _SeededOrderRepository(<OrderSummary>[]));

/// Cold load failed with no connection.
///
/// **This preview found a live bug — look at the EN 200% rendering.** The empty
/// state above is wrapped in `OmdsPullToRefresh → ListView`, so it scrolls and
/// can be pulled to retry. The error state next to it in
/// `order_history_screen.dart` is returned BARE into the `TabBarView`: an
/// `OmdsErrorState` whose `Column` (64 pt icon → title → message → retry
/// button, `mainAxisSize.min`) has no scroll and no pull-to-refresh. When the
/// column outgrows the tab's list area it is a hard bottom `RenderFlex`
/// overflow, and the "Try again" button — the ONLY recovery affordance on the
/// state, since the pull gesture is absent here — is clipped away with it.
///
/// Measured in this box (390 × 560, roughly the Delivery-tab list area on a
/// phone): fits at 1.0×; at 1.6× the button's bottom sits 27 pt past the
/// viewport; at 2.0× the whole button starts 134 pt BELOW it and cannot be
/// reached at all. It also overflows at plain 1.0× once the list area is under
/// ~460 pt tall, i.e. on SE-class devices. Wrapping this branch the way the
/// empty branch is already wrapped would fix all of it.
///
/// The server branch (`orderHistoryErrorServer`, "Something went wrong on our
/// end.") pairs the SAME title with different body copy; it is not a separate
/// preview because the layout is identical — only the sentence changes.
@JeebPreview(group: 'shell', name: 'Error · offline, retry', size: _errorBox)
Widget ordersTabErrorNetwork() =>
    _hosted(const _FailingOrderRepository(OrderRepositoryErrorKind.network));

/// The first page is still in flight — an indeterminate spinner, centred.
///
/// Held open by a future that never completes, so it is the one preview here
/// that cannot be pumped to settlement; its render test drives fixed frames
/// instead. What to check in the canvas: the spinner is centred in the tab
/// BELOW the filter chip and tab bar (those stay up — only the list area
/// swaps), and it survives the AR RTL dark rendering, where an indicator tinted
/// `colorScheme.primary` on a dark surface is easy to lose.
@JeebPreview(group: 'shell', name: 'Loading · first page', size: _loadingBox)
Widget ordersTabLoading() =>
    _hosted(const _NeverResolvingOrderRepository());

/// Layout ceiling: the longest plausible addresses a Beirut request produces.
///
/// Three squeezes meet on one card and each fails differently:
///
/// * the header `Row` — a `dateLabel` in an `Expanded` beside an
///   [OrderStatusChip] that is NOT flexible, so at 200% text the date must
///   ellipsize rather than push the chip off the trailing edge. The date is
///   `DateFormat.yMMMd().add_jm()`, which is *longer in Arabic*, so the AR
///   rendering squeezes harder than the EN one;
/// * both `_AddressLine`s — `maxLines: 2` with ellipsis, which means a real
///   third line of address is silently lost rather than wrapped;
/// * the footer `Row` — tier label in an `Expanded` beside the amount, with
///   `onTheWay` ("On the way") as the longest of the five tier labels.
@JeebPreview(group: 'shell', name: 'Long addresses · layout ceiling', size: _listBox)
Widget ordersTabLongAddresses() => _hosted(
      _SeededOrderRepository(<OrderSummary>[
        _row(
          id: 'order-long-001',
          pickupAddress:
              'Pharmacie Al-Muhandis, Rue Abdel Aziz, Bloc B, 3rd floor, '
              'Hamra, Beirut, Lebanon',
          dropoffAddress:
              'Immeuble Trabulsi, Rue Sursock, near the Greek Orthodox '
              'church, Achrafieh, Beirut, Lebanon',
          status: OrderRequestStatus.pickedUp,
          tier: OrderTier.onTheWay,
          amountMinor: 1234567,
        ),
      ]),
    );

/// T11 / SW-02 regression guard, made visible: a missing price is UNKNOWN.
///
/// The requests-list endpoint drops the amount for some rows, and every history
/// row once read `$0.00` because a missing key was treated as a zero — even the
/// completed $12 order. A null `amountMinor` must render the muted em-dash with
/// an "Amount unavailable" semantics label, never a fabricated zero. If this
/// preview ever shows a currency amount, `hasKnownAmount` has broken.
///
/// The row also carries an UNRECOGNISED wire status, which is the second half
/// of the same defensive contract: [OrderRequestStatus.unknown] buckets into
/// Active and renders "In progress" rather than crashing or vanishing, so a
/// state added on the gateway stays visible to the user and to QA.
@JeebPreview(group: 'shell', name: 'Unknown amount + unknown status', size: _listBox)
Widget ordersTabUnknownAmount() => _hosted(
      _SeededOrderRepository(<OrderSummary>[
        _row(
          id: 'order-unpriced-001',
          pickupAddress: 'Bourj Hammoud',
          dropoffAddress: 'Dekwaneh',
          status: OrderRequestStatus.unknown,
          tier: OrderTier.standard,
          amountMinor: null,
        ),
      ]),
    );
