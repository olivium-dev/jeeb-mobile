// Render tests for the JeeberActiveDeliveriesBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's title. Declared here so a preview quietly
/// rewired to a short name fails instead of silently losing the one state that
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
      'Untitled order · id fallback': 'Order $_kOrphanRequestId',
    },
  );

  group('JeeberActiveDeliveriesBanner preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester

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
      expect(find.textContaining(_kOrphanRequestId), findsOneWidget);
    });
  });
}
