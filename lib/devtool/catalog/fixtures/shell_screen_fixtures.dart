// Shared dev-only fixtures for `ShellScreen` — the bottom-nav host every

import 'dart:async';

import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/domain/client_home_request.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';

/// Canned [OrderRepository] — every read resolves to the page canned for that
/// tab, and to an empty page for a tab with nothing canned.
/// Filtering by [OrderHistoryTab] the way the gateway's `status` filter does is
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
/// A [Completer] that is never completed holds no timer and no subscription; it
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
/// Deliberately NOT a widget builder: the catalog wraps the screen in its own
/// chrome and the preview host wraps it in another, so a shared builder taking
class ShellScreenPreviewFixtures {
  const ShellScreenPreviewFixtures._();

  /// The three order pages the catalog has shown since DT-04: one active
  /// delivery en route, one delivered, and nothing cancelled — enough for each
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
  /// A request with no `displayId` falls back to the customer's own typed
  static const String longestRequestTitle =
      'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
      'drop everything at the clinic on Independence Street before it closes';

  /// The same items line every other Jeeb fixture uses, so the rows in the
  /// canvas match the rows in `DevClientHomeFixtures`.
  static const String itemsSummary =
      '1 kilo potato, water gallon, coffee blend';

  /// Nothing pending, one request with offers waiting.
  /// `ClientHomeScreen._resolveInitialTab` reads this shape and moves the
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
        offerAvatarUrls: <String>['', '', ''],
        conversationId: 'conv-rep-longest',
      ),
    ],
  );
}
