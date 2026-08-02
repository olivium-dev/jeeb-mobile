// Render tests for the InProgressTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string. That matters more here than elsewhere:
// all six previews are the SAME widget seeded through the SAME cubit, so a
// suite that only asserted "something rendered" would pass even if every fake
// repository were wired to the same snapshot — which is precisely the mistake
// the fixtures are shaped to make easy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · spinner`, which cannot settle — see the
  // dedicated group below.
  testPreviewsRender(
    'InProgressTab',
    const <String, Widget Function()>{
      'Two active rows': inProgressTabTwoRows,
      'Empty · no active deliveries': inProgressTabEmpty,
      'Failed · cold load': inProgressTabFailed,
      'Searching · track without chat': inProgressTabSearching,
      'Long title + both CTAs': inProgressTabLongContent,
    },
    expectedText: const <String, String>{
      // The first row's title — the second row ('Grocery run') is asserted
      // separately below, so this one string cannot stand in for the pair.
      'Two active rows': 'Pharmacy run',
      'Empty · no active deliveries': 'No active deliveries yet.',
      'Failed · cold load': "Couldn't load your home",
      'Searching · track without chat': 'Birthday cake, Hamra',
      'Long title + both CTAs':
          'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
    },
  );

  // The loading sub-state is an indeterminate `CircularProgressIndicator`
  // (`OmdsLoadingState`) held open by a never-completing load. `pumpAndSettle`
  // — which `pumpPreview` calls — never returns while one is on screen, so this
  // preview gets the same three assertions the shared suite makes (builds in
  // EN, builds in AR, renders its OWN state) driven by fixed pumps instead.
  group('InProgressTab previews · Loading · spinner', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(inProgressTabLoading, locale));
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      // The spinner is up...
      expect(find.byKey(const Key('in-progress-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and none of the other four sub-states is. That combination is true
      // of no other preview in this file.
      expect(find.byKey(const Key('in-progress-list')), findsNothing);
      expect(find.byKey(const Key('in-progress-empty')), findsNothing);
      expect(find.byKey(const Key('in-progress-error')), findsNothing);
    });
  });

  group('InProgressTab preview specifics', () {
    // Each sub-state gets its OWN test on purpose. Every preview in this file
    // is the same widget tree — `BlocProvider` → `SingleChildScrollView` →
    // `InProgressTab` — differing only in the repository closed over by
    // `create`. Pumping a second preview into the same tester therefore REUSES
    // the first preview's element, and with it the first preview's cubit:
    // `create` never runs again. Two states asserted in one test would silently
    // both be the first one.
    const Map<String, ({Widget Function() preview, Key present, Key absent})>
        subStates = <String,
            ({Widget Function() preview, Key present, Key absent})>{
      'list': (
        preview: inProgressTabTwoRows,
        present: Key('in-progress-list'),
        absent: Key('in-progress-empty'),
      ),
      'empty': (
        preview: inProgressTabEmpty,
        present: Key('in-progress-empty'),
        absent: Key('in-progress-list'),
      ),
      'error': (
        preview: inProgressTabFailed,
        present: Key('in-progress-error'),
        absent: Key('in-progress-list'),
      ),
    };

    subStates.forEach((
      String name,
      ({Widget Function() preview, Key present, Key absent}) spec,
    ) {
      testWidgets('the $name sub-state renders alone', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, spec.preview);

        expect(find.byKey(spec.present), findsOneWidget);
        expect(find.byKey(spec.absent), findsNothing);
        expect(find.byKey(const Key('in-progress-loading')), findsNothing);
      });
    });

    testWidgets('the two-row preview really renders TWO rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inProgressTabTwoRows);

      expect(find.byKey(const Key('active-request-card-ip-1')), findsOneWidget);
      expect(find.byKey(const Key('active-request-card-ip-2')), findsOneWidget);
      expect(find.text('Grocery run'), findsOneWidget);
    });

    // JEBV4-218 / Q-085: Track renders on every In-Progress card; the chat pill
    // stays gated on a Jeeber actually being engaged.
    testWidgets('the searching preview shows Track but NOT Open chat', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inProgressTabSearching);

      expect(
        find.byKey(const Key('active-track-order-ip-searching')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('active-open-chat-ip-searching')),
        findsNothing,
      );
    });

    testWidgets('the long-content preview shows BOTH action pills', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inProgressTabLongContent);

      expect(
        find.byKey(const Key('active-open-chat-ip-long')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('active-track-order-ip-long')),
        findsOneWidget,
      );
    });

    // The tab is a ListView child in production (`client_home_screen.dart` →
    // `_ReadyLayout`), i.e. it lays out against UNBOUNDED height, and
    // `_InProgressList` is a plain `Column` with no scroll of its own. The
    // previews reproduce that with a `SingleChildScrollView`; if that host is
    // ever dropped, a two-row list at large text scales becomes a vertical
    // RenderFlex overflow rather than a scroll.
    testWidgets('the previews host the tab against unbounded height', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inProgressTabTwoRows);

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(
        tester.getSize(find.byType(InProgressTab)).height,
        greaterThan(0),
      );
    });
  });
}
