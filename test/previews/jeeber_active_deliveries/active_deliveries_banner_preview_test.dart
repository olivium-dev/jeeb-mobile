// Render tests for the ActiveDeliveriesBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';

import '../preview_test_harness.dart';

/// The OMDS card the banner builds once per revealed delivery.
Finder get _cards => find.descendant(
  of: find.byType(ActiveDeliveriesBanner),
  matching: find.byType(OMDSGlassCard),
);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ActiveDeliveriesBanner',
    const <String, Widget Function()>{
      'At rest · one delivery': activeDeliveriesBannerCollapsed,
      'Expanded · just-won order': activeDeliveriesBannerExpanded,
      'Expanded · four, mixed statuses': activeDeliveriesBannerExpandedMany,
      'Expanded · longest content': activeDeliveriesBannerLongContent,
      'Narrow 360 · actions stack': activeDeliveriesBannerNarrow,
      // No `expectedText` entry: this state renders SizedBox.shrink by design,
      'Nothing active · self-hidden': activeDeliveriesBannerHidden,
    },
    expectedText: const <String, String>{
      'At rest · one delivery': 'View all (1)',
      'Expanded · just-won order': 'Flash delivery request',
      'Expanded · four, mixed statuses': 'Delivery 3',
      'Expanded · longest content':
          'Flash delivery request with a rather long title #0',
      'Narrow 360 · actions stack': 'Pharmacy run',
    },
  );

  group('ActiveDeliveriesBanner preview specifics', () {
    testWidgets('the at-rest preview is one row and builds no card', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveriesBannerCollapsed);

      expect(find.text('Your active deliveries'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(_cards, findsNothing);
      // The card's own content must not be reachable while collapsed — that is
      expect(find.text('Flash delivery request'), findsNothing);
      expect(find.text('Open chat'), findsNothing);
    });

    testWidgets('the expanded previews really do open the disclosure', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveriesBannerExpandedMany);

      expect(_cards, findsNWidgets(4));
      expect(find.text('Show less'), findsOneWidget);
      // One chip per non-terminal status, so the four are reviewable together.
      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Picked'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
      expect(find.text('At Door'), findsOneWidget);
    });

    testWidgets('a delivery with no title falls back to the localized label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveriesBannerExpandedMany);

      // `d2` carries neither title nor dropoff: the fallback title renders and
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Dropoff 0'), findsOneWidget);
      expect(find.text('Dropoff 2'), findsNothing);
    });

    testWidgets('390 puts the two actions side by side; 360 stacks them', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveriesBannerExpanded);
      final Offset wideChat = tester.getTopLeft(find.text('Open chat'));
      final Offset wideManage = tester.getTopLeft(find.text('Manage delivery'));
      expect(
        wideManage.dy,
        wideChat.dy,
        reason: 'above the 300px threshold both actions share one row',
      );

      await pumpPreview(tester, activeDeliveriesBannerNarrow);
      final Offset narrowChat = tester.getTopLeft(find.text('Open chat'));
      final Offset narrowManage = tester.getTopLeft(
        find.text('Manage delivery'),
      );
      expect(
        narrowManage.dy,
        greaterThan(narrowChat.dy),
        reason:
            'the S22-width preview must exercise the STACKED branch — the '
            'one the 39px SM-S921B overflow came from',
      );
    });

    testWidgets('the self-hidden preview renders nothing at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveriesBannerHidden);

      expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
      expect(_cards, findsNothing);
      expect(find.text('Your active deliveries'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });
  });
}
