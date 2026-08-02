// Render tests for the HomeTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// HomeTab picks ONE of three screen-level layouts (loading / failed / ready) and
// the ready one then picks ONE of two sub-tabs, so five of the six previews
// would satisfy a render-only check while showing the wrong branch — an
// empty-state preview accidentally wired to an empty fixture looks identical to
// a list preview whose fixture stopped arriving. Every state therefore pins a
// string only IT can produce, and the group at the bottom pins the
// branch-exclusive contracts on top of that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/shell/home_tab_preview.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's card header. Declared here rather than
/// imported so a preview quietly rewired to a short title fails instead of
/// silently losing the one state that exercises the header's non-flexible tier
/// badge against an unbounded free-text title.
const String _kLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
    'drop everything at the clinic on Independence Street before it closes';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · cold`, which cannot settle — see the
  // dedicated group below.
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
      // rather than sitting on an empty Pending list.
      'Auto-advance to Replies': 'ORD-23480',
      // The screen-level connection error, distinct from the per-tab one.
      'Failed · cold load': "Couldn't load your home",
      'Longest content': _kLongTitle,
    },
  );

  // The loading branch centres an `OmdsLoadingState`, i.e. an INDETERMINATE
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes — builds in EN, builds in AR, renders its
  // OWN state — driven by fixed pumps instead.
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
      // all — it is not "the ready tab with a spinner in the list".
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pending Requests'), findsNothing);
      expect(find.text('Replies'), findsNothing);
      expect(find.text('Create your first request'), findsNothing);

      // CURRENT BEHAVIOUR, pinned because it is a finding rather than a
      // contract: the header says "Welcome back" even though
      // `greetingNameProvider` returned "Layla" and `ClientHomeCubit.load()`
      // emitted it into `state.greetingName` on the SAME frame.
      // `_LoadingLayout` hardcodes `name: null` while `_FailedLayout` (asserted
      // below) passes `state.greetingName` through, so the greeting visibly
      // flips from generic to personalized when the load lands. Whoever fixes
      // that should flip these two lines, not delete them.
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Hello, Layla'), findsNothing);
    });
  });

  group('HomeTab preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `MultiBlocProvider` element is UPDATED rather than replaced and
    // keeps the cubits the first preview created.
    testWidgets('the ready tab composes greeting + chip row + rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabPending);

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Replies'), findsOneWidget);
      // JEBV4-298 relocated the In-Progress surface to the Delivery tab, so
      // this tab bar is two chips — never three.
      expect(find.text('In Progress'), findsNothing);
      expect(find.text('ORD-23471'), findsOneWidget);
    });

    testWidgets('the header "+" is ENABLED, so it paints navy not gray', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, homeTabPending);

      // The precise condition that once regressed the create-request top plus
      // to a disabled-gray circle in every screen 13/14/15 capture: a null
      // `onPressed` repaints in the disabled color regardless of the configured
      // navy background. A preview built without HomeTab's own callback wiring
      // would show the defect rather than the design.
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
      // row is on screen even though HomeTab built the screen with
      // `initialTab: pendingRequests`.
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
      // per-sub-tab error, there is no chip row left to switch with.
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
    // one row in this tab whose RTL behaviour is NOT obvious from the source:
    // `_ClientHomeTabBar` builds a plain `Row` and relies entirely on the
    // ambient directionality. Measured at the preview's own 390 dp box.
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
