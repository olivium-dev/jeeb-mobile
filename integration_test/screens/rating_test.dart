// Isolated native UI test — RatingScreen (legacy /feedback rating terminal).
// The screen owns its Scaffold + PopScope; the RatingRepository seam is only
// touched on submit, never at build, so no repository/DI is needed to render.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rating: customer rates jeeber (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RatingScreen(
        deliveryId: 'del-client-001',
        isClient: true,
        rateeName: 'Karim',
      ),
      'rating__customer',
    );
  });

  testWidgets('rating: jeeber rates customer (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RatingScreen(
        deliveryId: 'del-jeeber-001',
        isClient: false,
        rateeName: 'Sami',
      ),
      'rating__jeeber',
    );
  });

  testWidgets('rating: customer rates jeeber (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RatingScreen(
        deliveryId: 'del-client-001',
        isClient: true,
        rateeName: 'Karim',
      ),
      'rating__ar',
      locale: const Locale('ar'),
    );
  });
}
