import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/courier_position_notice.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CourierPositionNotice',
    const <String, Widget Function()>{
      'Stale · 3 min old': courierPositionNoticeStale,
      'Lost · 5 min ago': courierPositionNoticeLost,
      'Lost · under a minute': courierPositionNoticeLostSubMinute,
      'Stale · no age reported': courierPositionNoticeStaleNoAge,
      'Lost · overnight': courierPositionNoticeLostOvernight,
      'Live · nothing to say': courierPositionNoticeLive,
    },
    expectedText: const <String, String>{
      'Stale · 3 min old': "Jeeber's location is 3 min old",
      'Lost · 5 min ago': 'No signal from the Jeeber — last seen 5 min ago',
      'Lost · under a minute': 'No signal from the Jeeber',
      'Stale · no age reported': "Jeeber's location is 0 min old",
      'Lost · overnight':
          'No signal from the Jeeber — last seen 1440 min ago',
    },
  );

  group('CourierPositionNotice preview specifics', () {
    testWidgets('a live position renders no row at all — zero pixels, not '
        'an empty pill', (WidgetTester tester) async {
      await pumpPreview(tester, courierPositionNoticeLive);

      expect(find.byType(CourierPositionNotice), findsOneWidget);
      expect(
        tester.getSize(find.byType(CourierPositionNotice)),
        Size.zero,
        reason: 'the widget owns the decision to disappear, so it must '
            'contribute no height to the map surface above it',
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('stale and lost do not share copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, courierPositionNoticeStale);
      expect(find.textContaining('No signal'), findsNothing);
      expect(find.textContaining('last seen'), findsNothing);

      await pumpPreview(tester, courierPositionNoticeLost);
      expect(find.textContaining("Jeeber's location"), findsNothing);
    });

    testWidgets('a sub-minute age drops the number rather than reading '
        '"0 min ago"', (WidgetTester tester) async {
      await pumpPreview(tester, courierPositionNoticeLostSubMinute);

      expect(find.text('No signal from the Jeeber'), findsOneWidget);
      expect(find.textContaining('0 min'), findsNothing);
      expect(find.textContaining('min ago'), findsNothing);
    });

    testWidgets('the copy is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        courierPositionNoticeLost,
        locale: const Locale('ar'),
      );

      expect(
        find.text('لا إشارة من الجيبر — آخر ظهور قبل 5 دقيقة'),
        findsOneWidget,
      );
      expect(find.textContaining('No signal'), findsNothing);
    });

    testWidgets('the two rungs are told apart by icon as well as colour', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, courierPositionNoticeStale);
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsNothing);

      await pumpPreview(tester, courierPositionNoticeLost);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.schedule_outlined), findsNothing);
    });

    testWidgets('CHARACTERIZATION — given a band narrower than its label the '
        'pill OVERFLOWS: it can neither wrap nor ellipsize', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(240, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        previewCanvas(courierPositionNoticeLostOvernight, const Locale('en')),
      );
      await tester.pump();

      final Object? error = tester.takeException();
      expect(
        error,
        isA<FlutterError>(),
        reason: 'a label too wide for its band must surface as an overflow — '
            'there is no maxLines and no TextOverflow.ellipsis to absorb it',
      );
      expect('$error', contains('overflowed'));
      expect(
        find.text('No signal from the Jeeber — last seen 1440 min ago'),
        findsOneWidget,
      );
    });
  });
}
