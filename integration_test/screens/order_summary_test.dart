// Isolated native UI test — OrderSummaryScreen (order-summary, JM-031). The
// screen owns its BlocProvider and resolves an OrderSummaryRepository seam;
// injecting a scripted fake avoids DI/network. OrderSummaryCubit has no timers,
// so no cubitFactory override is needed. jeeberAvatarUrl is left null so the
// pinned header renders initials (no on-device image fetch).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/order_summary/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/order_summary_screen.dart';

import '../support/screen_harness.dart';

class _FakeOrderSummaryRepo implements OrderSummaryRepository {
  const _FakeOrderSummaryRepo(this._summary);
  final OrderSummary _summary;
  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async => _summary;
}

OrderSummaryScreen _summary(OrderSummary s) => OrderSummaryScreen(
      deliveryId: s.deliveryId,
      repository: _FakeOrderSummaryRepo(s),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('order-summary: rated jeeber (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _summary(const OrderSummary(
        deliveryId: 'del-client-001',
        requestId: 'req-client-001',
        conversationId: 'conv-001',
        price: 45.0,
        currency: 'USD',
        jeeberName: 'Karim',
        tier: 'express',
        jeeberRating: 4.8,
        jeeberRatingCount: 42,
        etaMinutes: 15,
        itemSummary: 'Pharmacy run — 2 items',
      )),
      'order-summary__rated',
    );
  });

  testWidgets('order-summary: cold-start jeeber, no rating chip (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _summary(const OrderSummary(
        deliveryId: 'del-client-002',
        requestId: 'req-client-002',
        conversationId: '',
        price: 18.0,
        currency: 'USD',
        jeeberName: 'Hadi',
        tier: 'standard',
        itemSummary: 'Grocery pickup',
      )),
      'order-summary__cold-start',
    );
  });

  testWidgets('order-summary: rated jeeber (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _summary(const OrderSummary(
        deliveryId: 'del-client-001',
        requestId: 'req-client-001',
        conversationId: 'conv-001',
        price: 45.0,
        currency: 'USD',
        jeeberName: 'Karim',
        tier: 'express',
        jeeberRating: 4.8,
        jeeberRatingCount: 42,
        etaMinutes: 15,
        itemSummary: 'Pharmacy run — 2 items',
      )),
      'order-summary__ar',
      locale: const Locale('ar'),
    );
  });
}
