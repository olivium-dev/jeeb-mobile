// Isolated native UI test — DeliveryDetailScreen (delivery-detail, /orders/:id).
// The screen wraps its body in a RootAwareBackScope → BackButtonListener, which
// asserts a parent Router exists, so it must be pumped inside a GoRouter (via
// pumpRouterAndShoot) rather than the plain-MaterialApp harness. It reads the
// app-global RoleCubit defensively (falls back to the client Contact label when
// absent) and takes only a `deliveryId`; every action row navigates on tap, so
// no cubit/DI is needed for the static action-hub render. Covers en + Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';

import '../support/screen_harness.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/orders/DLV-1',
      routes: [
        GoRoute(
          path: '/orders/:id',
          builder: (_, state) =>
              DeliveryDetailScreen(deliveryId: state.pathParameters['id']!),
        ),
      ],
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delivery-detail: action hub (en)', (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(),
      'delivery-detail__hub',
    );
  });

  testWidgets('delivery-detail: action hub (ar)', (tester) async {
    await pumpRouterAndShoot(
      tester,
      binding,
      _router(),
      'delivery-detail__ar',
      locale: const Locale('ar'),
    );
  });
}
