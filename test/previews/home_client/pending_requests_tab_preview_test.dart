// Render tests for the PendingRequestsTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The tab picks ONE of four branches off ClientHomeState, and four of the five
// settleable previews would satisfy a render-only check while showing the wrong
// branch — an empty-state preview accidentally wired to an empty fixture list
// looks identical to a list preview whose fixture stopped arriving. So every
// state pins a string only IT can produce, and the group below pins the
// branch-exclusive contracts on top of that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';
import 'package:jeeb_mobile/previews/home_client/pending_requests_tab_preview.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's header. Declared here so a preview quietly
/// rewired to a short title fails instead of silently losing the one state
/// that exercises the header's non-flexible tier badge.
const String _kLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, '
    'then drop everything at the clinic on Independence Street';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · cold`, which cannot settle — see the
  // dedicated group below.
  testPreviewsRender(
    'PendingRequestsTab',
    const <String, Widget Function()>{
      'Searching · two requests': pendingRequestsTabSearching,
      'Offers arrived · 3 unseen': pendingRequestsTabOffers,
      'Longest content · no order id': pendingRequestsTabLongContent,
      'Empty · no pending requests': pendingRequestsTabEmpty,
      'Failed · cold load': pendingRequestsTabFailed,
    },
    expectedText: const <String, String>{
      'Searching · two requests': 'ORD-23470',
      'Offers arrived · 3 unseen': '3 offers',
      'Longest content · no order id': _kLongTitle,
      'Empty · no pending requests':
          'No pending requests — broadcast a new one to get offers.',
      'Failed · cold load': "Couldn't load your home",
    },
  );

  // The loading branch is a centred `OmdsLoadingState`, i.e. an INDETERMINATE
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes — builds in EN, builds in AR, renders its
  // OWN state — driven by fixed pumps instead. It has no text to pin, so its
  // own state is pinned by the branch key plus the absence of every other
  // branch.
  group('PendingRequestsTab previews · Loading · cold', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(pendingRequestsTabLoading, locale));
      await tester.pump(); // the seeded load() emit
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.byKey(const Key('pending-loading')), findsOneWidget);
      expect(find.byKey(const Key('pending-error')), findsNothing);
      expect(find.byKey(const Key('pending-empty')), findsNothing);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
    });
  });

  group('PendingRequestsTab preview specifics', () {
    testWidgets('every pending row carries its own server-derived status', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestsTabSearching);

      expect(find.byType(PendingCountdownCard), findsNWidgets(2));
      expect(find.text('Searching for Jeebers…'), findsNWidgets(2));
      // The gateway list carries no expiry, so nothing may manufacture one.
      expect(find.text('Expired'), findsNothing);
    });

    testWidgets('the offers badge REPLACES the searching line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestsTabOffers);

      expect(find.byKey(const Key('pending-offers-badge')), findsOneWidget);
      expect(find.byKey(const Key('pending-server-status')), findsNothing);
      expect(find.text('Searching for Jeebers…'), findsNothing);
    });

    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `BlocProvider` element is UPDATED rather than replaced and keeps
    // the cubit the first preview created. The tab would still show the first
    // state under the second preview's name.
    testWidgets('a real createdAt produces a past-fact age line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestsTabLongContent);

      expect(find.text('Created 12 minutes ago'), findsOneWidget);
    });

    testWidgets('rows without a createdAt show no age line at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestsTabSearching);

      // A missing timestamp is UNKNOWN, never a fabricated "just now".
      expect(find.byKey(const Key('pending-created-age')), findsNothing);
    });

    testWidgets('the empty branch never renders a card or a spinner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestsTabEmpty);

      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      expect(find.byType(PendingCountdownCard), findsNothing);
      expect(find.byKey(const Key('pending-loading')), findsNothing);
    });

    testWidgets('the failed branch offers a retry, not an empty state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestsTabFailed);

      expect(find.byKey(const Key('pending-error')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('pending-empty')), findsNothing);
    });
  });
}
