// Render tests for the OrdersTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, and that matters more here than almost
// anywhere: all six previews are the SAME widget — `OrdersTab` — differing only
// in the fake repository handed to its `repository` override. A suite that
// asserted "something rendered" would pass with every fake wired to the same
// snapshot, which is exactly the mistake fixtures of this shape make easy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/money_format.dart';
import 'package:jeeb_mobile/previews/shell/orders_tab_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · first page`, which cannot settle — see the
  // dedicated group below.
  testPreviewsRender(
    'OrdersTab',
    const <String, Widget Function()>{
      'Active · two live deliveries': ordersTabActiveRows,
      'Empty · no orders yet': ordersTabEmpty,
      'Error · offline, retry': ordersTabErrorNetwork,
      'Long addresses · layout ceiling': ordersTabLongAddresses,
      'Unknown amount + unknown status': ordersTabUnknownAmount,
    },
    expectedText: const <String, String>{
      // The SECOND row's pickup address. Pinning the first row's would pass on
      // a fixture that silently dropped everything after item 0.
      'Active · two live deliveries': 'Mar Mikhael',
      // The per-tab subtitle, not the shared 'No orders yet' title — the title
      // is identical on all three tabs and would not prove which one rendered.
      'Empty · no orders yet': 'Active deliveries will show up here.',
      'Error · offline, retry':
          'You appear to be offline. Check your connection and try again.',
      'Long addresses · layout ceiling':
          'Pharmacie Al-Muhandis, Rue Abdel Aziz, Bloc B, 3rd floor, '
              'Hamra, Beirut, Lebanon',
      // The chip label for an unrecognised wire status.
      'Unknown amount + unknown status': 'In progress',
    },
  );

  // The loading sub-state is an indeterminate `CircularProgressIndicator`
  // (`OmdsLoadingState`) held open by a never-completing first page.
  // `pumpAndSettle` — which `pumpPreview` calls — never returns while one is on
  // screen, so this preview gets the same three assertions the shared suite
  // makes (builds in EN, builds in AR, renders its OWN state) driven by fixed
  // pumps instead.
  group('OrdersTab previews · Loading · first page', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(ordersTabLoading, locale));
      await tester.pump(); // resolve localizations; `initialLoad` fires here
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · first page · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · first page renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      // The spinner is up...
      expect(find.byKey(const Key('order-history-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and none of the other list sub-states is. That combination is true
      // of no other preview in this file.
      expect(find.byKey(const Key('order-history-error')), findsNothing);
      expect(
        find.byKey(const Key('order-history-empty-active')),
        findsNothing,
      );
      expect(find.byKey(const Key('order-history-list-active')), findsNothing);
    });
  });

  group('OrdersTab preview specifics', () {
    // Each sub-state gets its OWN test on purpose. Every preview in this file
    // builds the same element tree — `OrdersTab` → `BlocProvider` keyed
    // `orders-tab-client` → `OrdersResumeRefetcher` → `OrderHistoryScreen` —
    // differing only in the repository closed over by `create`. Pumping a
    // second preview into the same tester would therefore REUSE the first
    // preview's element and its cubit; `create` never runs again, and two
    // states asserted in one test would silently both be the first one.
    testWidgets('the empty preview shows the ACTIVE tab placeholder alone', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ordersTabEmpty);

      expect(find.byKey(const Key('order-history-empty-active')), findsOneWidget);
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.byKey(const Key('order-history-list-active')), findsNothing);
      expect(find.byKey(const Key('order-history-error')), findsNothing);
    });

    testWidgets('the error preview offers a retry affordance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ordersTabErrorNetwork);

      expect(find.byKey(const Key('order-history-error')), findsOneWidget);
      expect(find.text("Couldn't load orders"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(find.byKey(const Key('order-history-list-active')), findsNothing);
    });

    testWidgets('the active preview really renders TWO rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ordersTabActiveRows);

      expect(
        find.byKey(const Key('order-history-card-order-cod-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('order-history-card-order-cod-002')),
        findsOneWidget,
      );
      // The two statuses the live COD run walked through, side by side.
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Matched'), findsOneWidget);
      // Real amounts render through the one MoneyFormat rule.
      expect(
        find.text(MoneyFormat.format(6, currency: 'USD')),
        findsOneWidget,
      );
    });

    // T11 / SW-02: a missing price is UNKNOWN, never a fabricated zero.
    testWidgets('the unpriced preview shows an em-dash, never \$0.00', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ordersTabUnknownAmount);

      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
    });

    // The tab is mounted against BOUNDED height in the shell's IndexedStack;
    // `OrderHistoryScreen` is a Column ending in `Expanded(TabBarView)` and
    // cannot lay out on an unbounded vertical axis. If a future edit wraps
    // `_hosted` in a scroll view the way `in_progress_tab_preview.dart` does,
    // every preview in this file throws instead of rendering.
    testWidgets('the previews host the tab against bounded height', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, ordersTabActiveRows);

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(TabBarView), findsOneWidget);
      expect(tester.getSize(find.byType(TabBarView)).height, greaterThan(0));
    });
  });
}
