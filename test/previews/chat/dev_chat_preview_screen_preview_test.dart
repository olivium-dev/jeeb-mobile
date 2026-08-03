// Render tests for the DevChatPreviewScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/dev_chat_preview_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/confirm_delivery_action_sheet.dart';

import '../preview_test_harness.dart';

/// Kamal's note — produced only by the broadcasting feed's first offer card.
const String _kKamalOfferNote =
    r'Hi i can bring you your order in 2 hours for  35$';

/// The jeeber legs' balance-deduction banner, verbatim.
const String _kFeeBannerNotice = r'Note $0.5 will be reduced from your Balance';

/// The fee banner's "Order picked" pill — the one pixel that separates the
/// `dm` state from the `dm-order-picked` one.
const Key _kOrderPickedPill = Key('chat-fee-banner-order-picked');

/// Pumps [preview] with framework errors intercepted rather than recorded.
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

  // Every preview except `Client · broadcasting offers`, which cannot render
  testPreviewsRender(
    'DevChatPreviewScreen',
    const <String, Widget Function()>{
      'Client · sending initial request': devChatPreviewScreenClientSending,
      'Client · accepted thread': devChatPreviewScreenClientAccepted,
      'Unrecognised selector · silent fallback':
          devChatPreviewScreenUnrecognisedSelector,
      'Jeeber · accepted thread': devChatPreviewScreenJeeberAccepted,
      'Jeeber · order picked': devChatPreviewScreenJeeberOrderPicked,
      'Jeeber · confirm picking sheet':
          devChatPreviewScreenJeeberConfirmPicking,
      'Jeeber · confirm heading-off sheet':
          devChatPreviewScreenJeeberConfirmHeadingOff,
      'Compact 320 pt · jeeber order picked': devChatPreviewScreenCompactJeeber,
    },
    expectedText: const <String, String>{
      // The request-feed header: a centred order id instead of a counterpart,
      'Client · sending initial request': 'ORD-23748',
      // The third bubble exists only in the accepted 1:1 thread.
      'Client · accepted thread':
          'Hello Kamal please i need the water to be tanourine',
      // The unrecognised selector falls through to that same accepted thread,
      'Unrecognised selector · silent fallback': 'Kamal Hajj',
      // The balance-deduction banner is the jeeber leg's signature chrome.
      'Jeeber · accepted thread': _kFeeBannerNotice,
      // …and the pill replaces the dismiss × on exactly one of its states.
      'Jeeber · order picked': 'Order picked',
      // The two sheets differ ONLY in their title, which is the whole reason
      'Jeeber · confirm picking sheet': 'Confirm Picking the order',
      'Jeeber · confirm heading-off sheet': 'Confirm Heading off',
      // Same selector as `Jeeber · order picked`, a different width: the two
      'Compact 320 pt · jeeber order picked': _kFeeBannerNotice,
    },
  );

  // The broadcasting feed is the one designed state that cannot render
  group('DevChatPreviewScreen previews · Client · broadcasting offers', () {
    Future<void> pumpBroadcasting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        devChatPreviewScreenClientBroadcasting,
        locale: locale,
      );

      for (final FlutterErrorDetails details in caught) {
        expect(
          details.exception.toString(),
          contains('overflowed'),
          reason: 'only the documented offer-card overflow is tolerated here',
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

      // Only the broadcasting selector seeds offer cards, and only Kamal's
      expect(find.text(_kKamalOfferNote), findsOneWidget);
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

  group('DevChatPreviewScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpPreview(tester, devChatPreviewScreenClientAccepted);

      expect(tester.getSize(find.byType(DevChatPreviewScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, devChatPreviewScreenCompactJeeber);

      expect(tester.getSize(find.byType(DevChatPreviewScreen)).width, 320);
    });

    // The pre-offers frame is the sending state's ENTIRE subject: the same
    testWidgets('the sending preview carries no offer card and no '
        'accept-only-one footer', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenClientSending);

      expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);
      expect(find.text(_kKamalOfferNote), findsNothing);
      expect(find.text('Accept only one offer'), findsNothing);
      // The composer stays visible through `broadcasting` — the client can
      expect(find.byType(TextField), findsOneWidget);
    });

    // `selector.startsWith('dm')` picks the leg and the client leg closes with
    testWidgets('an unrecognised selector silently renders the client '
        'accepted thread', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenUnrecognisedSelector);

      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(find.text('Hello Kamal please i need the water to be tanourine'),
          findsOneWidget);
      // Not the jeeber leg, which is where a `dm`-prefixed typo would land.
      expect(find.text(_kFeeBannerNotice), findsNothing);
      expect(find.text('Sami Fawaz'), findsNothing);
    });

    // The trailing slot is the ONLY pixel that separates `dm` from
    testWidgets('the plain jeeber thread has an EMPTY fee-banner trailing '
        'slot — no pill, no dismiss', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenJeeberAccepted);

      expect(find.text(_kFeeBannerNotice), findsOneWidget);
      expect(find.byKey(_kOrderPickedPill), findsNothing);
      // Scoped to the banner on purpose: the accepted banner stacked above the
      expect(
        find.descendant(
          of: find.byType(ChatFeeBanner),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );
    });

    testWidgets('the order-picked state fills that slot with the pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, devChatPreviewScreenJeeberOrderPicked);

      expect(find.text(_kFeeBannerNotice), findsOneWidget);
      expect(find.byKey(_kOrderPickedPill), findsOneWidget);
    });

    // The reason `_devChatPreviewScreenSheetHosted` exists. `show()` targets
    testWidgets('the auto-opened sheet stays inside its own 390 pt card', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, devChatPreviewScreenJeeberConfirmPicking);

      final Rect surface = tester.getRect(find.byType(DevChatPreviewScreen));
      final Rect sheet = tester.getRect(
        find.byType(ConfirmDeliveryActionSheet),
      );

      expect(surface.width, 390);
      expect(sheet.left, greaterThanOrEqualTo(surface.left));
      expect(sheet.right, lessThanOrEqualTo(surface.right));
      // …and the chat it belongs to is still mounted behind it.
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    // The two sheets share a shell and differ only in their copy, so the one
    testWidgets('the heading-off selector opens the heading-off sheet, not '
        'the picking one', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenJeeberConfirmHeadingOff);

      expect(find.text('Confirm Heading off'), findsOneWidget);
      expect(find.text('Confirm Picking the order'), findsNothing);
    });
  });
}
