// Isolated native UI test — capture-location (CaptureLocationScreen). The
// screen's map is injected via `mapBuilder`; when null it renders the neutral
// CaptureMapViewport placeholder (no GoogleMap / no Maps key needed), with the
// fixed centre pin overlay and the "Pin Location" CTA. We pump it with the
// default (placeholder) map and screenshot the chrome.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture-location: map picker chrome (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const CaptureLocationScreen(),
      'capture-location__map',
    );
  });

  testWidgets('capture-location: map picker chrome (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const CaptureLocationScreen(),
      'capture-location__map-ar',
      locale: const Locale('ar'),
    );
  });
}
