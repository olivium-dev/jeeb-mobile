// Render tests for the ChatScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's message. Declared here rather than imported so
/// a preview quietly rewired to a short fixture fails instead of silently
const String _kLongestMessage =
    'Please get 3 kilos of potatoes, two water gallons and a bag of coffee '
    'from Blend on Rue Gouraud, then stop at the pharmacy next door for '
    'paracetamol and cough syrup, and call me before you head to the clinic '
    'on Independence Street because the gate closes at seven.';

/// Kamal's note — the one string only the broadcasting feed can produce.
const String _kOfferNote = r'Hi i can bring you your order in 2 hours for  35$';

/// Pumps [preview] with framework errors intercepted rather than recorded.
/// `tester.takeException()` cannot be used to inspect them: once a second error
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
      expect(find.text(_kOfferNote), findsOneWidget);
      // Both offers arrived, and the footer that closes the list is the
      expect(find.byKey(const Key('chat-offer-card-offer-kamal')), findsOneWidget);
      expect(find.byKey(const Key('chat-offer-card-offer-rana')), findsOneWidget);
    });
  });

  // The loading body is six `OmdsListItemShimmer` rows, i.e. a repeating
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
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('ChatScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
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
    testWidgets('the failure body is an error with a retry, never the empty '
        'state', (WidgetTester tester) async {
      await pumpPreview(tester, chatScreenHistoryFailed);

      expect(find.byKey(ChatScreen.historyErrorKey), findsOneWidget);
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
      expect(find.text('No conversation yet'), findsNothing);
      // An error the user cannot act on is barely better than the empty state
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
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the closed thread hides the composer — the one state that '
        'does', (WidgetTester tester) async {
      await pumpPreview(tester, chatScreenJeeberRemoved);

      expect(find.byKey(const Key('jeeber-removed-banner')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    // The bound is meant to be INERT at a normal text scale: a header slot that
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
      expect(find.text('Track my order'), findsOneWidget);
      expect(find.text(_kLongestMessage), findsOneWidget);
      handle.dispose();
    });
  });
}
