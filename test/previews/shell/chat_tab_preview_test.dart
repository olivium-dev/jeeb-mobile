// Render tests for the ChatTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Two things make this suite different from the template:
//
//   1. TWO OF THE STATES ARE PIXEL-IDENTICAL BY DESIGN. `ChatTab` swallows its
//      `DioException`, so a 503 renders the same `OmdsEmptyState` as an empty
//      inbox — no error copy, no retry. `expectedText` therefore cannot tell
//      those two previews apart, and the dedicated tests below pin them at the
//      transport instead (`chatTabPreviewTransportLog`), which is the only place
//      they differ. That indistinguishability is the finding, not a gap.
//
//   2. ONE PREVIEW PER TEST, ALWAYS. Every preview here is the same widget tree
//      (`_GetItDioScope` → `ChatTab`) differing only in the canned transport, so
//      pumping a second preview into the same tester REUSES the first tab's
//      element — and `ChatTab` reads GetIt in `initState`, which would not run
//      again. Two states asserted in one test would silently both be the first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/shell/tabs/chat_tab.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);
  setUp(chatTabPreviewTransportLog.clear);

  // Every preview except `Loading · request in flight`, which cannot settle —
  // see the dedicated group below.
  testPreviewsRender(
    'ChatTab',
    const <String, Widget Function()>{
      'Three conversations': chatTabThreeConversations,
      'Empty · gateway returned none': chatTabEmpty,
      'Gateway 503 · reads as empty': chatTabGatewayError,
      'Real row shape · 1 of 3 survives': chatTabRealRowShape,
      'Long title + raw status': chatTabLongContent,
    },
    expectedText: const <String, String>{
      // The first row's title; the other two rows are asserted separately, so
      // this string cannot stand in for the list.
      'Three conversations': 'Pharmacy run',
      'Empty · gateway returned none': 'No conversations yet.',
      // Deliberately the SAME string as the empty state — see the header note.
      // The transport-level assertions below are what actually separate them.
      'Gateway 503 · reads as empty': 'No conversations yet.',
      // The hardcoded English fallback for a row the gateway sent without a
      // title — the only row of three that was not dropped.
      'Real row shape · 1 of 3 survives': 'Delivery',
      'Long title + raw status':
          'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
    },
  );

  // The loading state is an indeterminate `CircularProgressIndicator`
  // (`OmdsLoadingState`) held open by an adapter that never answers.
  // `pumpAndSettle` — which `pumpPreview` calls — never returns while one is on
  // screen, so this preview gets the same three assertions the shared suite
  // makes (builds in EN, builds in AR, renders its OWN state) driven by fixed
  // pumps instead.
  group('ChatTab previews · Loading · request in flight', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(chatTabLoading, locale));
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
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

      // The spinner is up...
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...neither of the other two sub-states is...
      expect(find.byKey(const Key('chat-tab-empty')), findsNothing);
      expect(find.byType(ListView), findsNothing);
      // ...and the request really did go out and really is unanswered. Without
      // this the preview would be indistinguishable from one whose transport was
      // never reached at all.
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
      // Third row: sent without a `title`, so the tab substitutes its literal.
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      // Only the FIRST row carries the shell's active-delivery key.
      expect(find.byKey(ChatTab.activeDeliveryCardKey), findsOneWidget);
    });

    // The status line and the missing-title fallback are printed verbatim from
    // the wire. Asserting them under `ar` is the point: an Arabic-first product
    // renders `InTransit` and `Delivery` to an Arabic reader.
    testWidgets('status tokens and the title fallback stay English in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        chatTabThreeConversations,
        locale: const Locale('ar'),
      );

      expect(find.text('InTransit'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('AtDoor'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('the long-content preview shows the raw status token', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabLongContent);

      expect(find.text('awaiting_jeeber_acceptance'), findsOneWidget);
    });

    // The pair below is the whole reason this file exists: same screen, two
    // different transport outcomes, and nothing on screen says which.
    testWidgets('a swallowed 503 renders the EMPTY state, not an error', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabGatewayError);

      expect(find.byKey(const Key('chat-tab-empty')), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      // The gateway answered 503 while holding a row the user never sees, and
      // the tab offers no retry: no button in the empty state, no
      // `RefreshIndicator` anywhere.
      expect(chatTabPreviewTransportLog, contains('→ 503 · 1 items'));
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
    });

    testWidgets('the empty preview is a real 200 with zero rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabEmpty);

      expect(find.byKey(const Key('chat-tab-empty')), findsOneWidget);
      expect(chatTabPreviewTransportLog, contains('→ 200 · 0 items'));
    });

    // Three active requests in, one row out — the two rows whose
    // `conversationId` the gateway omitted (or sent empty) are dropped with no
    // counter, no placeholder and no diagnostic.
    testWidgets('rows without a conversationId are dropped silently', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatTabRealRowShape);

      expect(chatTabPreviewTransportLog, contains('→ 200 · 3 items'));
      expect(find.byKey(ChatTab.activeDeliveryCardKey), findsOneWidget);
      // One row means no separators at all.
      expect(find.byType(Divider), findsNothing);
      // The survivor is the `InTransit` row; the dropped rows' statuses are
      // nowhere on screen.
      expect(find.text('InTransit'), findsOneWidget);
      expect(find.text('Ordered'), findsNothing);
      expect(find.text('PickedUp'), findsNothing);
    });
  });
}
