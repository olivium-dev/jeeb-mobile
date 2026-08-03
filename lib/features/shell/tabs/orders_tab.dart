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
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key, this.repository});

  final OrderRepository? repository;

  @override
  Widget build(BuildContext context) {
    final actingAsJeeber = _actingAsJeeber(context);
    return BlocProvider<OrderHistoryCubit>(
      key: ValueKey('orders-tab-${actingAsJeeber ? 'jeeber' : 'client'}'),
      create: (_) =>
          OrderHistoryCubit(repository: _resolveRepository(actingAsJeeber)),
      child: const OrdersResumeRefetcher(child: OrderHistoryScreen()),
    );
  }

  bool _actingAsJeeber(BuildContext context) {
    return context.watch<RoleCubit?>()?.state == UserRole.jeeber;
  }

  OrderRepository _resolveRepository(bool actingAsJeeber) {
    if (repository != null) return repository!;
    if (!actingAsJeeber && sl.isRegistered<OrderRepository>()) {
      return sl<OrderRepository>();
    }
    final dio = sl.isRegistered<Dio>() ? sl<Dio>() : Dio();
    return DioOrderRepository(dio, asJeeber: actingAsJeeber);
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, matching the shell body the tab is a child of in production.
const double _ordersTabPhoneWidth = 390;

/// A list box tall enough to show the filter chip, the three-tab bar and two
/// full cards without the ListView taking over — which is the point, since the
const Size _ordersTabListBox = Size(_ordersTabPhoneWidth, 700);

/// The placeholder states are a single centred block; they need height for the
/// EN 200%-text rendering of the matrix to grow into, not for more rows.
const Size _ordersTabEmptyBox = Size(_ordersTabPhoneWidth, 620);
const Size _ordersTabErrorBox = Size(_ordersTabPhoneWidth, 560);
const Size _ordersTabLoadingBox = Size(_ordersTabPhoneWidth, 400);

/// Canned snapshot, resolved on the next microtask like a real (fast) load.
/// Filters by [OrderHistoryTab] the way the gateway's `status` filter does, so
/// tapping Completed/Cancelled in the canvas shows that tab's real content
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
/// It MUST throw [OrderRepositoryException] and nothing else: that is the only
/// type `OrderHistoryCubit` catches, so any other error escapes the cubit and
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
/// Two rows rather than one because a single card cannot show the *rhythm* of
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
/// Worth a preview of its own because "No orders yet" is the exact string a
@JeebPreview(
  group: 'shell',
  name: 'Empty · no orders yet',
  size: _ordersTabEmptyBox,
)
Widget ordersTabEmpty() =>
    _ordersTabHosted(const _OrdersTabSeededRepository(<OrderSummary>[]));

/// Cold load failed with no connection.
/// **This preview found a live bug — look at the EN 200% rendering.** The empty
@JeebPreview(
  group: 'shell',
  name: 'Error · offline, retry',
  size: _ordersTabErrorBox,
)
Widget ordersTabErrorNetwork() => _ordersTabHosted(
      const _OrdersTabFailingRepository(OrderRepositoryErrorKind.network),
    );

/// The first page is still in flight — an indeterminate spinner, centred.
/// Held open by a future that never completes, so it is the one preview here
@JeebPreview(
  group: 'shell',
  name: 'Loading · first page',
  size: _ordersTabLoadingBox,
)
Widget ordersTabLoading() =>
    _ordersTabHosted(const _OrdersTabNeverResolvingRepository());

/// Layout ceiling: the longest plausible addresses a Beirut request produces.
/// Three squeezes meet on one card and each fails differently:
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
/// The requests-list endpoint drops the amount for some rows, and every history
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
