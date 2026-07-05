// Isolated native UI test — location-picker (LocationPickerScreen). This route
// is a placeholder "coming soon" empty-state page (no map, no cubit, no deps),
// so we pump it directly and screenshot the single state it renders.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/location/presentation/screens/location_picker_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('location-picker: placeholder (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const LocationPickerScreen(),
      'location-picker__placeholder',
    );
  });
}
