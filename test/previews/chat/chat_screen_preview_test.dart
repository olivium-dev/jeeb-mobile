// Render tests for the ChatScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen picks ONE of three bodies off `ChatState` — shimmer, error,
// empty, or the thread — and then stacks a variable header above it, so most of
// these previews would satisfy a render-only check while showing the wrong
// surface entirely. An "empty" preview whose fixture started throwing looks
// exactly like the failure state to a render-only assertion, and that
// confusion IS the b02 defect. Every state therefore pins a string only IT can
// produce, and the groups below pin the body-exclusive contracts on top.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's message. Declared here rather than imported so
/// a preview quietly rewired to a short fixture fails instead of silently
/// losing the one state that contests the thread with the header stack.
const String _kLongestMessage =
    'Please get 3 kilos of potatoes, two water gallons and a bag of coffee '
    'from Blend on Rue Gouraud, then stop at the pharmacy next door for '
    'paracetamol and cough syrup, and call me before you head to the clinic '
    'on Independence Street because the gate closes at seven.';

/// Kamal's note — the one string only the broadcasting feed can produce.
const String _kOfferNote = r'Hi i can bring you your order in 2 hours for  35$';

/// Pumps [preview] with framework errors intercepted rather than recorded.
///
/// `tester.takeException()` cannot be used to inspect them: once a second error
/// lands the binding collapses both into the string "Multiple exceptions (2)
/// were detected…", which says nothing about what they were. Taking them at
/// [FlutterError.onError] keeps each one, so the caller can decide which are
/// tolerable — and every error still has to be accounted for, because the
/// handler is restored before any assertion runs.
Future<List<FlutterErrorDetails>> _pumpCatchingErrors(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await pumpPreview(tester, preview, locale: locale);
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · cold history`, which cannot settle — see
  // the dedicated group below.
  testPreviewsRender(
    'ChatScreen',
    const <String, Widget Function()>{
      'Client · sending initial request': chatScreenClientSending,
      'Client · accepted thread': chatScreenClientAccepted,
      'Jeeber · accepted thread': chatScreenJeeberAccepted,
      'Jeeber · order picked': chatScreenJeeberOrderPicked,
      'Empty · waiting for offers': chatScreenEmptyBroadcasting,
      'History load failed': chatScreenHistoryFailed,
      'Longest content': chatScreenLongestContent,
      'Compact 320 pt · chrome stacked': chatScreenCompactChromeStack,
      'Jeeber removed · closed thread': chatScreenJeeberRemoved,
    },
    expectedText: const <String, String>{
      // The pre-offers frame is the customer's request with nothing under it.
      'Client · sending initial request':
          'I need 3 kilos of potatoes and water gallon and coffee from blend',
      // The third bubble exists only in the accepted 1:1 thread.
      'Client · accepted thread': 'Hello Kamal please i need the water to be '
          'tanourine',
      // The balance-deduction banner is the Jeeber leg's signature chrome.
      'Jeeber · accepted thread': r'Note $0.5 will be reduced from your Balance',
      // …and the pill replaces the dismiss × on exactly one of its states.
      'Jeeber · order picked': 'Order picked',
      // A read that came back with nothing, while offers are still open.
      'Empty · waiting for offers': 'No offers yet — sit tight.',
      // The failure body — NOT "No conversation yet".
      'History load failed': "Couldn't load this chat",
      'Longest content': _kLongestMessage,
      'Compact 320 pt · chrome stacked': 'I am at the gate, take your time.',
      'Jeeber removed · closed thread':
          'This request was assigned to another Jeeber.',
    },
  );

  // The broadcasting feed is the one designed state that cannot render
  // exception-free at a real phone width. `OfferCardBubble` lays Accept +
  // Decline out as a `Row(mainAxisSize: min)` of two intrinsically sized pills
  // with no `Wrap` and no `Flexible`; inside the chat the bubble is capped at
  // 250 pt, and the footer overflows by 97 px in EN at 390 pt (one exception
  // per card, so two per pump here). That is a PRE-EXISTING widget defect,
  // measured and documented in `offer_card_bubble.dart`'s own preview library —
  // this screen only makes it visible at the width the app ships.
  //
  // It is tolerated here rather than asserted: a test that pins a bug fails the
  // day someone fixes it. But it is tolerated NARROWLY — anything that is not
  // an overflow still fails, and widening the frame until the stripes disappear
  // would have been the other way to make this suite green, which is exactly
  // the reading these previews exist to prevent.
  group('ChatScreen previews · Client · broadcasting offers', () {
    Future<void> pumpBroadcasting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        chatScreenClientBroadcasting,
        locale: locale,
      );

      for (final FlutterErrorDetails details in caught) {
        expect(
          details.exception.toString(),
          contains('overflowed'),
          reason: 'only the documented footer overflow is tolerated here',
        );
      }
      // Nothing may reach the binding either — an error raised outside the
      // intercepted pump is not covered by the note above.
      expect(tester.takeException(), isNull);
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Client · broadcasting offers · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpBroadcasting(tester, locale: locale);
      });
    }

    testWidgets('Client · broadcasting offers renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpBroadcasting(tester);

      // Only the broadcasting feed carries an offer card, and only Kamal's
      // carries this note.
      expect(find.text(_kOfferNote), findsOneWidget);
      // Both offers arrived, and the footer that closes the list is the
      // accept-only-one note.
      expect(find.byKey(const Key('chat-offer-card-offer-kamal')), findsOneWidget);
      expect(find.byKey(const Key('chat-offer-card-offer-rana')), findsOneWidget);
    });
  });

  // The loading body is six `OmdsListItemShimmer` rows, i.e. a repeating
  // `AnimationController`. `pumpAndSettle` (which `pumpPreview` calls) never
  // returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes — builds in EN, builds in AR, renders its
  // OWN state — driven by fixed pumps instead. It has no text to pin, so its
  // state is pinned by the shimmer key plus the absence of every other body.
  group('ChatScreen previews · Loading · cold history', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(chatScreenLoading, locale));
      await tester.pump(); // the mount-time load() emit
      await tester.pump(const Duration(milliseconds: 16)); // one shimmer frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold history · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold history renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(
        find.byKey(const Key('chat-screen-history-shimmer')),
        findsOneWidget,
      );
      expect(find.byKey(ChatScreen.messageListKey), findsNothing);
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
      expect(find.byKey(ChatScreen.historyErrorKey), findsNothing);
      // …and no composer either. `_ChatBody` returns the shimmer BEFORE it
      // builds the Column, so the whole surface — composer and header chrome
      // included — is replaced for as long as the read takes: the user cannot
      // start typing while history loads, and a slow read looks like a chat
      // with no input. Pinned because it is a consequence of the early return,
      // not an intended state.
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('ChatScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `BlocProvider` element is UPDATED rather than replaced and keeps
    // the cubit the first preview created. The screen would still show the
    // first state under the second preview's name.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, chatScreenClientAccepted);

      expect(tester.getSize(find.byType(ChatScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatScreenCompactChromeStack);

      expect(
        tester.getSize(find.byType(ChatScreen)),
        const Size(320, 568),
      );
    });

    // b02, the whole reason both states are previewed: a 500 leaves `messages`
    // empty, so an emptiness-first body renders "No conversation yet" over a
    // thread that exists and a Jeeber already in transit.
    testWidgets('the failure body is an error with a retry, never the empty '
        'state', (WidgetTester tester) async {
      await pumpPreview(tester, chatScreenHistoryFailed);

      expect(find.byKey(ChatScreen.historyErrorKey), findsOneWidget);
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
      expect(find.text('No conversation yet'), findsNothing);
      // An error the user cannot act on is barely better than the empty state
      // it replaced.
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the empty preview is the EMPTY state, not the error one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatScreenEmptyBroadcasting);

      expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
      expect(find.byKey(ChatScreen.historyErrorKey), findsNothing);
      expect(find.text('Waiting for Jeebers…'), findsOneWidget);
    });

    testWidgets('the pre-offers frame carries no offer card and no accept-only-'
        'one footer', (WidgetTester tester) async {
      await pumpPreview(tester, chatScreenClientSending);

      expect(find.text(_kOfferNote), findsNothing);
      expect(find.text('Accept only one offer'), findsNothing);
      // The composer stays visible through `broadcasting` — the client can
      // still message while offers arrive.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the closed thread hides the composer — the one state that '
        'does', (WidgetTester tester) async {
      await pumpPreview(tester, chatScreenJeeberRemoved);

      expect(find.byKey(const Key('jeeber-removed-banner')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    // The bound is meant to be INERT at a normal text scale: a header slot that
    // is always scrolling is hiding content rather than budgeting it.
    testWidgets('the header slot does not scroll on the 390 pt phone', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatScreenLongestContent);

      final ScrollableState slot = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(chatHeaderSlotKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(slot.position.maxScrollExtent, 0);
    });

    testWidgets('the longest-content state stacks the pinned summary over the '
        'thread', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, chatScreenLongestContent);

      expect(
        find.bySemanticsIdentifier('order_chat_pinned_summary'),
        findsOneWidget,
      );
      // The accepted banner's client CTA — shown only because the fixture
      // seeded a tracking delivery id, so it is never a dead end.
      expect(find.text('Track my order'), findsOneWidget);
      expect(find.text(_kLongestMessage), findsOneWidget);
      handle.dispose();
    });
  });
}
