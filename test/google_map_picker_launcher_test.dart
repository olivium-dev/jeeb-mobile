import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/data/google_map_picker_launcher.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';

import 'support/sync_app_localizations.dart';

void main() {
  // T-MOB-012: the production MapPickerLauncher pushes the capture screen and
  // returns the coordinate parked under the centre pin. The GoogleMap is a
  // platform view that does not paint headless, but the route push + the
  // pin-returns-the-centre contract are exercised here; the gateway is omitted
  // so no real GPS/plugin call happens in `flutter test`.
  testWidgets('pickOnMap pushes the capture screen and pins return the centre',
      (tester) async {
    LocationPoint? result;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    final launcher = GoogleMapPickerLauncher(capturedContext);
    final future = launcher.pickOnMap(
      initial: const LocationPoint(latitude: 33.70, longitude: 35.40),
    );
    await tester.pump(); // start the push
    await tester.pump(const Duration(milliseconds: 350)); // route transition

    // The "Pin Location" CTA is on the pushed capture screen.
    final cta = find.text('Pin Location');
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    result = await future;
    // No camera moved (no platform view paint) → the centre is the initial.
    expect(result, isNotNull);
    expect(result!.latitude, closeTo(33.70, 1e-6));
    expect(result.longitude, closeTo(35.40, 1e-6));
  });

  testWidgets('pickOnMap defaults to Beirut downtown when no initial given',
      (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    final future = GoogleMapPickerLauncher(capturedContext).pickOnMap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final cta = find.text('Pin Location');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    final result = await future;
    expect(result, isNotNull);
    expect(result!.latitude, closeTo(33.8938, 1e-6));
    expect(result.longitude, closeTo(35.5018, 1e-6));
  });
}
