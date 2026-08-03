import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';

import '../preview_test_harness.dart';

/// The exact `itemsSummary` the long-content preview passes; pinned here so the
/// test fails loudly if the fixture is reworded.
const String _longSummary =
    '2 kg potatoes, 19 L water gallon, medium-roast coffee '
    'beans, 3 boxes of paracetamol, 1 pack of AA batteries';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'PendingCountdownCard',
    const <String, Widget Function()>{
      'Searching (no offers)': pendingCountdownCardSearching,
      'Searching · 320 pt phone': pendingCountdownCardSearchingNarrow,
      'New offers (3, unseen)': pendingCountdownCardNewOffers,
      'Seen offers (1, tonal)': pendingCountdownCardSeenOffers,
      'With created-age line': pendingCountdownCardCreatedAge,
      'Long content · no id · unknown tier': pendingCountdownCardLongContent,
    },
    expectedText: const <String, String>{
      'Searching (no offers)': 'Searching for Jeebers…',
      'Searching · 320 pt phone': 'ORD-31882',
      'New offers (3, unseen)': '3 offers',
      'Seen offers (1, tonal)': '1 offer',
      'With created-age line': 'Created 12 minutes ago',
      'Long content · no id · unknown tier': _longSummary,
    },
  );

  group('PendingCountdownCard preview specifics', () {
    testWidgets('no preview ever manufactures an expiry', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        pendingCountdownCardSearching,
        pendingCountdownCardSearchingNarrow,
        pendingCountdownCardNewOffers,
        pendingCountdownCardSeenOffers,
        pendingCountdownCardCreatedAge,
        pendingCountdownCardLongContent,
      ]) {
        await pumpPreview(tester, preview);

        expect(find.text('Expired'), findsNothing);
        expect(find.textContaining('left'), findsNothing);
      }
    });

    testWidgets('a row with no createdAt shows no age line at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingCountdownCardSearching);

      expect(find.byKey(const Key('pending-created-age')), findsNothing);
      expect(find.byKey(const Key('pending-server-status')), findsOneWidget);
    });

    testWidgets('the age line is a PAST fact, not a countdown', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingCountdownCardCreatedAge);

      expect(find.byKey(const Key('pending-created-age')), findsOneWidget);
      expect(find.text('Created 12 minutes ago'), findsOneWidget);
    });

    testWidgets('the offers chip REPLACES the searching line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingCountdownCardNewOffers);

      expect(find.byKey(const Key('pending-offers-badge')), findsOneWidget);
      expect(find.byKey(const Key('pending-server-status')), findsNothing);
      expect(find.text('Searching for Jeebers…'), findsNothing);
    });

    testWidgets('the searching line is localized, never left in English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        pendingCountdownCardSearching,
        locale: const Locale('ar'),
      );

      expect(find.text('البحث عن جِيبرين…'), findsOneWidget);
      expect(find.text('Searching for Jeebers…'), findsNothing);
    });

    testWidgets('a row with no displayId falls back to the request title', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingCountdownCardLongContent);

      expect(
        find.textContaining('Two kilos of Baalbek potatoes'),
        findsOneWidget,
      );
      // The unknown tier draws an empty badge rather than a placeholder label.
      expect(find.text('Express'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Flash'), findsNothing);
    });
  });
}
