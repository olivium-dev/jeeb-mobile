// Render tests for the TrackingMapSurface previews.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/courier_position_notice.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'No snapshot yet': trackingMapSurfaceAwaitingSnapshot,
  'Live fix, no notice': trackingMapSurfaceLiveFix,
  'Position stale (3 min)': trackingMapSurfaceStale,
  'Signal lost (5 min)': trackingMapSurfaceLost,
  'Signal lost, under a minute': trackingMapSurfaceLostNoAge,
  'Signal lost, longest copy': trackingMapSurfaceLostLongAge,
};

const Size _kPhone = Size(390, 844);

Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(_kPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpPreview(tester, preview, locale: locale);
}

Future<Object?> _overflowAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(_kPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
  return tester.takeException();
}

/// Pumps [preview] the way the canvas's **200% text** rendering does, and
/// returns the exception the frame reported, if any.
Future<Object?> _pumpAtDoubleText(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
  return tester.takeException();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TrackingMapSurface',
    _previews,
    // Captions, not widget output — see the header. Every state names itself,
    expectedText: const <String, String>{
      'No snapshot yet': 'No snapshot yet: placeholder only, no overlay',
      'Live fix, no notice': 'Live fix: notice mounted and silent',
      'Position stale (3 min)':
          'Stale rung: quiet chip, coordinates still published',
      'Signal lost (5 min)': 'Lost rung: loud chip, no coordinates at all',
      'Signal lost, under a minute':
          'Lost, age under a minute: number dropped',
      'Signal lost, longest copy': 'Lost, 100 min: longest plausible chip',
    },
  );

  group('TrackingMapSurface preview invariants', () {
    // sprint-009 P0: with no `com.google.android.geo.API_KEY` a live GoogleMap
    _previews.forEach((String state, Widget Function() preview) {
      testWidgets('$state renders the placeholder, never a live map', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, preview);

        expect(find.byKey(TrackingMapSurface.rootKey), findsOneWidget);
        expect(find.byType(TrackingGoogleMap), findsNothing);
        expect(find.byIcon(Icons.navigation_outlined), findsOneWidget);
      });
    });

    testWidgets('the accessibility identifier survives every state', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        expect(
          tester.getSemantics(find.byKey(TrackingMapSurface.rootKey)).identifier,
          'tracking_map',
        );
      }
    });
  });

  group('TrackingMapSurface preview specifics', () {
    // The assertion the caption-based `expectedText` above cannot make: six
    testWidgets('no snapshot mounts no overlay at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingMapSurfaceAwaitingSnapshot);

      expect(
        find.byType(CourierPositionNotice),
        findsNothing,
        reason: 'null info takes the no-Stack branch of `_MapBody`',
      );
    });

    testWidgets('a live fix mounts the notice and keeps it collapsed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingMapSurfaceLiveFix);

      // Mounted: the layout always mounts it once `info` is non-null…
      expect(find.byType(CourierPositionNotice), findsOneWidget);
      // …and the WIDGET decides there is nothing to say, not the layout.
      expect(tester.getSize(find.byType(CourierPositionNotice)), Size.zero);
      expect(find.textContaining('min'), findsNothing);
      expect(find.textContaining('No signal'), findsNothing);
    });

    testWidgets('stale and lost do NOT share copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingMapSurfaceStale);
      expect(find.textContaining("Jeeber's location is 3 min old"),
          findsOneWidget);
      expect(
        find.textContaining('No signal'),
        findsNothing,
        reason: "the customer's correct next action differs between the two "
            'rungs (P6), so the two rungs must not read alike',
      );

      await pumpPreview(tester, trackingMapSurfaceLost);
      expect(find.textContaining('No signal'), findsOneWidget);
      expect(find.textContaining('5 min ago'), findsOneWidget);
      expect(find.textContaining('min old'), findsNothing);
    });

    testWidgets('an age under a minute drops the number', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingMapSurfaceLostNoAge);

      expect(find.text('No signal from the Jeeber'), findsOneWidget);
      expect(find.textContaining('0 min'), findsNothing);
    });

    testWidgets('the longest state really is the longest', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingMapSurfaceLostLongAge);
      expect(find.textContaining('100 min ago'), findsOneWidget);
    });

    testWidgets('the notice copy is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        trackingMapSurfaceLost,
        locale: const Locale('ar'),
      );

      expect(find.textContaining('No signal'), findsNothing);
      expect(find.textContaining('لا إشارة من الجيبر'), findsOneWidget);
    });

    testWidgets('the overlay does not mirror under RTL — and should not', (
      WidgetTester tester,
    ) async {
      // `_MapBody._stacked` anchors the notice with `PositionedDirectional`
      await _pumpOnPhone(tester, trackingMapSurfaceLostNoAge);
      final Rect ltr = tester.getRect(find.byType(CourierPositionNotice));
      expect(tester.takeException(), isNull);

      await _pumpOnPhone(
        tester,
        trackingMapSurfaceLostNoAge,
        locale: const Locale('ar'),
      );
      final Rect rtl = tester.getRect(find.byType(CourierPositionNotice));
      expect(tester.takeException(), isNull);

      // Same band, same baseline: bottom-anchored `Spacing.medium` above the
      expect(ltr.bottom, rtl.bottom);
      // And centred, so the two locales agree on the horizontal axis by
      expect(ltr.center.dx, closeTo(_kPhone.width / 2, 1));
      expect(rtl.center.dx, closeTo(_kPhone.width / 2, 1));
    });
  });

  // FINDING, and the reason these previews were worth writing.
  group('TrackingMapSurface layout ceilings', () {
    testWidgets('the ORDINARY stale notice overflows at phone width', (
      WidgetTester tester,
    ) async {
      // Not a long-tail state: the plain 3-minute stale notice, at 1× text, on
      final Object? overflow = await _overflowAtPhoneWidth(
        tester,
        trackingMapSurfaceStale,
      );

      expect(
        overflow,
        isFlutterError,
        reason: 'a notice the customer cannot read is not an affordance',
      );
      expect('$overflow', contains('overflowed by 57 pixels'));
    });

    testWidgets('the lost notice overflows further — English', (
      WidgetTester tester,
    ) async {
      expect(
        '${await _overflowAtPhoneWidth(tester, trackingMapSurfaceLost)}',
        contains('overflowed by 270 pixels'),
      );
    });

    testWidgets('the lost notice overflows in Arabic too', (
      WidgetTester tester,
    ) async {
      // Shorter copy, same failure: 175 pt. Worth its own case because "it
      expect(
        '${await _overflowAtPhoneWidth(tester, trackingMapSurfaceLost, locale: const Locale('ar'))}',
        contains('overflowed by 175 pixels'),
      );
    });

    testWidgets('the longest copy overflows worst', (
      WidgetTester tester,
    ) async {
      expect(
        '${await _overflowAtPhoneWidth(tester, trackingMapSurfaceLostLongAge)}',
        contains('overflowed by 295 pixels'),
      );
    });

    testWidgets('the SHORTEST notice fits at phone width in both locales', (
      WidgetTester tester,
    ) async {
      // The control. Without it, "the chip overflows" could be read as "the
      expect(
        await _overflowAtPhoneWidth(tester, trackingMapSurfaceLostNoAge),
        isNull,
      );
      expect(
        await _overflowAtPhoneWidth(
          tester,
          trackingMapSurfaceLostNoAge,
          locale: const Locale('ar'),
        ),
        isNull,
      );
    });

    testWidgets('a state that fits at 1x still overflows at 200% text', (
      WidgetTester tester,
    ) async {
      // Same chip, same absent constraint, reached from the other direction:
      expect(
        await _pumpAtDoubleText(tester, trackingMapSurfaceLost),
        isFlutterError,
      );
    });

    testWidgets('the silent states survive 200% text', (
      WidgetTester tester,
    ) async {
      // The placeholder chrome itself is sound: a container, a centred icon and
      expect(
        await _pumpAtDoubleText(tester, trackingMapSurfaceAwaitingSnapshot),
        isNull,
      );
      expect(
        await _pumpAtDoubleText(tester, trackingMapSurfaceLiveFix),
        isNull,
      );
    });
  });
}
