// Shared dev-only fixtures for `ShellScreen` — the bottom-nav host every
// signed-in user lands on.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entries
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`, which mocks both
//     `ShellScreen` itself and its `OrdersTab` body off the same pages), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/shell/shell_screen.dart`.
//
// The catalog owned three private fakes (`_StaticOrderRepository`,
// `_EmptyOrderRepository`, `_FailingOrderRepository`) plus an inline
// three-tab order page map. Copying those into the preview section would have
// given the two surfaces two different `req-9001` — free to drift the first
// time either was edited — so both now import this file.
//
// `ShellScreen` takes exactly two seams, `homeRepository` and
// `ordersRepository`, and everything below feeds one of them. The client-home
// side reuses the fakes that already exist in
// `client_home_screen_fixtures.dart` (`SeededClientHomeRepository`,
// `FailingClientHomeRepository`, `StalledClientHomeRepository`) rather than
// declaring a fourth copy; only the ORDER side and the shell's own designed
// snapshots are new here.
//
// **Network-free by construction.** Every repository below answers from a const
// list, throws, or never completes. Neither `DioOrderRepository` nor
// `DioClientHomeRepository` is ever constructed, and no fixture touches GetIt —
// the `CatalogNetworkGuard` both hosts install is the net, not the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/domain/client_home_request.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';

/// Canned [OrderRepository] — every read resolves to the page canned for that
/// tab, and to an empty page for a tab with nothing canned.
///
/// Filtering by [OrderHistoryTab] the way the gateway's `status` filter does is
/// what makes the Delivery tab's three chips show three different lists in the
/// catalog instead of the active list repeated three times.
class ShellScreenStaticOrderRepository implements OrderRepository {
  const ShellScreenStaticOrderRepository(this._pages);

  final Map<OrderHistoryTab, OrderPage> _pages;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    return _pages[tab] ?? const OrderPage(items: [], page: 1, hasMore: false);
  }
}

/// A signed-in account that has never ordered: every tab resolves empty.
class ShellScreenEmptyOrderRepository implements OrderRepository {
  const ShellScreenEmptyOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async => const OrderPage(items: [], page: 1, hasMore: false);
}

/// Fails every read with the repository's OWN exception type, which is how the
/// live repository fails — not a null and not an empty page.
class ShellScreenFailingOrderRepository implements OrderRepository {
  const ShellScreenFailingOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    throw const OrderRepositoryException(OrderRepositoryErrorKind.network);
  }
}

/// A read that never lands, holding the Delivery tab on its cold-load skeleton
/// for as long as the surface is open.
///
/// A [Completer] that is never completed holds no timer and no subscription; it
/// simply never settles.
class ShellScreenStalledOrderRepository implements OrderRepository {
  const ShellScreenStalledOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) => Completer<OrderPage>().future;
}

/// The designed states of `ShellScreen`, as repositories and snapshots.
///
/// Deliberately NOT a widget builder: the catalog wraps the screen in its own
/// chrome and the preview host wraps it in another, so a shared builder taking
/// a `wrapIn…` flag would just be two builders wearing one name. Both consumers
/// visibly construct the real `ShellScreen` in their own source, which is also
/// what `tool/preview_inventory.dart` credits as coverage.
class ShellScreenPreviewFixtures {
  const ShellScreenPreviewFixtures._();

  /// The three order pages the catalog has shown since DT-04: one active
  /// delivery en route, one delivered, and nothing cancelled — enough for each
  /// of the Delivery tab's three chips to render a different list.
  static Map<OrderHistoryTab, OrderPage> orderPages() =>
      <OrderHistoryTab, OrderPage>{
        OrderHistoryTab.active: OrderPage(
          items: <OrderSummary>[
            OrderSummary(
              id: 'req-9001',
              createdAt: DateTime.utc(2026, 7, 1, 9, 30),
              pickupAddress: 'Hamra, Beirut',
              dropoffAddress: 'Achrafieh, Beirut',
              status: OrderRequestStatus.enRoute,
              tier: OrderTier.flash,
              amountMinor: 1500,
              currency: 'USD',
            ),
          ],
          page: 1,
          hasMore: false,
        ),
        OrderHistoryTab.completed: OrderPage(
          items: <OrderSummary>[
            OrderSummary(
              id: 'req-8890',
              createdAt: DateTime.utc(2026, 6, 20, 14, 0),
              pickupAddress: 'Verdun, Beirut',
              dropoffAddress: 'Mar Mikhael, Beirut',
              status: OrderRequestStatus.delivered,
              tier: OrderTier.standard,
              amountMinor: 900,
              currency: 'USD',
            ),
          ],
          page: 1,
          hasMore: false,
        ),
        OrderHistoryTab.cancelled: const OrderPage(
          items: <OrderSummary>[],
          page: 1,
          hasMore: false,
        ),
      };

  /// The populated client landing: `DevClientHomeFixtures` (three in-progress
  /// deliveries, three pending requests, the replies rows) behind the real
  /// in-memory repository, at its real 150 ms latency.
  static ClientHomeRepository populatedHome() =>
      InMemoryClientHomeRepository.fromSnapshot(
        DevClientHomeFixtures.snapshot(),
      );

  /// A signed-in account with nothing on any tab — the shape a brand-new user
  /// sees, and the one where the shell is ALL there is to look at.
  static ClientHomeRepository emptyHome() => InMemoryClientHomeRepository();

  /// The populated Delivery tab, over [orderPages].
  static OrderRepository populatedOrders() =>
      ShellScreenStaticOrderRepository(orderPages());

  /// The longest free-text a pending request can carry into the shell.
  ///
  /// A request with no `displayId` falls back to the customer's own typed
  /// description, which the gateway does not bound. Duplicated verbatim in
  /// `test/previews/shell/shell_screen_preview_test.dart` so a fixture quietly
  /// rewired to a short title fails instead of silently losing the one state
  /// that puts the landing tab under width pressure.
  static const String longestRequestTitle =
      'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
      'drop everything at the clinic on Independence Street before it closes';

  /// The same items line every other Jeeb fixture uses, so the rows in the
  /// canvas match the rows in `DevClientHomeFixtures`.
  static const String itemsSummary =
      '1 kilo potato, water gallon, coffee blend';

  /// Nothing pending, one request with offers waiting.
  ///
  /// `ClientHomeScreen._resolveInitialTab` reads this shape and moves the
  /// landing chip from Pending to Replies on the frame after the load — the
  /// "land where the content is" affordance — so a shell preview built on it
  /// opens on a DIFFERENT sub-tab from every other one, without anything
  /// tapping.
  static ClientHomeSnapshot repliesOnlySnapshot() => const ClientHomeSnapshot(
    replies: <ClientHomeRequest>[
      ClientHomeRequest(
        id: 'rep-compact',
        displayId: 'ORD-23495',
        title: 'ORD-23495',
        status: ClientRequestStatus.offersReceived,
        destinationLabel: itemsSummary,
        itemsSummary: itemsSummary,
        tier: ClientRequestTier.express,
        offerCount: 3,
        offerAvatarUrls: <String>['', '', ''],
        conversationId: 'conv-rep-compact',
      ),
    ],
  );

  /// A landing tab carrying the longest content the shell can be handed: an
  /// unbounded free-text title on a request that is out for bids, plus a
  /// replies row with a two-digit offer count.
  static ClientHomeSnapshot longestContentSnapshot() => const ClientHomeSnapshot(
    pending: <ClientHomeRequest>[
      ClientHomeRequest(
        id: 'pen-longest',
        title: longestRequestTitle,
        status: ClientRequestStatus.searching,
        destinationLabel: itemsSummary,
        itemsSummary: itemsSummary,
        tier: ClientRequestTier.express,
      ),
    ],
    replies: <ClientHomeRequest>[
      ClientHomeRequest(
        id: 'rep-longest',
        displayId: 'ORD-23480',
        title: 'ORD-23480',
        status: ClientRequestStatus.offersReceived,
        destinationLabel: itemsSummary,
        itemsSummary: itemsSummary,
        tier: ClientRequestTier.express,
        offerCount: 12,
        // Empty on purpose: `OmdsProfileAvatar` renders a URL through
        // `CachedNetworkImage`, and a real one would have the canvas reach for
        // a CDN it cannot see. An empty string falls back to the initials
        // placeholder — same geometry, no request.
        offerAvatarUrls: <String>['', '', ''],
        conversationId: 'conv-rep-longest',
      ),
    ],
  );
}
