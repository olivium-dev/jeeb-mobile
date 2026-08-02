// Render tests for the DeliveryStatusScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// `expectedText` pins the dev-chrome CAPTION each card carries, not screen
// copy. Three pairs of these states are indistinguishable to `find.text`: the
// two stream failures render the identical error page (that IS the finding),
// and cancel-in-flight opens as an ordinary pre-pickup delivery. A suite that
// pinned screen copy would either have nothing to pin or would pass with two
// previews wired to the same fixture. The `preview specifics` group below then
// asserts the real state behind every caption, so the caption is never the
// whole proof.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/presentation/delivery_status_screen.dart';

import '../preview_test_harness.dart';

/// The pulsing halo painted under the active milestone. Private to
/// `delivery_stage_indicator.dart` (`_StageDotState.activeKey`), but [Key]
/// equality is by value.
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
      // whole body is the spinner. A gateway that never answers leaves it here.
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
      // courier at all, so the button is correctly absent.
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
      // `DeliveryJeeberCard` with no regard for lifecycle, so a terminal
      // snapshot without a courier renders the pre-match spinner under the
      // success banner. This is the card the Screen Catalog has shipped since
      // DT-04. If someone makes the card lifecycle-aware, this test fails and
      // should be updated — deliberately, not by accident.
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
      // so the red banner is the only element that names the state.
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
      // re-subscribes without a tap: `_subscribe()` is only reachable from
      // `retry()`, which only the button calls.
      expect(find.text(_reconnectingToast), findsOneWidget);
    });

    testWidgets('a mid-delivery drop throws away a complete snapshot', (
      WidgetTester tester,
    ) async {
      // The strongest finding these previews produced. The cubit is holding a
      // full in-transit snapshot — ETA, both addresses, the courier — and the
      // view discards all of it because it branches on `mode` alone.
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
      // `streamLost`, and then the same stream's `onDone` sees
      // `snapshot.isInFlight` and emits it again. The second emit is identical
      // to the first and `DeliveryStatusState` is `Equatable`, so `Cubit`
      // discards it and the listener never runs twice. Pinned because the
      // double path is real and the de-duplication that saves it is not
      // obvious from either end.
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
      // dead end until the user taps Retry.
      expect(find.text('Connection lost'), findsOneWidget);
    });

    testWidgets('an open-time failure behaves the same way', (
      WidgetTester tester,
    ) async {
      // The control: with no snapshot in hand, `onDone` finds
      // `isInFlight == false` and stays quiet for a different reason. Same
      // count, so the two failures really are one picture.
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
      // in-flight treatment, held still:
      expect(find.text('Cancelling…'), findsOneWidget);
      expect(find.text('Cancel delivery'), findsNothing);
      // …and nothing else on the screen acknowledges the write. Contact stays
      // live and the stepper still says the delivery is on its way.
      expect(find.text('Contact Jeeber'), findsOneWidget);
      expect(find.text('Delivery #ORD-4829'), findsOneWidget);
    });

    testWidgets('a four-hour ETA renders as "240 min"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenLongestContent);

      // `deliveryEtaMinutes` is the only ETA plural in the ARB and the screen
      // clamps nothing on the way in, so hours are shown as minutes.
      expect(find.text('240 min'), findsOneWidget);
      expect(find.textContaining(' h'), findsNothing);
    });

    testWidgets('longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusScreenLongestContent);

      // Every long string is rendered in full — nothing is ellipsized or
      // clipped; the column just grows inside the scroll view.
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
      // four stepper labels sit in a flex-less `Row` inside
      // `OMDSLabeledStepperProgress`, which `delivery_stage_indicator.dart`
      // already documents and pins. It is recorded here so the yellow-and-black
      // stripe on the 200% matrix cards is recognized as that known OMDS issue
      // rather than something these previews introduced.
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
