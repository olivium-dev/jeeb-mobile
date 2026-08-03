// Render tests for the JeeberFeedTabView previews.

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
      'Offline · feed cleared, controls hidden': "You're offline",
      'Pending · submitted offers': r'$12.50',
      'Replies · accepted work': 'Heading to drop off',
    },
  );

  group('JeeberFeedTabView preview specifics', () {
    // The three sub-tabs render three structurally different bodies. Text
    testWidgets('the live feed renders the request list, not an empty state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewLiveFeed);

      expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
      expect(find.byKey(JeeberFeedTabView.pendingListKey), findsNothing);
      expect(find.text('No Requests yet'), findsNothing);
      // Both seeded rows are in the tree — the second is the one JEBV4-284 and
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
    testWidgets('offline hides the search bar and BOTH chip strips', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedTabViewOffline);

      // `JeeberFeedTabView.offlineBannerKey` is declared but never attached to
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
