// Render tests for the DashboardTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This widget is unusually easy to test into a false pass. Two of its six
// states render the same register prompt, and three more render the same feed
// or the same greeting-plus-availability header — a render-only check would
// stay green with all six previews wired to one seed, which is exactly what
// happens if the `sl` registration in `_SeededDashboardTab.initState` ever
// moves back into the preview function body (last writer wins). So each state
// pins the greeting name only IT seeds, and the specifics group pins the
// branch-exclusive contracts — gate destination, feed-vs-prompt, the
// active-deliveries disclosure over a NON-empty feed — on top of that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/previews/shell/dashboard_tab_preview.dart';

import '../preview_test_harness.dart';

/// The feed fixture's sender (`DevJeeberFeedFixtures`). Present exactly when the
/// tab resolved the FEED destination and the feed is non-empty.
const String _kFeedRow = 'Sami Fawaz';

/// The register prompt's CTA — actionable, and reachable from two states.
const String _kRegisterCta = 'Register now';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview registers a full set of fakes into the process-global `sl`.
  // Clearing between tests keeps a failure honest: a preview that stopped
  // registering something would otherwise pass on its neighbour's leftovers.
  tearDown(() => sl.reset());

  testPreviewsRender(
    'DashboardTab',
    const <String, Widget Function()>{
      'KYC none · register prompt': dashboardTabRegisterPrompt,
      'KYC pending · feed reachable': dashboardTabPendingKycFeed,
      'KYC approved · quiet feed': dashboardTabApprovedQuietFeed,
      'Won delivery · banner over feed': dashboardTabWonDeliveryBanner,
      'Availability load failed': dashboardTabAvailabilityLoadError,
      'KYC rejected · pre-redirect frame': dashboardTabRejectedFrame,
    },
    expectedText: const <String, String>{
      // No profile repository is seeded here, so this is the tab's own
      // hardcoded `profileName: 'Kamal'` — no other state can produce it.
      'KYC none · register prompt': 'Hello, Kamal',
      // The remaining greetings come from each state's seeded getMe name.
      'KYC pending · feed reachable': 'Hello, Layla',
      'KYC approved · quiet feed': 'Hello, Nadia',
      'Won delivery · banner over feed': 'Hello, Zeina',
      // The only state with no greeting at all: the load error replaces the
      // whole body.
      'Availability load failed': "Couldn't load your availability.",
      'KYC rejected · pre-redirect frame': 'Hello, Nour',
    },
  );

  group('DashboardTab preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT re-seed it — `previewCanvas` produces the same widget types, so
    // `_SeededDashboardTab`'s State is UPDATED rather than replaced, `initState`
    // never re-runs, and the second preview would still show the first's fakes.

    testWidgets('none resolves the register prompt, not the feed', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, dashboardTabRegisterPrompt);

      expect(find.bySemanticsIdentifier('delivery_register_prompt'), findsOne);
      expect(find.bySemanticsIdentifier('jeeber_feed_root'), findsNothing);
      expect(find.text(_kRegisterCta), findsOneWidget);
      expect(find.text(_kFeedRow), findsNothing);
      handle.dispose();
    });

    testWidgets('pending BROWSES the feed (D38 / W2-closer)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, dashboardTabPendingKycFeed);

      // The fail-without anchor: the old `!isApproved` collapse sent a pending
      // jeeber to the register prompt, which made `offer_kyc_gate` unreachable.
      expect(find.bySemanticsIdentifier('jeeber_feed_root'), findsOne);
      expect(find.text('Register as a delivery man'), findsNothing);
      expect(find.text(_kFeedRow), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'a won delivery surfaces ABOVE a still-non-empty feed '
      '(PUSH-UI-REACTION)',
      (WidgetTester tester) async {
        await pumpPreview(tester, dashboardTabWonDeliveryBanner);

        // Both halves matter: the banner used to be passed only to the
        // no-requests branch, so it rendered nowhere until the feed emptied.
        expect(find.text('Your active deliveries'), findsOneWidget);
        expect(find.text('View all (1)'), findsOneWidget);
        expect(find.text(_kFeedRow), findsOneWidget);
      },
    );

    testWidgets('the quiet feed is the empty view, not an empty feed list', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dashboardTabApprovedQuietFeed);

      expect(find.text('No requests right now'), findsOneWidget);
      expect(find.text(_kFeedRow), findsNothing);
    });

    testWidgets('an availability failure replaces the whole tab body', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dashboardTabAvailabilityLoadError);

      // The feed and the greeting loaded fine; neither survives the error
      // branch. This is the state, not a preview seeding accident — the same
      // seed feeds the feed fixture as `pending · feed reachable`.
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Hello,'), findsNothing);
      expect(find.text(_kFeedRow), findsNothing);
    });

    testWidgets('a REJECTED jeeber is shown an actionable register CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dashboardTabRejectedFrame);

      // Recorded, not endorsed: `rejected` is terminal (D52/D87), and in the app
      // this frame is replaced by the `kyc-rejected` redirect. With no router
      // the frame persists — which is what makes the CTA visible at all.
      expect(find.text(_kRegisterCta), findsOneWidget);
      expect(find.text('Hello, Nour'), findsOneWidget);
    });
  });
}

