// Render tests for the TrackingGoogleMap previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This suite carries more weight than most preview tests because the widget
// under review draws nothing on the Flutter side — its build is a platform view
// owned by the native Maps SDK. The reviewable surface is what the widget hands
// that view (camera / markers / polylines), which each preview renders as a
// readout line, so `expectedText` below is a genuine contract assertion rather
// than a "did something appear" check: `Stale fix` reading `markers 1` is the
// courier-marker P0 coming back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';
import 'package:jeeb_mobile/previews/live_tracking/tracking_google_map_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TrackingGoogleMap',
    const <String, Widget Function()>{
      'Live fix on route': trackingGoogleMapLiveFix,
      'Awaiting first fix': trackingGoogleMapAwaitingFirstFix,
      'Stale fix — no marker': trackingGoogleMapStaleFix,
      'Position lost': trackingGoogleMapPositionLost,
      'Single waypoint — no route': trackingGoogleMapSingleWaypoint,
      'Nothing known': trackingGoogleMapNothingKnown,
    },
    // Every string below is derived from the widget's own builders, and every
    // one differs from the other five. A preview that starts showing another
    // preview's state fails here.
    expectedText: const <String, String>{
      'Live fix on route':
          'live · markers 1 · route 2 pts · camera 33.8900,35.5000',
      'Awaiting first fix':
          'awaitingFirstFix · markers 0 · route 2 pts · camera 33.8938,35.5018',
      'Stale fix — no marker':
          'stale · markers 0 · route 2 pts · camera 33.8900,35.5000',
      'Position lost':
          'lost · markers 0 · route 2 pts · camera 33.8938,35.5018',
      'Single waypoint — no route':
          'awaitingFirstFix · markers 0 · route 0 pts · camera 33.8869,35.5131',
      'Nothing known':
          'unset · markers 0 · route 0 pts · camera 33.8938,35.5018',
    },
  );

  group('TrackingGoogleMap preview specifics', () {
    testWidgets('every preview mounts the REAL widget, not a stand-in', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        trackingGoogleMapLiveFix,
        trackingGoogleMapAwaitingFirstFix,
        trackingGoogleMapStaleFix,
        trackingGoogleMapPositionLost,
        trackingGoogleMapSingleWaypoint,
        trackingGoogleMapNothingKnown,
      ]) {
        await pumpPreview(tester, preview);
        expect(find.byType(TrackingGoogleMap), findsOneWidget);
      }
    });

    // The courier-marker P0, stated as the thing that must NOT happen.
    testWidgets('a stale fix draws no marker, though coordinates exist', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapStaleFix);

      // The camera still frames the last known coordinates...
      expect(find.textContaining('camera 33.8900,35.5000'), findsOneWidget);
      // ...but no pin is placed on them.
      expect(find.textContaining('markers 0'), findsOneWidget);
      expect(find.textContaining('markers 1'), findsNothing);
    });

    testWidgets('a live fix is the only state that draws a marker', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapLiveFix);
      expect(find.textContaining('markers 1'), findsOneWidget);

      for (final Widget Function() preview in <Widget Function()>[
        trackingGoogleMapAwaitingFirstFix,
        trackingGoogleMapStaleFix,
        trackingGoogleMapPositionLost,
        trackingGoogleMapSingleWaypoint,
        trackingGoogleMapNothingKnown,
      ]) {
        await pumpPreview(tester, preview);
        expect(find.textContaining('markers 1'), findsNothing);
      }
    });

    // A lost courier keeps the route: the customer still needs to see where the
    // delivery is headed even once the pin is gone.
    testWidgets('a lost position keeps the route but drops the marker', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapPositionLost);

      expect(find.textContaining('route 2 pts'), findsOneWidget);
      expect(find.textContaining('markers 0'), findsOneWidget);
    });

    // The polyline floor: one point is not a line, but it IS a camera target,
    // so the two disagree by design.
    testWidgets('a single waypoint draws no route yet still frames it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapSingleWaypoint);

      expect(find.textContaining('route 0 pts'), findsOneWidget);
      expect(find.textContaining('camera 33.8869,35.5131'), findsOneWidget);
    });

    // Documented in the preview because the fixture makes the two numerically
    // identical: the "nothing known" camera is the hardcoded Beirut constant,
    // not a route point. `route 0 pts` is what distinguishes them.
    testWidgets('with nothing known the camera falls back to Beirut downtown', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapNothingKnown);

      expect(
        find.text('unset · markers 0 · route 0 pts · camera 33.8938,35.5018'),
        findsOneWidget,
      );
    });
  });
}
