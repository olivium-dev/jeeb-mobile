// Render tests for the ChatTab previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/shell/tabs/chat_tab.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);
  setUp(chatTabPreviewTransportLog.clear);

  // Every preview except `Loading · request in flight`, which cannot settle —
  testPreviewsRender(
    'ChatTab',
    const <String, Widget Function()>{
      'Three conversations': chatTabThreeConversations,
      'Empty · gateway returned none': chatTabEmpty,
      'Gateway 503 · failure block': chatTabGatewayError,
      'Real row shape · 3 of 3 survive': chatTabRealRowShape,
      'Long title + raw status': chatTabLongContent,
      'Partial load · 1 row unroutable': chatTabPartialLoad,
      'Refresh failed over rows': chatTabRefreshFailed,
    },
    expectedText: const <String, String>{
      // The first row's title; the other two rows are asserted separately, so
      'Three conversations': 'Pharmacy run',
      'Empty · gateway returned none': 'No conversations yet',
      // The whole point of the pair: the 503 no longer reads as empty.
      'Gateway 503 · failure block':
          'Jeeb is briefly unavailable. Try again in a moment.',
      // Every row in that preview is title-less; the status label is what
      // distinguishes them, and none of them prints a wire token.
      'Real row shape · 3 of 3 survive': 'Picked up',
      'Long title + raw status':
          'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
      'Partial load · 1 row unroutable': "Some messages couldn't load.",
      'Refresh failed over rows': 'Pharmacy run',
    },
  );

  // The loading state is a never-answering request, so it can never settle.
  group('ChatTab previews · Loading · request in flight', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(chatTabLoading, locale));
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · request in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · request in flight renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      // The loading rung is up...
      expect(find.bySemanticsIdentifier('chat_tab_loading'), findsOneWidget);
      // ...neither of the other two sub-states is...
      expect(find.bySemanticsIdentifier('chat_tab_empty'), findsNothing);
      expect(find.bySemanticsIdentifier('chat_tab_error'), findsNothing);
      // ...and the request really did go out and really is unanswered. Without
      expect(chatTabPreviewTransportLog, <String>[
        'GET /v1/requests',
        '→ (never answers)',
      ]);
    });
  });

  group('ChatTab preview specifics', () {
    testWidgets('the list preview renders all three rows, separated', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabThreeConversations);

      expect(find.text('Pharmacy run'), findsOneWidget);
      expect(find.text('Grocery run'), findsOneWidget);
      // Third row: sent without a `title`, so the tab substitutes the
      // LOCALIZED fallback — never the old hard-coded 'Delivery'.
      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('Delivery'), findsNothing);
      expect(find.byType(Divider), findsNWidgets(2));
      // Only the FIRST row carries the shell's active-delivery key.
      expect(find.byKey(ChatTab.activeDeliveryCardKey), findsOneWidget);
    });

    // SHELL-03: the wire token never reaches the subtitle in either locale.
    testWidgets('status tokens are mapped, and the title fallback localizes', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        chatTabThreeConversations,
        locale: const Locale('ar'),
      );

      expect(find.text('InTransit'), findsNothing);
      expect(find.text('Accepted'), findsNothing);
      expect(find.text('AtDoor'), findsNothing);
      expect(find.text('Delivery'), findsNothing);
    });

    testWidgets('an unrecognised status draws NO subtitle at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabLongContent);

      expect(find.text('awaiting_jeeber_acceptance'), findsNothing);
    });

    // The pair below is the whole reason this file exists: same screen, two
    testWidgets('a 503 renders the FAILURE rung with a retry, never empty', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabGatewayError);

      expect(find.bySemanticsIdentifier('chat_tab_error'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_empty'), findsNothing);
      expect(find.bySemanticsIdentifier('chat_tab_retry_cta'), findsOneWidget);
      // The gateway answered 503 while holding a row the user never sees, and
      expect(chatTabPreviewTransportLog, contains('→ 503 · 1 items'));
    });

    testWidgets('the empty preview is a real 200 with zero rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabEmpty);

      expect(find.bySemanticsIdentifier('chat_tab_empty'), findsOneWidget);
      expect(chatTabPreviewTransportLog, contains('→ 200 · 0 items'));
    });

    // SHELL-02: three active requests in, three rows out. Two of them carry no
    // usable `conversationId` and route on their request id instead.
    testWidgets('rows without a conversationId still render and route', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabRealRowShape);

      expect(chatTabPreviewTransportLog, contains('→ 200 · 3 items'));
      expect(find.byKey(ChatTab.activeDeliveryCardKey), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.bySemanticsIdentifier('chat_tab_row_req-9001'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_row_req-9002'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_row_req-9003'), findsOneWidget);
    });

    testWidgets('the partial-load preview keeps the routable row and says so', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabPartialLoad);

      expect(
        find.bySemanticsIdentifier('chat_tab_partial_note'),
        findsOneWidget,
      );
      expect(find.text('Pharmacy run'), findsOneWidget);
    });

    testWidgets('the refresh-failure preview keeps its rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabRefreshFailed);

      expect(
        find.bySemanticsIdentifier('chat_tab_refresh_error'),
        findsOneWidget,
      );
      expect(find.text('Pharmacy run'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_error'), findsNothing);
    });
  });
}
