import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';

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

    testWidgets('a stale fix draws no marker, though coordinates exist', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapStaleFix);

      expect(find.textContaining('camera 33.8900,35.5000'), findsOneWidget);
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

    testWidgets('a lost position keeps the route but drops the marker', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapPositionLost);

      expect(find.textContaining('route 2 pts'), findsOneWidget);
      expect(find.textContaining('markers 0'), findsOneWidget);
    });

    testWidgets('a single waypoint draws no route yet still frames it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingGoogleMapSingleWaypoint);

      expect(find.textContaining('route 0 pts'), findsOneWidget);
      expect(find.textContaining('camera 33.8869,35.5131'), findsOneWidget);
    });

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
