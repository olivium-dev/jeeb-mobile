// Render tests for the ActiveOrderCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The specifics group below pins the two CTA gates the card owns
// (`_canTrack` / `_hasJeeber`), because every fixture passes a non-null
// `onOpenChat` exactly as `in_progress_tab.dart` does — so if a gate opens too
// wide, the preview silently starts showing a pill production would show too.

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
      // Untitled by design — the destination is the only text that identifies
      // this card, which is exactly the point of the state.
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

      // The fixture passes a non-null onOpenChat, as production always does:
      // suppression here is `_hasJeeber`, not a null callback.
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
      // The stage legend survives a card with no buttons: it is what overflows
      // on its own in the Arabic canvas rendering.
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
      // ClientRequestTier.unknown resolves to an empty label rather than a
      // fabricated tier name. Scoped to the badge because the empty title
      // renders a second `Text('')` right beside it — the header row really is
      // blank on both ends in this state.
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
