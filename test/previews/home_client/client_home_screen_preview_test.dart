// Render tests for the ClientHomeScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's header — the customer's free-text line on a
/// request that never got a server order id. Declared here rather than imported
const String _kLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, '
    'then drop everything at the clinic on Independence Street';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · cold`, which cannot settle — see the
  testPreviewsRender(
    'ClientHomeScreen',
    const <String, Widget Function()>{
      'Pending · three requests': clientHomeScreenPending,
      'Replies · nine offers': clientHomeScreenReplies,
      'In Progress (dev seam)': clientHomeScreenInProgress,
      'Empty · first run': clientHomeScreenEmpty,
      'Empty · 320 pt floor': clientHomeScreenEmptyCompact,
      'Failed · cold load': clientHomeScreenFailed,
      'Longest content': clientHomeScreenLongContent,
      'Auto-advanced to Replies': clientHomeScreenAutoAdvancedToReplies,
    },
    expectedText: const <String, String>{
      // Only the Pending list carries ORD-23471.
      'Pending · three requests': 'ORD-23471',
      // The `+N` overflow badge exists on the Replies card alone.
      'Replies · nine offers': '+6',
      // The jeeber name only renders on an In-Progress order card.
      'In Progress (dev seam)': 'Kamal Hajj',
      'Empty · first run':
          'No pending requests — broadcast a new one to get offers.',
      // Same empty body as above, so this state is pinned by its own greeting.
      'Empty · 320 pt floor': 'Hello, Yasmine',
      'Failed · cold load': "Couldn't load your home",
      'Longest content': _kLongTitle,
      // The reply that proves the screen moved off Pending by itself.
      'Auto-advanced to Replies': 'ORD-98120',
    },
  );

  // The loading body is a centred `OmdsLoadingState`, i.e. an INDETERMINATE
  group('ClientHomeScreen previews · Loading · cold', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(clientHomeScreenLoading, locale));
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

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No chip row, no list, no error, no empty state.
      expect(find.text('Pending Requests'), findsNothing);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
      expect(find.text("Couldn't load your home"), findsNothing);
      expect(
        find.text('No pending requests — broadcast a new one to get offers.'),
        findsNothing,
      );
    });

    // DOCUMENTED DEFECT, not a desired behaviour. `_LoadingLayout` hard-codes
    testWidgets('DEFECT: the loading header forgets a name it already has', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Hello, Layla'), findsNothing);
    });
  });

  group('ClientHomeScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the ready surface keeps both on-hold chips and no third', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeScreenPending);

      expect(
        find.byKey(const Key('client-home-tab-pendingRequests')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('client-home-tab-replies')), findsOneWidget);
      // JEBV4-298: the In-Progress chip was relocated to the Delivery tab.
      expect(find.byKey(const Key('client-home-tab-inProgress')), findsNothing);
    });

    // DOCUMENTED DEFECT, not a desired behaviour. `initialTab` still accepts
    testWidgets('DEFECT: the In-Progress body renders with no chip selected', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeScreenInProgress);

      // The In-Progress list really is the body on screen.
      expect(find.byKey(const Key('active-request-card-ip-1')), findsOneWidget);
      // …yet neither visible chip is selected, so the tab bar — the only signal
      for (final Key key in const <Key>[
        Key('client-home-tab-pendingRequests'),
        Key('client-home-tab-replies'),
      ]) {
        expect(tester.widget<OmdsChip>(find.byKey(key)).isSelected, isFalse);
      }
    });

    testWidgets('the failed body replaces the chip row, not just the list', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeScreenFailed);

      expect(find.text('Retry'), findsOneWidget);
      // The greeting survives (the name comes from the session, not the read).
      expect(find.text('Hello, Layla'), findsOneWidget);
      // But there is no way left to reach the other list.
      expect(
        find.byKey(const Key('client-home-tab-pendingRequests')),
        findsNothing,
      );
      expect(find.byKey(const Key('client-home-tab-replies')), findsNothing);
    });

    testWidgets('the empty body is the illustrated first-request CTA', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, clientHomeScreenEmpty);

      expect(find.text('Create your first request'), findsOneWidget);
      // The one place on this screen where an a11y id changes with the data.
      expect(
        find.bySemanticsIdentifier('_request_empty_state_avatar'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'the auto-advance state lands on Replies, never on In-Progress',
      (WidgetTester tester) async {
        await pumpPreview(tester, clientHomeScreenAutoAdvancedToReplies);

        expect(find.byKey(const Key('replies-card-rep-auto')), findsOneWidget);
        expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
        expect(find.byKey(const Key('active-request-card-ip-1')), findsNothing);
      },
    );

    testWidgets('the longest-content greeting shows the FIRST name only', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeScreenLongContent);

      expect(find.text('Hello, Abdulrahman'), findsOneWidget);
      expect(find.textContaining('Al-Trabulsi'), findsNothing);
      // The header degrades to the free-text title when no order id exists.
      expect(find.text(_kLongTitle), findsOneWidget);
    });
  });
}
