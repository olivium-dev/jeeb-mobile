import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_location_pin.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_map_viewport.dart';

import 'support/sync_app_localizations.dart';

void main() {
  // T-MOB-012: the route injects a live GoogleMap via `mapBuilder`. These
  testWidgets('renders the injected map builder instead of the placeholder',
      (tester) async {
    const injected = Key('injected-map-sentinel');
    await tester.pumpWidget(
      wrapForTest(
        CaptureLocationScreen(
          mapBuilder: (_) => const ColoredBox(
            key: injected,
            color: Color(0xFF00FF00),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(injected), findsOneWidget);
    // The placeholder must NOT be rendered when a builder is injected.
    expect(find.byType(CaptureMapViewport), findsNothing);
    // The fixed centre pin overlay is always present.
    expect(find.byType(CaptureLocationPin), findsOneWidget);
  });

  testWidgets('falls back to the placeholder when no map builder is injected',
      (tester) async {
    await tester.pumpWidget(wrapForTest(const CaptureLocationScreen()));
    await tester.pump();

    expect(find.byType(CaptureMapViewport), findsOneWidget);
    expect(find.byType(CaptureLocationPin), findsOneWidget);
  });

  testWidgets('Pin Location CTA fires onPinned (the route returns the centre)',
      (tester) async {
    var pinned = 0;
    await tester.pumpWidget(
      wrapForTest(
        CaptureLocationScreen(
          mapBuilder: (_) => const SizedBox.expand(),
          onPinned: () => pinned++,
        ),
      ),
    );
    await tester.pump();

    final cta = find.text('Pin Location');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();

    expect(pinned, 1);
  });
}
