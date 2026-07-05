// Isolated native UI test — OrderHistoryScreen (Delivery / Orders tab). Pumps
// the screen over a fake OrderRepository + OrderHistoryCubit and screenshots
// the populated Active list and the per-tab empty state.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';

import '../support/screen_harness.dart';

/// Fake mirroring test/order_history_screen_test.dart's _FakeRepo: serves the
/// scripted page for the first call per tab, then an empty terminal page.
class _FakeRepo implements OrderRepository {
  _FakeRepo(this._pages);

  final Map<OrderHistoryTab, List<OrderPage>> _pages;
  final Map<OrderHistoryTab, int> _calls = {};

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final call = _calls.update(tab, (v) => v + 1, ifAbsent: () => 0);
    final list = _pages[tab] ?? const [];
    if (call >= list.length) {
      return OrderPage(items: const [], page: page, hasMore: false);
    }
    return list[call];
  }
}

OrderSummary _o(String id, OrderRequestStatus status) => OrderSummary(
      id: id,
      createdAt: DateTime.utc(2026, 5, 17, 10),
      pickupAddress: 'Pickup $id',
      dropoffAddress: 'Dropoff $id',
      status: status,
      tier: OrderTier.express,
      amountMinor: 1234_00,
      currency: 'USD',
    );

/// Wrap in a Scaffold (the screen returns a Column and hosts a Material TabBar)
/// with the cubit provided.
Widget _orderHistory(OrderRepository repo) {
  final cubit = OrderHistoryCubit(repository: repo, pageSize: 2);
  return Scaffold(
    body: BlocProvider.value(
      value: cubit,
      child: const OrderHistoryScreen(),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('order-history: populated Active list (en)', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [
        OrderPage(
          items: [
            _o('a1', OrderRequestStatus.enRoute),
            _o('a2', OrderRequestStatus.pickedUp),
          ],
          page: 1,
          hasMore: false,
        ),
      ],
    });
    await pumpAndShoot(
      tester,
      binding,
      _orderHistory(repo),
      'order-history__populated',
    );
  });

  testWidgets('order-history: empty Active tab (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _orderHistory(_FakeRepo(const {})),
      'order-history__empty',
    );
  });

  testWidgets('order-history: populated Active list (ar)', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [
        OrderPage(
          items: [_o('a1', OrderRequestStatus.enRoute)],
          page: 1,
          hasMore: false,
        ),
      ],
    });
    await pumpAndShoot(
      tester,
      binding,
      _orderHistory(repo),
      'order-history__ar',
      locale: const Locale('ar'),
    );
  });
}
