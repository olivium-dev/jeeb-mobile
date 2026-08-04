import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/data/google_map_picker_launcher.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';

import 'support/sync_app_localizations.dart';

void main() {
  // T-MOB-012: the production MapPickerLauncher pushes the capture screen and
  testWidgets('pickOnMap pushes the capture screen seeded at the given initial',
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

    final launcher = GoogleMapPickerLauncher(capturedContext);
    final future = launcher.pickOnMap(
      initial: const LocationPoint(latitude: 33.70, longitude: 35.40),
    );
    await tester.pump(); // start the push
    await tester.pump(const Duration(milliseconds: 350)); // route transition

    // The "Confirm drop-off" CTA is on the pushed capture screen.
    final cta = find.text('Confirm drop-off');
    expect(cta, findsOneWidget);
    // The seed reaches the sheet's pinned-point card, so what the customer
    // reads is the coordinate the launcher handed the map.
    expect(find.text('33.7000, 35.4000'), findsOneWidget);

    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // JEBV4-176: no platform view painted here, so no camera ever settled. The
    // launcher must NOT hand the seed back as if the customer had chosen it.
    expect(await future, isNull);
  });

  testWidgets('pickOnMap seeds Beirut downtown when no initial given',
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

    expect(find.text('Confirm drop-off'), findsOneWidget);
    expect(find.text('33.8938, 35.5018'), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm drop-off'));
    await tester.tap(find.text('Confirm drop-off'));
    await tester.pumpAndSettle();

    expect(await future, isNull);
  });

  // The screen's own default (no `onPinned`) used to pop with NO value, so any
  // caller awaiting the route got null even when a point was pinned.
  testWidgets('confirming with no onPinned pops the pinned point', (
    tester,
  ) async {
    final controller = MapCaptureController(
      initial: const LocationPoint(latitude: 12.25, longitude: -3.5),
    );
    addTearDown(controller.dispose);
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

    final future = Navigator.of(capturedContext).push<LocationPoint>(
      MaterialPageRoute<LocationPoint>(
        builder: (_) => CaptureLocationScreen(
          controller: controller,
          mapBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
    await tester.pumpAndSettle();

    final result = await future;
    expect(result, isNotNull);
    expect(result!.latitude, closeTo(12.25, 1e-6));
    expect(result.longitude, closeTo(-3.5, 1e-6));
  });

  testWidgets('confirming with no controller pops without a coordinate', (
    tester,
  ) async {
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

    final future = Navigator.of(capturedContext).push<LocationPoint>(
      MaterialPageRoute<LocationPoint>(
        builder: (_) => const CaptureLocationScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
    await tester.pumpAndSettle();

    expect(await future, isNull);
  });
}
