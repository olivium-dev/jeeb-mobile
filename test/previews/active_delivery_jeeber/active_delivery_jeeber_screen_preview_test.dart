// Render tests for the ActiveDeliveryJeeberScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen has ONE axis — the `ActiveDeliveryState` its cubit holds — and
// several of its states are near-neighbours on screen: `InTransit` and
// `AtDoor` differ by one swapped button, the two GPS-permission states differ
// by one bool, and the three unsuccessful terminals share a code path and
// differ only in copy. A render-only check would pass on a preview wired to the
// wrong fixture in every one of those pairs, so each state pins a string of its
// own AND the specifics groups below pin what must be ABSENT — which is where
// the two regression guards (JEBV4-276, the GPS CTA choice) actually live.
//
// One preview per test, always. `previewCanvas` produces the same widget types
// for every preview, so pumping a second one into the same tester UPDATES the
// host element rather than replacing it: `_ActiveDeliveryJeeberScreenHostState`
// keeps the FIRST preview's `late final` cubit and the second preview would
// silently render the first one's state under the second one's name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/active_delivery_jeeber_screen_fixtures.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';

import '../preview_test_harness.dart';

/// The seam-pin identifier the route flow asserts on first frame. Present on
/// the working screen AND on the unavailable shell, which is the point of
/// [activeDeliveryJeeberScreenUnavailable].
const String _markDeliveredRoot = 'mark_delivered_root';

/// Widgets whose presence separates a loaded delivery from every degraded
/// state: the progress card's title and the drop-off card's label.
const String _progressTitle = 'Delivery progress';
const String _dropOffLabel = ActiveDeliveryJeeberScreenFixtures.dropOffLabel;

Finder _semanticsIdentifier(String identifier) => find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.identifier == identifier,
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ActiveDeliveryJeeberScreen',
    const <String, Widget Function()>{
      // `Loading · cold open` is deliberately absent from `expectedText`: the
      // state paints a bare `CircularProgressIndicator` and NO text at all, so
      // there is nothing to pin. It is asserted in its own group below, where
      // the absence is the assertion.
      'Loading · cold open': activeDeliveryJeeberScreenLoading,
      'Unavailable · no seam wired': activeDeliveryJeeberScreenUnavailable,
      'Load failed · retry': activeDeliveryJeeberScreenLoadFailed,
      'Ordered · advance CTA': activeDeliveryJeeberScreenOrdered,
      'In transit · mark delivered': activeDeliveryJeeberScreenInTransit,
      'At door · door OTP': activeDeliveryJeeberScreenAtDoorOtp,
      'GPS blocked · in-app retry':
          activeDeliveryJeeberScreenGpsBlockedRetryable,
      'GPS blocked · settings only':
          activeDeliveryJeeberScreenGpsBlockedSettingsOnly,
      'Delivered · completed': activeDeliveryJeeberScreenCompleted,
      'Completing · no premature banner':
          activeDeliveryJeeberScreenCompletingOptimistically,
      'Cancelled · terminal': activeDeliveryJeeberScreenCancelled,
      'Expired · terminal': activeDeliveryJeeberScreenExpired,
      'Disputed · under review': activeDeliveryJeeberScreenDisputed,
      'Longest content · compact 320 pt':
          activeDeliveryJeeberScreenLongestContent,
    },
    expectedText: const <String, String>{
      'Unavailable · no seam wired': 'Delivery details unavailable.',
      // The cubit's own English literal, NOT the localized fallback — see the
      // preview's doc comment.
      'Load failed · retry': ActiveDeliveryJeeberScreenFixtures.loadErrorMessage,
      // Names the NEXT status, and only the pre-delivering stages have it.
      'Ordered · advance CTA': 'Mark as Picked',
      'In transit · mark delivered': 'Complete Delivery',
      'At door · door OTP': 'Enter delivery code',
      'GPS blocked · in-app retry': 'Allow location',
      'GPS blocked · settings only': 'Open settings',
      'Delivered · completed': 'Delivered successfully',
      // This state renders no banner and no panel, so its own drop-off is the
      // only thing that distinguishes it from a plain `Done`.
      'Completing · no premature banner':
          ActiveDeliveryJeeberScreenFixtures.optimisticDropOffLabel,
      'Cancelled · terminal': 'Delivery cancelled',
      'Expired · terminal': 'Delivery expired',
      'Disputed · under review': 'Delivery under review',
      'Longest content · compact 320 pt':
          ActiveDeliveryJeeberScreenFixtures.longDropOffLabel,
    },
  );

  group('ActiveDeliveryJeeberScreen previews · the degraded surfaces', () {
    testWidgets('loading is a spinner and NOTHING else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenLoading);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No title, no message, no retry, nothing to cancel — the whole reason
      // this state is previewed.
      expect(find.text(_progressTitle), findsNothing);
      expect(find.text(_dropOffLabel), findsNothing);
      expect(
        find.text(ActiveDeliveryJeeberScreenFixtures.loadErrorMessage),
        findsNothing,
      );
      // The app bar title is the only string on screen.
      expect(find.text('Active Delivery'), findsOneWidget);
    });

    testWidgets('the unavailable shell keeps the seam pin and offers no way '
        'out', (WidgetTester tester) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenUnavailable);

      // Indistinguishable from a working delivery to any flow that asserts
      // only the route pin.
      expect(_semanticsIdentifier(_markDeliveredRoot), findsOneWidget);
      expect(find.text('Delivery details unavailable.'), findsOneWidget);
      // Nothing to retry with, and no delivery to act on.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(_progressTitle), findsNothing);
      expect(find.text('Open Chat'), findsNothing);
    });

    testWidgets('a loaded delivery carries the same seam pin', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenInTransit);

      expect(_semanticsIdentifier(_markDeliveredRoot), findsOneWidget);
      expect(find.text(_progressTitle), findsOneWidget);
    });
  });

  group('ActiveDeliveryJeeberScreen previews · the delivering phase', () {
    testWidgets('in transit: the CTA, and no OTP entry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenInTransit);

      expect(find.text('Complete Delivery'), findsOneWidget);
      expect(find.text('Enter delivery code'), findsNothing);
      // JM-051: the stepper drops its own advance button for the whole
      // delivering phase — the journey to Done belongs to the panel.
      expect(find.text('Mark as At Door'), findsNothing);
      expect(find.text('Mark as In Transit'), findsNothing);
    });

    testWidgets('at door: the OTP entry replaces the CTA, under the SAME '
        'label', (WidgetTester tester) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenAtDoorOtp);

      expect(find.text('Enter delivery code'), findsOneWidget);
      // `activeDeliveryOtpSubmit` and `activeDeliveryMarkDone` are both
      // "Complete Delivery", so the swap is invisible from the button alone.
      expect(find.text('Complete Delivery'), findsOneWidget);
      expect(find.text('Mark as At Door'), findsNothing);
    });

    testWidgets('ordered: the quick actions STACK at phone width', (
      WidgetTester tester,
    ) async {
      // `_QuickActions` only builds its `Row` above 448 pt of content width,
      // and a 390 pt phone leaves the list 358 — so the row branch is
      // unreachable on every handset the app supports.
      await pumpPreview(tester, activeDeliveryJeeberScreenOrdered);

      final Offset maps = tester.getCenter(find.text('Open in Maps'));
      final Offset chat = tester.getCenter(find.text('Open Chat'));
      expect(maps.dy, lessThan(chat.dy));
      expect(maps.dx, closeTo(chat.dx, 0.5));
    });
  });

  group('ActiveDeliveryJeeberScreen previews · completion', () {
    testWidgets('a CONFIRMED Done paints the delivered banner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenCompleted);

      expect(find.text('Delivered successfully'), findsOneWidget);
    });

    testWidgets('an OPTIMISTIC Done does NOT (JEBV4-276)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        activeDeliveryJeeberScreenCompletingOptimistically,
      );

      // The OTP path reverts from exactly this frame back to AtDoor, so a
      // banner here tells the jeeber the handover succeeded before anything
      // confirmed it.
      expect(find.text('Delivered successfully'), findsNothing);
      expect(
        find.text(ActiveDeliveryJeeberScreenFixtures.optimisticDropOffLabel),
        findsOneWidget,
      );
    });
  });

  group('ActiveDeliveryJeeberScreen previews · the parked GPS uploader', () {
    testWidgets('recoverable in-app: "Allow location", never "Open settings"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenGpsBlockedRetryable);

      expect(find.text('Live tracking is off'), findsOneWidget);
      expect(find.text('Allow location'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
    });

    testWidgets('permanently denied: "Open settings", never a retry the OS '
        'would drop', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        activeDeliveryJeeberScreenGpsBlockedSettingsOnly,
      );

      expect(find.text('Live tracking is off'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Allow location'), findsNothing);
    });

    testWidgets('a healthy delivery shows no banner at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeDeliveryJeeberScreenInTransit);

      expect(find.text('Live tracking is off'), findsNothing);
    });
  });

  group('ActiveDeliveryJeeberScreen previews · the unsuccessful terminals', () {
    const Map<String, Widget Function()> terminals = <String, Widget Function()>{
      'Delivery cancelled': activeDeliveryJeeberScreenCancelled,
      'Delivery expired': activeDeliveryJeeberScreenExpired,
      'Delivery under review': activeDeliveryJeeberScreenDisputed,
    };

    terminals.forEach((String title, Widget Function() preview) {
      testWidgets('$title drops the stepper, the address AND every action', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, preview);

        expect(find.text(title), findsOneWidget);
        expect(find.text(_progressTitle), findsNothing);
        expect(find.text(_dropOffLabel), findsNothing);
        // `Delivery under review` means support is still working the case and
        // an admin can still resolve it (SM edges 12/13) — the jeeber is given
        // no way to reach anyone from here.
        expect(find.text('Open Chat'), findsNothing);
        expect(find.text('Open in Maps'), findsNothing);
      });
    });
  });
}
