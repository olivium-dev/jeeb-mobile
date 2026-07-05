// Isolated native UI test — GoodsCostScreen (Jeeber declares the purchased-
// goods cost for a delivery). The screen self-provides its GoodsCostCubit
// (..loadCurrency()) and takes an optional `repository` seam; we inject the
// in-memory FakeGoodsCostRepository (the same DI-less fallback the screen uses,
// currency 'USD') so the currency label resolves deterministically without
// GetIt/Dio and no network timer spawns. Takes only `deliveryId`. Captures the
// cost-entry state en + ar.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/goods_cost/data/fake_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/presentation/goods_cost_screen.dart';

import '../support/screen_harness.dart';

Widget _screen() => GoodsCostScreen(
      deliveryId: 'DLV-1',
      repository: FakeGoodsCostRepository(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('goods-cost: cost entry (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'goods-cost__entry',
    );
  });

  testWidgets('goods-cost: cost entry (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'goods-cost__entry-ar',
      locale: const Locale('ar'),
    );
  });
}
