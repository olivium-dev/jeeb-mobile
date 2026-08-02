// Render tests for the JeeberFeedTabView previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// Pinning a DISTINCT string per state matters more than usual here. All six
// previews are the same page under the same greeting and the same availability
// control, and three of them differ only in which of the three sub-tabs is
// active — so a suite that asserted only "something rendered" would still pass
// if every fixture collapsed onto the Requests tab.
//
// Each pinned string is therefore something only ITS state can produce: a
// client name that appears on exactly one card, the availability title that
// only an offline page shows, the money string only the pending list formats,
// the action label only an accepted card carries.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberFeedTabView',
    const <String, Widget Function()>{
      'Requests · live feed': jeeberFeedTabViewLiveFeed,
      'Requests · empty feed': jeeberFeedTabViewEmptyFeed,
      'Requests · longest content · 360 pt': jeeberFeedTabViewLongContent,
      'Offline · feed cleared, controls hidden': jeeberFeedTabViewOffline,
      'Pending · submitted offers': jeeberFeedTabViewPendingOffers,
      'Replies · accepted work': jeeberFeedTabViewReplies,
    },
    expectedText: const <String, String>{
      // The first card's client name — no other preview seeds this sender.
      'Requests · live feed': 'Sami Fawaz',
      'Requests · empty feed': 'No Requests yet',
      // The full (pre-ellipsis) name, which is what `Text.data` holds.
      'Requests · longest content · 360 pt':
          'Abdulrahman Al-Muhandis Al-Trabulsi',
      // The AVAILABILITY title, not the offline banner's own copy: the banner
      // string is printed twice on this page (banner + empty body), so it
      // could not be pinned with `findsOneWidget`.
      'Offline · feed cleared, controls hidden': "You're offline",
      'Pending · submitted offers': r'$12.50',
      'Replies · accepted work': 'Heading to drop off',
    },
  );

  group('JeeberFeedTabView preview specifics', () {
    // The three sub-tabs render three structurally different bodies. Text
    // assertions alone cannot tell "the Pending tab is showing" from "the
    // Requests tab happens to be empty", so pin the bodies by their keys.
    testWidgets('the live feed renders the request list, not an empty state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewLiveFeed);

      expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
      expect(find.byKey(JeeberFeedTabView.pendingListKey), findsNothing);
      expect(find.text('No Requests yet'), findsNothing);
      // Both seeded rows are in the tree — the second is the one JEBV4-284 and
      // the banner regression used to push out of a too-small inner viewport.
      expect(find.text('Layla Hamdan'), findsOneWidget);
    });

    testWidgets('the pending tab swaps in the submitted-offers list', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewPendingOffers);

      expect(find.byKey(JeeberFeedTabView.pendingListKey), findsOneWidget);
      expect(find.byKey(JeeberFeedTabView.listKey), findsNothing);
      // Its own back affordance, which the Requests tab does not have.
      expect(find.bySemanticsIdentifier('pending_offers_back'), findsOneWidget);
      // The open offer keeps Withdraw; the accepted one carries a badge and
      // must NOT offer to withdraw a bid that already became a delivery.
      expect(
        find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('pending_offer_1_withdraw_cta'),
        findsNothing,
      );
      // The feed's request row is seeded but belongs to another tab.
      expect(find.text('Sami Fawaz'), findsNothing);
    });

    // T-MOB-029 AC3, and the finding this preview exists for: going offline
    // does not merely add a banner, it removes every control on the page.
    testWidgets('offline hides the search bar and BOTH chip strips', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewOffline);

      // `JeeberFeedTabView.offlineBannerKey` is declared but never attached to
      // `_OfflineBanner`, so nothing can key off the banner today. Pinned as
      // `findsNothing` so that wiring it up is a deliberate change here rather
      // than a silent one.
      expect(find.byKey(JeeberFeedTabView.offlineBannerKey), findsNothing);
      expect(find.byKey(JeeberFeedTabView.searchBarKey), findsNothing);
      expect(find.byKey(JeeberFeedTabView.tabStripKey), findsNothing);
      expect(find.byKey(JeeberFeedTabView.tierStripKey), findsNothing);
      // The request is still in the cubit and is still not drawn.
      expect(find.byKey(JeeberFeedTabView.listKey), findsNothing);
      expect(find.text('Sami Fawaz'), findsNothing);
      // The offline copy is printed twice — banner AND empty body.
      expect(find.text('You are offline'), findsNWidgets(2));
      expect(
        find.text('Go online to see available requests.'),
        findsNWidgets(2),
      );
    });

    // The tier strip is a Requests-tab control only; the sub-tab strip is not.
    //
    // One test per preview, NOT three pumps in one: `initialTab` is read once,
    // in the State's field initializer, so re-pumping a second preview into the
    // same tree reuses `_JeeberFeedTabViewState` and keeps the FIRST preview's
    // active tab. Three pumps in one test therefore asserted the wrong page.
    const Map<String, Widget Function()> tabScoped =
        <String, Widget Function()>{
          'Requests · live feed': jeeberFeedTabViewLiveFeed,
          'Pending · submitted offers': jeeberFeedTabViewPendingOffers,
          'Replies · accepted work': jeeberFeedTabViewReplies,
        };

    for (final MapEntry<String, Widget Function()> entry in tabScoped.entries) {
      testWidgets('${entry.key} keeps the sub-tab strip', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, entry.value);

        expect(find.byKey(JeeberFeedTabView.tabStripKey), findsOneWidget);
        expect(
          find.byKey(JeeberFeedTabView.tierStripKey),
          entry.value == jeeberFeedTabViewLiveFeed
              ? findsOneWidget
              : findsNothing,
          reason: 'The tier chips are scoped to the Requests tab.',
        );
      });
    }

    // An accepted row is a delivery control, not an auction row: the
    // Ignore/Offer pair must be gone or a jeeber could "ignore" work they have
    // already committed to.
    testWidgets('an accepted row shows the advance pill, never Ignore/Offer', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewReplies);

      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_action_req-accepted'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_ignore_req-accepted'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_offer_req-accepted'),
        findsNothing,
      );
    });

    // The empty preview is doubling as the loading and error renderings: the
    // feed body reads `state.requests` and never `state.status`. If a spinner
    // or an error surface is ever added, this assertion is the one that should
    // fail and force the preview set to grow.
    testWidgets('the empty feed offers no retry and no diagnosis', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewEmptyFeed);

      expect(find.text('No Requests yet'), findsOneWidget);
      expect(find.text('All requests will show up here'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The chrome stays up, so a jeeber can still search or switch tabs.
      expect(find.byKey(JeeberFeedTabView.searchBarKey), findsOneWidget);
      expect(find.byKey(JeeberFeedTabView.tabStripKey), findsOneWidget);
    });

    // The two text contracts the longest-content state is built to stress.
    testWidgets('the longest row clips its name and its description', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewLongContent);

      final Text name = tester.widget<Text>(
        find.text('Abdulrahman Al-Muhandis Al-Trabulsi'),
      );
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);

      final Text summary = tester.widget<Text>(
        find.textContaining('2 shawarma + cola from Barbar'),
      );
      expect(summary.maxLines, 2);
      expect(summary.overflow, TextOverflow.ellipsis);
    });
  });
}
