// Render tests for the CaptureLocationScreen previews.

// `Tristate` is a dart:ui type that `package:flutter/semantics.dart` does not
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/capture_location_screen_fixtures.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_location_pin.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_map_viewport.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/gps_denied_state.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Placeholder map (ships today)': captureLocationScreenPlaceholderMap,
  'Live map (production shape)': captureLocationScreenLiveMap,
  'Confirming (CTA disabled, nothing else is)': captureLocationScreenConfirming,
  'Permission denied (via the map seam)': captureLocationScreenPermissionDenied,
  'Outside service area (longest copy)': captureLocationScreenOutsideServiceArea,
  'Compact 320pt phone': captureLocationScreenCompactPhone,
};

/// The screen's confirm CTA, addressed by the Semantics id Maestro uses.
final Finder _cta = find.bySemanticsIdentifier('capture_location_pin_cta');

/// The label inside that CTA — a plain widget finder, so it can be tapped
/// without depending on the semantics tree.
final Finder _ctaLabel = find.text('Pin Location');

/// The pannable map stand-in that replaces the `google_maps_flutter` platform
/// view (which renders nothing headless).
final Finder _fakeMap = find.byType(CaptureLocationScreenFakeMap);

/// Drags the map by [delta] the way a user pans it under the fixed pin.
Future<void> _panMap(WidgetTester tester, Offset delta) async {
  await tester.drag(_fakeMap, delta);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CaptureLocationScreen',
    _previews,
    expectedText: const <String, String>{
      // The screen's own placeholder copy — the state that ships today.
      'Placeholder map (ships today)': 'Map preview',
      // The live-map stand-in's readout: the coordinate under the pin.
      'Live map (production shape)':
          CaptureLocationScreenPreviewFixtures.beirutReadout,
      // Identical product copy to the state above it, so the caption is what
      'Confirming (CTA disabled, nothing else is)':
          'Confirming · map and back still live',
      // Shipped ARB copy, reachable only through the map seam.
      'Permission denied (via the map seam)': 'Location access required',
      'Outside service area (longest copy)': 'Outside service area',
      'Compact 320pt phone': 'Compact 320 pt phone',
    },
  );

  group('CaptureLocationScreen · the state that ships today', () {
    testWidgets('offers a live CTA over a map that cannot pan', (
      WidgetTester tester,
    ) async {
      // `/capture-location` builds `CaptureLocationScreen` with no mapBuilder
      await pumpPreview(tester, captureLocationScreenPlaceholderMap);

      expect(find.byType(CaptureMapViewport), findsOneWidget);
      expect(_fakeMap, findsNothing);

      // And yet the primary CTA is fully enabled and fires.
      expect(find.text('pins confirmed 0'), findsOneWidget);
      await tester.tap(_ctaLabel);
      await tester.pumpAndSettle();

      expect(find.text('pins confirmed 1'), findsOneWidget);
    });
  });

  group('CaptureLocationScreen · isConfirming', () {
    testWidgets('disables the CTA', (WidgetTester tester) async {
      await pumpPreview(tester, captureLocationScreenConfirming);

      await tester.tap(_ctaLabel);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('pins confirmed 0'), findsOneWidget);
    });

    testWidgets('and shows no sign that anything is in flight', (
      WidgetTester tester,
    ) async {
      // The class doc calls this "a busy state (reverse-geocode / save in
      await pumpPreview(tester, captureLocationScreenConfirming);

      expect(_ctaLabel, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('and gates nothing else — the map still pans', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationScreenConfirming);
      expect(
        find.text(CaptureLocationScreenPreviewFixtures.beirutReadout),
        findsOneWidget,
      );

      await _panMap(tester, const Offset(0, -40));

      // The user is still moving the point while the host is already
      expect(find.text('33.89300, 35.50180'), findsOneWidget);
      expect(
        find.text(CaptureLocationScreenPreviewFixtures.beirutReadout),
        findsNothing,
      );
    });

    testWidgets('and the CTA announces itself identically either way', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, captureLocationScreenLiveMap);
      final SemanticsData idle = tester.getSemantics(_cta).getSemanticsData();

      await pumpPreview(tester, captureLocationScreenConfirming);
      final SemanticsData busy = tester.getSemantics(_cta).getSemanticsData();

      // `Semantics(identifier: …, button: true)` in `_PinCta` never passes
      expect(idle.flagsCollection.isButton, isTrue);
      expect(busy.flagsCollection.isButton, isTrue);
      expect(idle.flagsCollection.isEnabled, Tristate.none);
      expect(busy.flagsCollection.isEnabled, Tristate.none);

      handle.dispose();
    });
  });

  group('CaptureLocationScreen · the states it has no room for', () {
    testWidgets('permission denied arrives under the pin, over a live CTA', (
      WidgetTester tester,
    ) async {
      // The screen has no denied state. `GpsDeniedState` reaches it only by
      await pumpPreview(tester, captureLocationScreenPermissionDenied);

      expect(find.byType(GpsDeniedState), findsOneWidget);
      expect(find.text('Location access required'), findsOneWidget);
      expect(find.byType(CaptureLocationPin), findsOneWidget);

      await tester.tap(_ctaLabel);
      await tester.pumpAndSettle();

      // A confirmed pin on a screen that has just said it cannot locate you.
      expect(find.text('pins confirmed 1'), findsOneWidget);
    });

    testWidgets('outside-service-area copy ships with nowhere to render', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationScreenOutsideServiceArea);

      expect(find.text('Outside service area'), findsOneWidget);
      expect(
        find.text(captureLocationScreenOutsideServiceAreaBody),
        findsOneWidget,
      );
      expect(find.byType(CaptureLocationPin), findsOneWidget);
      expect(_cta, findsOneWidget);
    });
  });

  group('CaptureLocationScreen · the live map', () {
    testWidgets('pans under the pin, through the pin', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationScreenLiveMap);
      expect(
        find.text(CaptureLocationScreenPreviewFixtures.beirutReadout),
        findsOneWidget,
      );

      // Started dead centre, i.e. on the pin: `CaptureLocationPin` is an
      await _panMap(tester, const Offset(0, 40));

      expect(find.text('33.89460, 35.50180'), findsOneWidget);
    });

    testWidgets('draws the centre-on-me affordance the real viewport draws', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationScreenLiveMap);

      expect(
        find.bySemanticsIdentifier('capture_location_my_location'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('capture_location_map'),
        findsOneWidget,
      );
    });
  });

  group('CaptureLocationScreen · compact device', () {
    testWidgets('is really 320 pt wide, not just declared to be', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationScreenCompactPhone);

      expect(tester.getSize(find.byType(CaptureLocationScreen)).width, 320);
      expect(_ctaLabel, findsOneWidget);
      expect(find.byType(CaptureLocationPin), findsOneWidget);
    });
  });
}
