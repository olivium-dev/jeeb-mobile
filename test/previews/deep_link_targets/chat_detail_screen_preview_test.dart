// Render tests for the ChatDetailScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's message. Declared here rather than imported so
/// a preview quietly rewired to a short fixture fails instead of silently losing
const String _kLongestMessage =
    'Please get 3 kilos of potatoes, two water gallons and a bag of coffee '
    'from Blend on Rue Gouraud, then stop at the pharmacy next door for '
    'paracetamol and cough syrup, and call me before you head to the clinic '
    'on Independence Street because the gate closes at seven.';

/// The synthetic account handle the unnamed-counterpart state feeds the header.
/// It must never be rendered — that is the whole state.
const String _kSyntheticHandle = 'jeeb-e1a35ea8a520';

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

  // Every preview except the two with their own group below: `Broadcasting`
  testPreviewsRender(
    'ChatDetailScreen',
    const <String, Widget Function()>{
      'Compose · no offers yet': chatDetailScreenCompose,
      'Accepted · pinned summary': chatDetailScreenAccepted,
      'Accepted · unnamed counterpart': chatDetailScreenAcceptedUnnamed,
      'Fresh compose · no conversation yet': chatDetailScreenFreshCompose,
      'Empty · accepted thread': chatDetailScreenEmptyAccepted,
      'History load failed': chatDetailScreenHistoryFailed,
      'Longest content': chatDetailScreenLongestContent,
    },
    expectedText: const <String, String>{
      // The header is the short order reference derived from the route param —
      'Compose · no offers yet': '#NDING1',
      // The third bubble exists only in the accepted 1:1 thread.
      'Accepted · pinned summary':
          'Hello Kamal please i need the water to be tanourine',
      // Same thread, but the counterpart's only name on file is a synthetic
      'Accepted · unnamed counterpart': 'Your Jeeber',
      // The `unknown` phase's empty copy — reachable only from the `new`
      'Fresh compose · no conversation yet': 'No conversation yet',
      // A read that came back with nothing on a thread that DOES exist.
      'Empty · accepted thread': 'Say hello',
      // The failure body — NOT either empty state.
      'History load failed': "Couldn't load this chat",
      'Longest content': _kLongestMessage,
    },
  );

  // The broadcasting feed is the one designed state that cannot render
  group('ChatDetailScreen previews · Broadcasting · offer cards landing', () {
    Future<void> pumpBroadcasting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        chatDetailScreenBroadcasting,
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
      testWidgets('Broadcasting · offer cards landing · ${locale.languageCode}',
          (WidgetTester tester) async {
        await pumpBroadcasting(tester, locale: locale);
      });
    }

    testWidgets('Broadcasting renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpBroadcasting(tester);

      // Only the broadcasting feed carries an offer card, and only Kamal's
      expect(find.text(_kOfferNote), findsOneWidget);
      expect(
        find.byKey(const Key('chat-offer-card-offer-kamal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat-offer-card-offer-rana')),
        findsOneWidget,
      );
    });
  });

  // The loading body is six `OmdsListItemShimmer` rows, i.e. a repeating
  group('ChatDetailScreen previews · Loading · cold history', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(chatDetailScreenLoadingHistory, locale),
      );
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
      // …and no composer either: the body is replaced wholesale while the read
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('ChatDetailScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpPreview(tester, chatDetailScreenAccepted);

      expect(tester.getSize(find.byType(ChatDetailScreen)).width, 390);
    });

    // Run-22 §T5. `_headerTitle` runs the resolved counterpart name through
    testWidgets('the unnamed-counterpart state never renders the raw handle', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatDetailScreenAcceptedUnnamed);

      expect(find.textContaining(_kSyntheticHandle), findsNothing);
      expect(find.text('Your Jeeber'), findsOneWidget);
      // …and the accepted chrome is still there, so the fallback is a HEADER
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
    });

    // The named counterpart is the control for the state above: same fixture,
    testWidgets('the named counterpart is rendered verbatim, not genericised', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatDetailScreenAccepted);

      expect(find.text('Kamal Hajj'), findsWidgets);
      expect(find.text('Your Jeeber'), findsNothing);
    });

    // b02, and the reason all three are previewed adjacently: a failed read
    testWidgets('the failure body is an error with a retry, never an empty '
        'state', (WidgetTester tester) async {
      await pumpPreview(tester, chatDetailScreenHistoryFailed);

      expect(find.byKey(ChatScreen.historyErrorKey), findsOneWidget);
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
      expect(find.text('No conversation yet'), findsNothing);
      expect(find.text('Say hello'), findsNothing);
      // An error the user cannot act on is barely better than the empty state
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the empty preview is the EMPTY state, not the error one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatDetailScreenEmptyAccepted);

      expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
      expect(find.byKey(ChatScreen.historyErrorKey), findsNothing);
    });

    // Fresh compose is the third "nothing here" state, and the only one whose
    testWidgets('fresh compose shows the Chat label, never a reference built '
        'from the sentinel', (WidgetTester tester) async {
      await pumpPreview(tester, chatDetailScreenFreshCompose);

      expect(find.text('Chat'), findsOneWidget);
      expect(find.textContaining('#NEW'), findsNothing);
      expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
    });

    // JM-025 AC1 vs AC2: the compose state is the one where the next message
    testWidgets('compose carries no pinned summary and no dispute action', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, chatDetailScreenCompose);

      expect(find.bySemanticsIdentifier('order_chat_pinned_summary'),
          findsNothing);
      expect(find.bySemanticsIdentifier('order_chat_open_dispute'),
          findsNothing);
      // The composer stays live through `broadcasting` — the customer can still
      expect(find.byType(TextField), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the accepted state stacks the pinned summary over the thread', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, chatDetailScreenAccepted);

      expect(
        find.bySemanticsIdentifier('order_chat_pinned_summary'),
        findsOneWidget,
      );
      expect(
        find.text('Hello Kamal please i need the water to be tanourine'),
        findsOneWidget,
      );
      handle.dispose();
    });

    // The bound is meant to be INERT at a normal text scale on a real phone: a
    testWidgets('the header slot does not scroll on the 390 pt phone', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatDetailScreenLongestContent);

      final ScrollableState slot = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(chatHeaderSlotKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(slot.position.maxScrollExtent, 0);
    });
  });
}
