// Render tests for the HomeTab previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's card header. Declared here rather than
/// imported so a preview quietly rewired to a short title fails instead of
const String _kLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
    'drop everything at the clinic on Independence Street before it closes';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · cold`, which cannot settle — see the
  testPreviewsRender(
    'HomeTab',
    const <String, Widget Function()>{
      'Pending · two requests': homeTabPending,
      'Empty · new account': homeTabEmpty,
      'Auto-advance to Replies': homeTabAdvancesToReplies,
      'Failed · cold load': homeTabFailed,
      'Longest content': homeTabLongContent,
    },
    expectedText: const <String, String>{
      // A pending card header — only the populated pending list renders one.
      'Pending · two requests': 'ORD-23470',
      // The first-request CTA, which exists only under the empty illustration.
      'Empty · new account': 'Create your first request',
      // A replies-only order id: proves the tab actually MOVED to Replies
      'Auto-advance to Replies': 'ORD-23480',
      // The screen-level connection error, distinct from the per-tab one.
      'Failed · cold load': "Couldn't load your home",
      'Longest content': _kLongTitle,
    },
  );

  // The loading branch centres an `OmdsLoadingState`, i.e. an INDETERMINATE
  group('HomeTab previews · Loading · cold', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(homeTabLoading, locale));
      await tester.pump(); // the post-frame load() emit
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

      // The screen-level loading layout REPLACES the ready layout, chip row and
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pending Requests'), findsNothing);
      expect(find.text('Replies'), findsNothing);
      expect(find.text('Create your first request'), findsNothing);

      // CURRENT BEHAVIOUR, pinned because it is a finding rather than a
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Hello, Layla'), findsNothing);
    });
  });

  group('HomeTab preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the ready tab composes greeting + chip row + rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabPending);

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Replies'), findsOneWidget);
      // JEBV4-298 relocated the In-Progress surface to the Delivery tab, so
      expect(find.text('In Progress'), findsNothing);
      expect(find.text('ORD-23471'), findsOneWidget);
    });

    testWidgets('the header "+" is ENABLED, so it paints navy not gray', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabPending);

      // The precise condition that once regressed the create-request top plus
      final IconButton plus = tester.widget<IconButton>(
        find.byKey(const Key('client-home-greeting-add')),
      );
      expect(plus.onPressed, isNotNull);
    });

    testWidgets('the empty tab keeps the chip row above the illustration', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabEmpty);

      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      expect(find.text('What do you need?'), findsOneWidget);
      // Empty is still the READY layout: the user can still switch tabs.
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Replies'), findsOneWidget);
      // No name on file → the generic greeting, not a bare "?" next to a name.
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('an empty Pending list advances the selection to Replies', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabAdvancesToReplies);

      // The one-shot "land where the content is" affordance fired: the Replies
      expect(find.byKey(const Key('replies-card-ord-23480')), findsOneWidget);
      expect(find.byKey(const Key('pending-empty')), findsNothing);
    });

    testWidgets('the failed tab drops the chip row and offers a retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabFailed);

      expect(find.text("Couldn't load your home"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The screen-level failure replaces the whole ready layout — unlike the
      expect(find.text('Pending Requests'), findsNothing);
      expect(find.text('Replies'), findsNothing);
      // Unlike `_LoadingLayout`, this one carries the known name through.
      expect(find.text('Hello, Layla'), findsOneWidget);
    });

    testWidgets('the greeting shows the FIRST name only and ellipsizes', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabLongContent);

      expect(find.text('Hello, Abdulrahman'), findsOneWidget);
      expect(find.textContaining('Al-Trabulsi'), findsNothing);
    });

    // The chip row mirrors correctly, which is worth pinning because it is the
    testWidgets('the chip row and header mirror under AR RTL', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, homeTabPending, locale: const Locale('ar'));

      final double pendingChipX = tester
          .getTopLeft(find.byKey(const Key('client-home-tab-pendingRequests')))
          .dx;
      final double repliesChipX = tester
          .getTopLeft(find.byKey(const Key('client-home-tab-replies')))
          .dx;
      // First chip sits to the TRAILING (right) side under RTL.
      expect(pendingChipX, greaterThan(repliesChipX));

      // The header swaps too: avatar trailing, create-request "+" leading.
      final double avatarX = tester
          .getTopLeft(find.byKey(const Key('client-home-greeting-avatar')))
          .dx;
      final double plusX = tester
          .getTopLeft(find.byKey(const Key('client-home-greeting-add')))
          .dx;
      expect(avatarX, greaterThan(plusX));
    });
  });
}
