// Render tests for the JeeberActiveDeliveriesBanner previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This widget is unusually easy to test into a false pass: FOUR of its six
// states are near-identical stacks of the same row, and two more render
// literally nothing. A render-only check would pass with every preview wired to
// the same fixture — so each state pins a string only IT can produce, and the
// two invisible states pin the ABSENCE of the header and the CTA (there is no
// text to find in a `SizedBox.shrink`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/jeeber_home/jeeber_active_deliveries_banner_preview.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's title. Declared here so a preview quietly
/// rewired to a short name fails instead of silently losing the one state that
/// exercises the non-flexible "Open chat" button against an `Expanded` title.
const String _kLongName = 'Abdulrahman Al-Muhandis Al-Trabulsi';

/// The untitled row's request id — also its route id, hence its button key.
const String _kOrphanRequestId = 'f2244baa-ff25-4316-b723-c08a80cd3da9';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberActiveDeliveriesBanner',
    const <String, Widget Function()>{
      'One accepted order': jeeberActiveDeliveriesBannerSingle,
      'Three accepted orders': jeeberActiveDeliveriesBannerThree,
      'Longest counterpart name': jeeberActiveDeliveriesBannerLongName,
      'Untitled order · id fallback': jeeberActiveDeliveriesBannerUntitled,
      'Empty · self-hidden': jeeberActiveDeliveriesBannerEmpty,
      'Loading · self-hidden': jeeberActiveDeliveriesBannerLoading,
    },
    expectedText: const <String, String>{
      // Row title from `counterpartName`, plus the singular header.
      'One accepted order': 'Rami Haddad',
      // Only this state can produce the plural header.
      'Three accepted orders': '3 active deliveries',
      'Longest counterpart name': _kLongName,
      // The `'Order <id>'` fallback is asserted verbatim because it is the
      // current contract AND it is hardcoded English — see the AR test below.
      // If it is ever localized, this line must change with it.
      'Untitled order · id fallback': 'Order $_kOrphanRequestId',
    },
  );

  group('JeeberActiveDeliveriesBanner preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT reload it — `previewCanvas` produces the same widget types, so
    // the banner's `State` is UPDATED rather than replaced, `initState` never
    // re-runs, and the second preview would still show the first one's rows.

    testWidgets('the single row pluralizes the header for ONE delivery', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberActiveDeliveriesBannerSingle);

      expect(find.text('1 active delivery'), findsOneWidget);
      expect(find.textContaining('active deliveries'), findsNothing);
      expect(find.text('Open chat'), findsOneWidget);
    });

    testWidgets('each of the three rows resolves its own title branch', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberActiveDeliveriesBannerThree);

      // counterpartName wins over title…
      expect(find.text('Nadia Khoury'), findsOneWidget);
      expect(find.text('Grocery run'), findsNothing);
      // …title is used when there is no counterpart…
      expect(find.text('Pharmacy run'), findsOneWidget);
      // …and displayId is the last labelled fallback.
      expect(find.text('ORD-23748'), findsOneWidget);
      // Three rows, three independently routed CTAs.
      expect(find.text('Open chat'), findsNWidgets(3));
      expect(find.byKey(const Key('jeeber-active-open-chat-r-203')),
          findsOneWidget);
    });

    testWidgets('the empty state renders nothing at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberActiveDeliveriesBannerEmpty);

      // Additive by contract: no header, no row, no CTA — the dashboard's
      // no-requests layout must be byte-identical without accepted orders.
      expect(find.textContaining('active deliver'), findsNothing);
      expect(find.text('Open chat'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the in-flight read renders nothing either — no skeleton', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberActiveDeliveriesBannerLoading);

      expect(find.byType(Text), findsNothing);
      // No spinner, no reserved space: the banner has no loading affordance,
      // which is why an arriving order pops in rather than fading in.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('AR localizes the header and the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberActiveDeliveriesBannerSingle,
        locale: const Locale('ar'),
      );

      expect(find.text('توصيلة نشطة واحدة'), findsOneWidget);
      expect(find.text('فتح المحادثة'), findsOneWidget);
      expect(find.text('Open chat'), findsNothing);
    });

    testWidgets('…but the id fallback title stays English in AR', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberActiveDeliveriesBannerUntitled,
        locale: const Locale('ar'),
      );

      // `_ActiveDeliveryRow._title` takes an `AppLocalizations` and never uses
      // it, so the unlabelled row reads "Order <uuid>" in an Arabic UI. Pinned
      // on the id (not the whole string) so localizing the prefix — the fix —
      // keeps this passing as long as the id survives.
      expect(find.textContaining(_kOrphanRequestId), findsOneWidget);
    });
  });
}
