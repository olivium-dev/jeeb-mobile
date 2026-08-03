// Render tests for the DashboardTab previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';

import '../preview_test_harness.dart';

/// The feed fixture's sender (`DevJeeberFeedFixtures`). Present exactly when the
/// tab resolved the FEED destination and the feed is non-empty.
const String _kFeedRow = 'Sami Fawaz';

/// The register prompt's CTA — actionable, and reachable from two states.
const String _kRegisterCta = 'Register now';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview registers a full set of fakes into the process-global `sl`.
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
      'KYC none · register prompt': 'Hello, Kamal',
      // The remaining greetings come from each state's seeded getMe name.
      'KYC pending · feed reachable': 'Hello, Layla',
      'KYC approved · quiet feed': 'Hello, Nadia',
      'Won delivery · banner over feed': 'Hello, Zeina',
      // The only state with no greeting at all: the load error replaces the
      'Availability load failed': "Couldn't load your availability.",
      'KYC rejected · pre-redirect frame': 'Hello, Nour',
    },
  );

  group('DashboardTab preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester

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
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Hello,'), findsNothing);
      expect(find.text(_kFeedRow), findsNothing);
    });

    testWidgets('a REJECTED jeeber is shown an actionable register CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dashboardTabRejectedFrame);

      // Recorded, not endorsed: `rejected` is terminal (D52/D87), and in the app
      expect(find.text(_kRegisterCta), findsOneWidget);
      expect(find.text('Hello, Nour'), findsOneWidget);
    });
  });
}
