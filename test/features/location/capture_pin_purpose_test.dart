import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/domain/capture_pin_purpose.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, CapturePinPurpose purpose) async {
    await tester.pumpWidget(
      wrapForTest(
        CaptureLocationScreen(
          purpose: purpose,
          mapBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the PICKUP leg never claims "Drop-off here"', (tester) async {
    await pumpScreen(tester, CapturePinPurpose.pickup);

    expect(find.text('Pickup here'), findsOneWidget);
    expect(find.text('Drop-off here'), findsNothing);
    expect(find.text('Confirm pickup'), findsOneWidget);
    expect(find.text('Confirm drop-off'), findsNothing);
  });

  testWidgets('a plain place pick reads neutrally', (tester) async {
    await pumpScreen(tester, CapturePinPurpose.place);

    expect(find.text('Set location here'), findsOneWidget);
    expect(find.text('Drop-off here'), findsNothing);
    expect(find.text('Confirm location'), findsOneWidget);
  });

  testWidgets('the drop-off leg is unchanged', (tester) async {
    await pumpScreen(tester, CapturePinPurpose.dropOff);

    expect(find.text('Drop-off here'), findsOneWidget);
    expect(find.text('Confirm drop-off'), findsOneWidget);
  });

  testWidgets('the sheet names the coordinate it is about to confirm',
      (tester) async {
    final controller = MapCaptureController(
      initial: const LocationPoint(latitude: 33.8938, longitude: 35.5018),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrapForTest(
        CaptureLocationScreen(
          purpose: CapturePinPurpose.pickup,
          controller: controller,
          mapBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Selected point'), findsOneWidget);
    expect(find.text('33.8938, 35.5018'), findsOneWidget);

    controller.updateCenter(
      const LocationPoint(latitude: 33.5, longitude: 35.25),
    );
    await tester.pump();

    expect(find.text('33.5000, 35.2500'), findsOneWidget);
  });

  test('the query param maps to a purpose, unknown values stay neutral', () {
    expect(CapturePinPurpose.parse('pickup'), CapturePinPurpose.pickup);
    expect(CapturePinPurpose.parse('drop-off'), CapturePinPurpose.dropOff);
    expect(CapturePinPurpose.parse('dropoff'), CapturePinPurpose.dropOff);
    expect(CapturePinPurpose.parse(null), CapturePinPurpose.place);
    expect(CapturePinPurpose.parse('nonsense'), CapturePinPurpose.place);
  });
}
