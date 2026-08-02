import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../order_history/application/order_history_cubit.dart';
import '../../order_history/data/dio_order_repository.dart';
import '../../order_history/domain/order_repository.dart';
import '../../order_history/presentation/order_history_screen.dart';
import '../../order_history/presentation/orders_resume_refetcher.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../core/previews/jeeb_preview.dart';
import '../../order_history/domain/order_summary.dart';

/// Container for the bottom-nav Delivery tab. Wires the cubit + Dio-backed
/// repository so the screen itself can stay BlocProvider-free in tests.
///
/// ROLE-AWARE (JEBV4-280): the Delivery tab is SHARED by clients and jeebers in
/// the additive shell. For a pure customer it lists their own orders
/// (`GET /v1/requests`); for a jeeber it must list their assigned delivery JOBS
/// (`GET /v1/deliveries?role=jeeber`) — hitting the customer list as a jeeber
/// returned an empty page and stranded the tab on "No orders yet". The tab
/// resolves a customer- or jeeber-scoped [DioOrderRepository] from the active
/// role, key-gated so a late login→role sync rebuilds the cubit against the
/// right endpoint. A pure customer triggers neither jeeber signal, so their
/// Delivery view is completely unchanged.
///
/// The repository is fetched from the global GetIt container if one was
/// registered (so DI bootstrap can swap in a fake during integration tests),
/// and otherwise a one-shot Dio is used.
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key, this.repository});

  /// Optional override — primarily a hook for widget tests / the DT-04 catalog.
  /// When supplied it wins over the role-aware resolution below (the catalog
  /// seeds a fixed customer-shaped repo), so the shared screen renders without a
  /// live gateway.
  final OrderRepository? repository;

  @override
  Widget build(BuildContext context) {
    final actingAsJeeber = _actingAsJeeber(context);
    return BlocProvider<OrderHistoryCubit>(
      // Role-keyed so a client→jeeber role resolution (e.g. getMe active_role or
      // the capability sync landing after first build) tears down the customer
      // cubit and rebuilds it against `/v1/deliveries?role=jeeber`. A customer's
      // key never flips, so their cubit + list state are preserved untouched.
      key: ValueKey('orders-tab-${actingAsJeeber ? 'jeeber' : 'client'}'),
      create: (_) =>
          OrderHistoryCubit(repository: _resolveRepository(actingAsJeeber)),
      // The list used to be read exactly ONCE per process. The shell keeps this
      // tab mounted inside its `IndexedStack`, so `OrderHistoryScreen.initState`
      // never ran twice and nothing else re-read: the status chip held its
      // first-seen value — "Pending" through Picked and InTransit on the live
      // COD run. `OrdersResumeRefetcher` supplies the missing consumers for
      // signals the shell and the push bus were already broadcasting.
      child: const OrdersResumeRefetcher(child: OrderHistoryScreen()),
    );
  }

  /// True when the signed-in user is ACTIVELY acting as a jeeber — the single
  /// axis the Delivery-tab scope keys on (F6 / JEBV4-303 role-bleed fix).
  ///
  /// Source of truth is the active [UserRole] ([RoleCubit]) — persisted and
  /// known SYNCHRONOUSLY at first build for a returning jeeber, and set from the
  /// gateway `active_role` by [RoleSync] on login/resume. Only an active jeeber
  /// loads the jeeber JOB feed (`/v1/deliveries?role=jeeber`); a client — a pure
  /// customer OR a DUAL-ROLE user acting as client — loads only their own
  /// requests (`/v1/requests`, role=client scope).
  ///
  /// Deliberately does NOT fall back to the `jeeber` CAPABILITY
  /// (`RoleAvailabilityCubit` / `available_roles`): a dual-role account browsing
  /// as a customer HOLDS the jeeber capability, and OR-ing it in leaked the
  /// jeeber job feed onto the customer's Delivery tab (the A33 role-bleed). The
  /// Dashboard/Earnings jeeber tabs keep their capability-based visibility
  /// (documented product decision); only the Delivery-tab list is active-role
  /// scoped. A returning jeeber's role is persisted so there is no client-list
  /// flash; a fresh jeeber login re-keys the cubit once `active_role` resolves.
  /// Nullable read keeps bare widget tests (no RoleCubit) on the customer path.
  bool _actingAsJeeber(BuildContext context) {
    return context.watch<RoleCubit?>()?.state == UserRole.jeeber;
  }

  OrderRepository _resolveRepository(bool actingAsJeeber) {
    if (repository != null) return repository!;
    // Customer: the DI-registered repository when present (integration-test
    // seam), else a bare Dio one — unchanged from before. Jeeber: always the
    // delivery-scoped Dio repository (there is no jeeber OrderRepository in DI,
    // and the DI one is customer-scoped to `/v1/requests`).
    if (!actingAsJeeber && sl.isRegistered<OrderRepository>()) {
      return sl<OrderRepository>();
    }
    final dio = sl.isRegistered<Dio>() ? sl<Dio>() : Dio();
    return DioOrderRepository(dio, asJeeber: actingAsJeeber);
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/shell/orders_tab_preview_test.dart
// ===========================================================================
//
// [OrdersTab] draws nothing itself: it is the shell's container for the
// Delivery tab, wiring an [OrderHistoryCubit] over an [OrderRepository] and
// mounting `OrdersResumeRefetcher → OrderHistoryScreen` underneath. So every
// preview here is *state*, seeded through the one seam the tab already exposes
// for exactly this purpose — its `repository` parameter, which the tab
// documents as the widget-test / DT-04-catalog override and which wins over
// the role-aware Dio resolution below it. Nothing here touches DI, so
// `sl.isRegistered<OrderRepository>()` is never consulted and
// [DioOrderRepository] is never constructed.
//
// [OrderHistoryCubit] takes no `seed:`, so each state supplies a tiny local
// fake repository with canned data: one that resolves, one that never
// completes, one that throws. All three are network-free by construction, not
// merely by the guard in [jeebPreviewHost].
//
// Fixture values are lifted from
// `test/features/order_history/orders_stale_status_chip_test.dart` — the same
// `order-cod-001` / Hamra → Achrafieh / Express / $6.00 row that file scripts
// through the live-COD-run status progression — so the preview and the
// regression test describe the same screen.
//
// **Why there is no jeeber-scoped preview.** The tab's headline behaviour
// (JEBV4-280 / F6) is role-aware: an ACTIVE jeeber gets
// `/v1/deliveries?role=jeeber` instead of `/v1/requests`. That axis is not
// previewable from here and deliberately is not faked: the role is read from
// [RoleCubit], whose constructor requires a real `SharedPreferences` — a
// platform plugin the preview canvas has no binding for. It would also show
// nothing new, because `repository` (which every preview below must pass to
// stay off the network) short-circuits the role resolution entirely; the only
// role-dependent difference left is the *route* a tapped row pushes, which is
// invisible in a still frame. `orders_stale_status_chip_test.dart` and the
// role-bleed tests own that axis.
//
// **The box.** In production the shell hosts this tab inside an `IndexedStack`
// (`shell_screen.dart`) at full body size, so it lays out against phone width
// and BOUNDED height — `OrderHistoryScreen` is a `Column` ending in
// `Expanded(TabBarView)` and cannot survive an unbounded vertical axis. The
// canvas box supplies both, and [jeebPreviewHost]'s `Scaffold` + `SafeArea` is
// the same bounded parent the shell provides. Nothing is wrapped in a scroll
// view here for that reason — unlike the `InProgressTab` previews.

/// Phone width, matching the shell body the tab is a child of in production.
const double _ordersTabPhoneWidth = 390;

/// A list box tall enough to show the filter chip, the three-tab bar and two
/// full cards without the ListView taking over — which is the point, since the
/// thing that goes wrong between rows is the rhythm (divider, padding, the
/// status chips lining up down the trailing edge).
const Size _ordersTabListBox = Size(_ordersTabPhoneWidth, 700);

/// The placeholder states are a single centred block; they need height for the
/// EN 200%-text rendering of the matrix to grow into, not for more rows.
const Size _ordersTabEmptyBox = Size(_ordersTabPhoneWidth, 620);
const Size _ordersTabErrorBox = Size(_ordersTabPhoneWidth, 560);
const Size _ordersTabLoadingBox = Size(_ordersTabPhoneWidth, 400);

/// Canned snapshot, resolved on the next microtask like a real (fast) load.
///
/// Filters by [OrderHistoryTab] the way the gateway's `status` filter does, so
/// tapping Completed/Cancelled in the canvas shows that tab's real content
/// rather than the Active list repeated three times.
class _OrdersTabSeededRepository implements OrderRepository {
  const _OrdersTabSeededRepository(this.orders);

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
class _OrdersTabNeverResolvingRepository implements OrderRepository {
  const _OrdersTabNeverResolvingRepository();

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
class _OrdersTabFailingRepository implements OrderRepository {
  const _OrdersTabFailingRepository(this.kind);

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
Widget _ordersTabHosted(OrderRepository repository) =>
    OrdersTab(repository: repository);

/// One history row, shaped like `_order` in
/// `test/features/order_history/orders_stale_status_chip_test.dart`.
OrderSummary _ordersTabRow({
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
@JeebPreview(
  group: 'shell',
  name: 'Active · two live deliveries',
  size: _ordersTabListBox,
)
Widget ordersTabActiveRows() => _ordersTabHosted(
      _OrdersTabSeededRepository(<OrderSummary>[
        _ordersTabRow(
          id: 'order-cod-001',
          pickupAddress: 'Hamra',
          dropoffAddress: 'Achrafieh',
        ),
        _ordersTabRow(
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
@JeebPreview(
  group: 'shell',
  name: 'Empty · no orders yet',
  size: _ordersTabEmptyBox,
)
Widget ordersTabEmpty() =>
    _ordersTabHosted(const _OrdersTabSeededRepository(<OrderSummary>[]));

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
@JeebPreview(
  group: 'shell',
  name: 'Error · offline, retry',
  size: _ordersTabErrorBox,
)
Widget ordersTabErrorNetwork() => _ordersTabHosted(
      const _OrdersTabFailingRepository(OrderRepositoryErrorKind.network),
    );

/// The first page is still in flight — an indeterminate spinner, centred.
///
/// Held open by a future that never completes, so it is the one preview here
/// that cannot be pumped to settlement; its render test drives fixed frames
/// instead. What to check in the canvas: the spinner is centred in the tab
/// BELOW the filter chip and tab bar (those stay up — only the list area
/// swaps), and it survives the AR RTL dark rendering, where an indicator tinted
/// `colorScheme.primary` on a dark surface is easy to lose.
@JeebPreview(
  group: 'shell',
  name: 'Loading · first page',
  size: _ordersTabLoadingBox,
)
Widget ordersTabLoading() =>
    _ordersTabHosted(const _OrdersTabNeverResolvingRepository());

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
@JeebPreview(
  group: 'shell',
  name: 'Long addresses · layout ceiling',
  size: _ordersTabListBox,
)
Widget ordersTabLongAddresses() => _ordersTabHosted(
      _OrdersTabSeededRepository(<OrderSummary>[
        _ordersTabRow(
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
@JeebPreview(
  group: 'shell',
  name: 'Unknown amount + unknown status',
  size: _ordersTabListBox,
)
Widget ordersTabUnknownAmount() => _ordersTabHosted(
      _OrdersTabSeededRepository(<OrderSummary>[
        _ordersTabRow(
          id: 'order-unpriced-001',
          pickupAddress: 'Bourj Hammoud',
          dropoffAddress: 'Dekwaneh',
          status: OrderRequestStatus.unknown,
          tier: OrderTier.standard,
          amountMinor: null,
        ),
      ]),
    );
