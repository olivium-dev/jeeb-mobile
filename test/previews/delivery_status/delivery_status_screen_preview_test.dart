// Render tests for the DeliveryStatusScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/presentation/delivery_status_screen.dart';

import '../preview_test_harness.dart';

/// The pulsing halo painted under the active milestone. Private to
/// `delivery_stage_indicator.dart` (`_StageDotState.activeKey`), but [Key]
const Key _activeDotKey = Key('delivery-status-active-dot');

/// The one-shot toast the screen raises for `DeliveryStatusError.streamLost`.
const String _reconnectingToast = 'Live status reconnecting…';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryStatusScreen',
    const <String, Widget Function()>{
      'Cold start': deliveryStatusScreenConnecting,
      'Matched': deliveryStatusScreenMatched,
      'No courier yet': deliveryStatusScreenAwaitingJeeber,
      'In transit': deliveryStatusScreenInTransit,
      'Delivered': deliveryStatusScreenDelivered,
      'Cancelled': deliveryStatusScreenCancelled,
      'Stream lost on open': deliveryStatusScreenStreamLostOnOpen,
      'Stream dropped mid-delivery': deliveryStatusScreenStreamDropped,
      'Cancel in flight': deliveryStatusScreenCancelInFlight,
      'Longest content': deliveryStatusScreenLongestContent,
      'Compact viewport': deliveryStatusScreenCompact,
    },
    expectedText: const <String, String>{
      'Cold start': DeliveryStatusScreenCaptions.connecting,
      'Matched': DeliveryStatusScreenCaptions.matched,
      'No courier yet': DeliveryStatusScreenCaptions.awaitingJeeber,
      'In transit': DeliveryStatusScreenCaptions.inTransit,
      'Delivered': DeliveryStatusScreenCaptions.delivered,
      'Cancelled': DeliveryStatusScreenCaptions.cancelled,
      'Stream lost on open': DeliveryStatusScreenCaptions.streamLostOnOpen,
      'Stream dropped mid-delivery': DeliveryStatusScreenCaptions.streamDropped,
      'Cancel in flight': DeliveryStatusScreenCaptions.cancelInFlight,
      'Longest content': DeliveryStatusScreenCaptions.longestContent,
      'Compact viewport': DeliveryStatusScreenCaptions.compact,
    },
  );

  group('DeliveryStatusScreen preview specifics', () {
    testWidgets('cold start is a spinner with no delivery and no actions', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenConnecting);

      expect(find.text('Loading delivery…'), findsOneWidget);
      // No subtitle, no stepper, no CTAs: `mode` is still `loading`, so the
      expect(find.textContaining('Delivery #'), findsNothing);
      expect(find.text('Cancel delivery'), findsNothing);
      expect(find.text('Contact Jeeber'), findsNothing);
    });

    testWidgets('matched is the only state with BOTH CTAs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenMatched);

      expect(find.text('Delivery #ORD-4821'), findsOneWidget);
      expect(find.text('Cancel delivery'), findsOneWidget);
      expect(find.text('Contact Jeeber'), findsOneWidget);
      // Pre-pickup, so no ETA: `isEtaVisible` is gated on the in-transit stage.
      expect(find.textContaining('min'), findsNothing);
    });

    testWidgets('no courier yet keeps Cancel and withdraws Contact', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenAwaitingJeeber);

      expect(find.text('Looking for a Jeeber…'), findsOneWidget);
      expect(find.text('Cancel delivery'), findsOneWidget);
      // `canContactJeeber` needs a phone number on the snapshot; there is no
      expect(find.text('Contact Jeeber'), findsNothing);
    });

    testWidgets('in transit shows the ETA and drops Cancel', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenInTransit);

      expect(find.text('8 min'), findsOneWidget);
      expect(find.text('Contact Jeeber'), findsOneWidget);
      // BR-4: once the parcel is in hand the sender must escalate via dispute.
      expect(find.text('Cancel delivery'), findsNothing);
    });

    testWidgets('a DELIVERED delivery still says it is looking for a courier', (
      WidgetTester tester,
    ) async {
      // The finding, pinned: `_ReadyView` hands `snapshot.jeeber` to
      await pumpPreview(tester, deliveryStatusScreenDelivered);

      expect(find.text('Delivered successfully'), findsOneWidget);
      expect(find.text('Looking for a Jeeber…'), findsOneWidget);
      expect(find.text('Cancel delivery'), findsNothing);
      expect(find.text('Contact Jeeber'), findsNothing);
    });

    testWidgets('a cancelled delivery is contradicted by its own stepper', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenCancelled);

      expect(find.text('Delivery cancelled'), findsOneWidget);
      // The milestone row keeps its timestamp …
      expect(find.text('at 10:00'), findsOneWidget);
      // … while the stepper is zeroed and nothing pulses.
      expect(find.byKey(_activeDotKey), findsNothing);
      // The ARB has `deliveryStageCancelled`; nothing on this screen reads it,
      expect(find.text('Cancelled'), findsNothing);
      expect(find.text('Cancel delivery'), findsNothing);
    });

    testWidgets('a stream lost on open offers a Retry over a promise', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenStreamLostOnOpen);

      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // …and simultaneously a toast claiming the opposite. Nothing
      expect(find.text(_reconnectingToast), findsOneWidget);
    });

    testWidgets('a mid-delivery drop throws away a complete snapshot', (
      WidgetTester tester,
    ) async {
      // The strongest finding these previews produced. The cubit is holding a
      await pumpPreview(tester, deliveryStatusScreenStreamDropped);

      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Delivery #ORD-4828'), findsNothing);
      expect(find.text('6 min'), findsNothing);
      expect(find.textContaining('Hamra'), findsNothing);
      expect(find.text('Karim H.'), findsNothing);
    });

    testWidgets('a dropped stream raises exactly ONE toast, then silence', (
      WidgetTester tester,
    ) async {
      // A dropped stream reaches the cubit TWICE — `onError` emits
      await pumpPreview(tester, deliveryStatusScreenStreamDropped);
      expect(find.text(_reconnectingToast), findsOneWidget);

      // 4 s display + the exit transition, and nothing is queued behind it.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text(_reconnectingToast),
        findsNothing,
        reason: 'the onDone re-emit is identical and must be de-duplicated',
      );
      // The page underneath does NOT recover when the toast goes: this is a
      expect(find.text('Connection lost'), findsOneWidget);
    });

    testWidgets('an open-time failure behaves the same way', (
      WidgetTester tester,
    ) async {
      // The control: with no snapshot in hand, `onDone` finds
      await pumpPreview(tester, deliveryStatusScreenStreamLostOnOpen);
      expect(find.text(_reconnectingToast), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_reconnectingToast), findsNothing);
      expect(find.text('Connection lost'), findsOneWidget);
    });

    testWidgets('cancel in flight is one label swap and nothing else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenCancelInFlight);

      final Finder cancel = find.text('Cancel delivery');
      await tester.ensureVisible(cancel);
      await tester.pump();
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.text('Cancel this delivery?'), findsOneWidget);
      await tester.tap(find.text('Yes, cancel'));
      await tester.pumpAndSettle();

      // The gateway's `cancel()` future never completes, so this is the whole
      expect(find.text('Cancelling…'), findsOneWidget);
      expect(find.text('Cancel delivery'), findsNothing);
      // …and nothing else on the screen acknowledges the write. Contact stays
      expect(find.text('Contact Jeeber'), findsOneWidget);
      expect(find.text('Delivery #ORD-4829'), findsOneWidget);
    });

    testWidgets('a four-hour ETA renders as "240 min"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenLongestContent);

      // `deliveryEtaMinutes` is the only ETA plural in the ARB and the screen
      expect(find.text('240 min'), findsOneWidget);
      expect(find.textContaining(' h'), findsNothing);
    });

    testWidgets('longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenLongestContent);

      // Every long string is rendered in full — nothing is ellipsized or
      expect(
        find.text('Delivery #REQ-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f'),
        findsOneWidget,
      );
      expect(
        find.text('Rue Abdel Aziz, Hamra, Ras Beirut, Beirut Governorate'),
        findsOneWidget,
      );
      expect(find.text('Abdulrahman Al-Muhandis Al-Trabulsi'), findsOneWidget);
      expect(find.text('Pickup truck'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the compact card renders its own delivery, not a neighbour\'s',
        (WidgetTester tester) async {
      await pumpPreview(tester, deliveryStatusScreenCompact);

      expect(find.text('Delivery #ORD-4830'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
    });

    testWidgets('at a real phone width the OMDS stepper labels overflow', (
      WidgetTester tester,
    ) async {
      // Not a defect in this screen and not a regression in this section: the
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, deliveryStatusScreenInTransit);

      final Object? error = tester.takeException();
      expect(error, isFlutterError);
      expect(error.toString(), contains('overflowed'));
    });
  });
}
