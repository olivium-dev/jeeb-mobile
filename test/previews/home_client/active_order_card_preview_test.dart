import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/active_request_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ActiveOrderCard',
    const <String, Widget Function()>{
      'En route · chat + track': activeOrderCardEnRoute,
      'Searching · track only': activeOrderCardSearching,
      'Delivered · no actions': activeOrderCardDelivered,
      'Long title + long summary': activeOrderCardLongContent,
      'Untitled · unknown tier': activeOrderCardUntitledUnknownTier,
    },
    expectedText: const <String, String>{
      'En route · chat + track': 'Pharmacy run',
      'Searching · track only': 'Grocery run',
      'Delivered · no actions': 'Bakery order',
      'Long title + long summary':
          'Pharmacy pickup for Mrs. Haddad on Rue Sursock',
      'Untitled · unknown tier': 'Mar Mikhael, Beirut',
    },
  );

  group('ActiveOrderCard preview specifics', () {
    testWidgets('en-route opens BOTH gates (chat + track)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeOrderCardEnRoute);

      expect(
        find.byKey(const Key('active-open-chat-preview-en-route')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('active-track-order-preview-en-route')),
        findsOneWidget,
      );
    });

    testWidgets('searching keeps Track (Q-085) but hides Open chat (JM-025)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeOrderCardSearching);

      expect(
        find.byKey(const Key('active-open-chat-preview-searching')),
        findsNothing,
      );
      expect(find.text('Open chat'), findsNothing);
      expect(
        find.byKey(const Key('active-track-order-preview-searching')),
        findsOneWidget,
      );
      expect(find.text('Track my order'), findsOneWidget);
    });

    testWidgets('delivered closes both gates — no action row at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeOrderCardDelivered);

      expect(
        find.byKey(const Key('active-track-order-preview-delivered')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('active-open-chat-preview-delivered')),
        findsNothing,
      );
      expect(find.text('Track my order'), findsNothing);
      expect(find.text('Open chat'), findsNothing);
      expect(find.text('In Transit'), findsOneWidget);
    });

    testWidgets('long content stays single-line — it clips, it never wraps', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeOrderCardLongContent);

      final Text title = tester.widget<Text>(
        find.text('Pharmacy pickup for Mrs. Haddad on Rue Sursock'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);

      final Text summary = tester.widget<Text>(
        find.textContaining('1 kilo potato'),
      );
      expect(summary.maxLines, 1);
      expect(summary.overflow, TextOverflow.ellipsis);
    });

    testWidgets('untitled falls back to the "?" avatar and a blank tier badge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, activeOrderCardUntitledUnknownTier);

      expect(find.text('?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ClientHomeTierBadge),
          matching: find.text(''),
        ),
        findsOneWidget,
      );
      expect(find.text('Flash'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Express'), findsNothing);
    });
  });
}
