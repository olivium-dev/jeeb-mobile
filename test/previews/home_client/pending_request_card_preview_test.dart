// Render tests for the PendingRequestCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every `expectedText` below is unique to its
// state: a suite that only asserted "something rendered" would still pass if
// all five previews showed the same request.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/pending_request_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'PendingRequestCard',
    const <String, Widget Function()>{
      'Searching': pendingRequestCardSearching,
      'No display id (title fallback)': pendingRequestCardTitleFallback,
      'Empty summary line': pendingRequestCardEmptySummary,
      'Unknown tier badge': pendingRequestCardUnknownTier,
      'Long content overflow': pendingRequestCardLongContent,
    },
    expectedText: const <String, String>{
      'Searching': 'ORD-23470',
      'No display id (title fallback)': 'Pharmacy run for Mom',
      'Empty summary line': 'ORD-23471',
      'Unknown tier badge': 'ORD-23472',
      'Long content overflow':
          'ORD-23473 Beirut Souks pickup, Achrafieh drop-off',
    },
  );

  group('PendingRequestCard preview specifics', () {
    testWidgets('happy path shows the destination as the summary line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestCardSearching);

      expect(find.text('ORD-23470'), findsOneWidget);
      expect(find.text('Achrafieh'), findsOneWidget);
      expect(find.text('Express'), findsOneWidget);
    });

    testWidgets('G1: the summary never echoes the header (title fallback)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestCardTitleFallback);

      // Header falls back to `title`; because `itemsSummary` is the same
      // string, `summaryLine` must drop to the destination rather than print
      // the sentence twice.
      expect(find.text('Pharmacy run for Mom'), findsOneWidget);
      expect(find.text('Achrafieh, Beirut'), findsOneWidget);
    });

    testWidgets('an empty summaryLine renders a BLANK line, not a fallback', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestCardEmptySummary);

      // The tier badge proves the empty Text below is the summary, not the
      // badge. `PendingCountdownCard` substitutes the localized searching
      // label here; this card does not — that divergence is the point of the
      // preview.
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text(''), findsOneWidget);
      expect(find.text('Searching for Jeebers…'), findsNothing);
    });

    testWidgets('an unknown tier renders an EMPTY badge, not a neutral chip', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestCardUnknownTier);

      expect(find.text('ORD-23472'), findsOneWidget);
      expect(find.text('Hamra'), findsOneWidget);
      expect(find.text('Flash'), findsNothing);
      expect(find.text('Express'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      // The badge is still in the tree — it just has nothing to say.
      expect(find.text(''), findsOneWidget);
    });

    testWidgets('long content lays out without an overflow exception', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingRequestCardLongContent);

      expect(tester.takeException(), isNull);
      expect(find.text('Flash'), findsOneWidget);
      expect(
        find.textContaining('1 kilo potato, water gallon'),
        findsOneWidget,
      );
    });
  });
}
