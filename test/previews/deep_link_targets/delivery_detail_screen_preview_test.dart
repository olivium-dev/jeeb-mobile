// Render tests for the DeliveryDetailScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';

import '../preview_test_harness.dart';

/// Every QA-targetable child the hub can build, banners included.
const List<String> _kAllRowIds = <String>[
  'order-detail-status-delivered',
  'order-detail-status-cancelled',
  'order-detail-track',
  'order-detail-chat',
  'order-detail-otp',
  'order-detail-rate',
  'order-detail-receipt',
  'order-detail-escalate',
  'order-detail-cancel',
];

/// The fail-open list: every legacy affordance, no banner. Shared verbatim by
/// the in-flight and the failed status previews — the identity is asserted,
const Set<String> _kFailOpenRows = <String>{
  'order-detail-track',
  'order-detail-chat',
  'order-detail-otp',
  'order-detail-rate',
  'order-detail-escalate',
  'order-detail-cancel',
};

/// Which of [_kAllRowIds] are on screen right now.
Set<String> _rows(WidgetTester tester) => <String>{
      for (final String id in _kAllRowIds)
        if (find.byKey(Key(id)).evaluate().isNotEmpty) id,
    };

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryDetailScreen',
    const <String, Widget Function()>{
      'Status pending · fails open': deliveryDetailScreenStatusPending,
      'Status unavailable · fails open': deliveryDetailScreenStatusUnavailable,
      'Active · pre-pickup (cancel open)': deliveryDetailScreenActivePrePickup,
      'Active · in transit (cancel closed)':
          deliveryDetailScreenActiveInTransit,
      'Delivered · banner + Rate + Receipt': deliveryDetailScreenDelivered,
      'Cancelled · banner + Report only': deliveryDetailScreenCancelled,
      'Expired → Cancelled banner': deliveryDetailScreenExpiredTerminal,
      'Compact 320 pt · delivered': deliveryDetailScreenCompactDelivered,
    },
    expectedText: const <String, String>{
      // Rate is offered ONLY by the delivered bucket and by fail-open, and
      'Status pending · fails open': 'Rate your delivery',
      // Tracking survives in fail-open and in both active states; the specifics
      'Status unavailable · fails open': 'Live tracking',
      // The free-cancel window, open.
      'Active · pre-pickup (cancel open)': 'Cancel delivery',
      // …and closed: OTP is what is left of the at-door leg.
      'Active · in transit (cancel closed)': 'Verify OTP',
      // Banner title — only the delivered bucket builds it.
      'Delivered · banner + Rate + Receipt': 'Delivered',
      // Banner body, so the cancelled pair pins two different strings.
      'Cancelled · banner + Report only': 'This delivery was cancelled.',
      // An EXPIRED delivery, and the word on screen is "Cancelled".
      'Expired → Cancelled banner': 'Cancelled',
      // The longest run of text the screen has to wrap, at the narrow floor.
      'Compact 320 pt · delivered': 'This delivery is complete.',
    },
  );

  group('DeliveryDetailScreen preview specifics', () {
    testWidgets('status in flight → the full legacy list, no banner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenStatusPending);

      // This is the first frame of EVERY delivery, a delivered one included:
      expect(_rows(tester), _kFailOpenRows);
      // Rate AND Cancel together: no real lifecycle state produces that pair.
      expect(find.byKey(const Key('order-detail-rate')), findsOneWidget);
      expect(find.byKey(const Key('order-detail-cancel')), findsOneWidget);
    });

    testWidgets('a FAILED status read is indistinguishable from an in-flight '
        'one — same rows, no error copy, nothing to retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenStatusUnavailable);

      expect(_rows(tester), _kFailOpenRows);
      // `_loadStatus` swallows OrderChatSummaryException and leaves `_statusId`
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Delivered'), findsNothing);
      expect(find.text('Cancelled'), findsNothing);
    });

    testWidgets('pre-pickup offers Cancel and never Rate', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenActivePrePickup);

      expect(_rows(tester), <String>{
        'order-detail-track',
        'order-detail-chat',
        'order-detail-otp',
        'order-detail-escalate',
        'order-detail-cancel',
      });
    });

    testWidgets('in transit withdraws Cancel and keeps everything else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenActiveInTransit);

      expect(_rows(tester), <String>{
        'order-detail-track',
        'order-detail-chat',
        'order-detail-otp',
        'order-detail-escalate',
      });
    });

    testWidgets('delivered hides Cancel / OTP / tracking structurally', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenDelivered);

      expect(_rows(tester), <String>{
        'order-detail-status-delivered',
        'order-detail-chat',
        'order-detail-rate',
        'order-detail-receipt',
        'order-detail-escalate',
      });
    });

    testWidgets('cancelled leaves the customer one affordance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenCancelled);

      expect(_rows(tester), <String>{
        'order-detail-status-cancelled',
        'order-detail-escalate',
      });
    });

    // The reason this state has its own preview: `_bucket` folds `expired`,
    testWidgets('an EXPIRED delivery is presented as cancelled', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenExpiredTerminal);

      expect(
        find.byKey(const Key('order-detail-status-cancelled')),
        findsOneWidget,
      );
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('This delivery was cancelled.'), findsOneWidget);
      // Nothing anywhere says "expired", so the two terminals are one surface.
      expect(find.textContaining('xpired'), findsNothing);
    });

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpPreview(tester, deliveryDetailScreenDelivered);

      expect(tester.getSize(find.byType(DeliveryDetailScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailScreenCompactDelivered);

      expect(
        tester.getSize(find.byType(DeliveryDetailScreen)),
        const Size(320, 568),
      );
    });

    // The accessibility ceiling the matrix renders for these two previews, run
    testWidgets('the fullest list survives AR at 200% text', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(
        tester,
        deliveryDetailScreenStatusPending,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the delivered banner survives AR at 200% text on the 320 pt '
        'floor', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(
        tester,
        deliveryDetailScreenCompactDelivered,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
