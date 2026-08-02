// Render tests for the DevChatPreviewScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen is a DISPATCHER: one string in, one of six designed frames out,
// and every unrecognised string still produces a frame. A render-only check
// therefore passes on every one of these previews even if the dispatch is
// completely miswired — which is the single failure this screen can have. So
// each state pins a string that only IT can produce, and the groups below pin
// the parts of the dispatch that no string can distinguish: the widths, the
// empty-vs-populated fee-banner trailing slot, and the fact that the two
// confirm sheets stay INSIDE their own card.

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
///
/// `tester.takeException()` cannot be used to inspect them: once a second error
/// lands the binding collapses both into "Multiple exceptions (2) were
/// detected…", which says nothing about what they were. Taking them at
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

  // Every preview except `Client · broadcasting offers`, which cannot render
  // exception-free at the width the app ships — see the dedicated group below.
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
      // which is what the client's two pre-accept states share and no other
      // state has.
      'Client · sending initial request': 'ORD-23748',
      // The third bubble exists only in the accepted 1:1 thread.
      'Client · accepted thread':
          'Hello Kamal please i need the water to be tanourine',
      // The unrecognised selector falls through to that same accepted thread,
      // so its header — the counterpart name the accepted leg switches to — is
      // what says the fallback fired rather than a blank or a jeeber frame.
      'Unrecognised selector · silent fallback': 'Kamal Hajj',
      // The balance-deduction banner is the jeeber leg's signature chrome.
      'Jeeber · accepted thread': _kFeeBannerNotice,
      // …and the pill replaces the dismiss × on exactly one of its states.
      'Jeeber · order picked': 'Order picked',
      // The two sheets differ ONLY in their title, which is the whole reason
      // both are previewed and both are pinned.
      'Jeeber · confirm picking sheet': 'Confirm Picking the order',
      'Jeeber · confirm heading-off sheet': 'Confirm Heading off',
      // Same selector as `Jeeber · order picked`, a different width: the two
      // cannot be told apart by text, so this one pins the banner BODY — the
      // element that has to keep sharing a row with the pill at 320 pt — and
      // the width itself is pinned in the specifics group below.
      'Compact 320 pt · jeeber order picked': _kFeeBannerNotice,
    },
  );

  // The broadcasting feed is the one designed state that cannot render
  // exception-free at a real phone width. `OfferCardBubble` lays Accept +
  // Decline out as a `Row(mainAxisSize: min)` of two intrinsically sized pills
  // with no `Wrap` and no `Flexible`; inside the chat the bubble is capped at
  // 250 pt, and the footer overflows in EN at 390 pt — one exception per card,
  // so two per pump here. That is a PRE-EXISTING defect of that widget,
  // measured and documented in its own preview library; this screen only makes
  // it visible at the width the app ships.
  //
  // Tolerated rather than asserted: a test that pins a bug fails the day
  // someone fixes it. But tolerated NARROWLY — anything that is not an overflow
  // still fails, and widening the frame until the stripes disappear would have
  // been the other way to make this suite green, which is exactly the reading
  // these previews exist to prevent.
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

      // Only the broadcasting selector seeds offer cards, and only Kamal's
      // carries this note.
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
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `BlocProvider` element is UPDATED rather than replaced and keeps
    // the cubit the first preview created. The screen would still show the
    // first state under the second preview's name.

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
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
    // header and the same bubble as broadcasting, minus the offers. Pinned the
    // same way `test/features/chat/dev_chat_sending_fixture_test.dart` pins it,
    // because a fixture quietly rewired to the broadcasting thread would still
    // render — with two offer cards nobody asked for.
    testWidgets('the sending preview carries no offer card and no '
        'accept-only-one footer', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenClientSending);

      expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);
      expect(find.text(_kKamalOfferNote), findsNothing);
      expect(find.text('Accept only one offer'), findsNothing);
      // The composer stays visible through `broadcasting` — the client can
      // still type while offers arrive.
      expect(find.byType(TextField), findsOneWidget);
    });

    // `selector.startsWith('dm')` picks the leg and the client leg closes with
    // `_ => accepted`, so nothing rejects an unknown string. This is the hole,
    // asserted rather than described: the fallback frame is the CLIENT accepted
    // thread — no fee banner, no jeeber counterpart — and it renders happily.
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
    // `dm-order-picked`, and `_bannerTrailing` is a three-way switch on the raw
    // selector string. If it ever collapses, both jeeber states render the same
    // banner and every other assertion in this file still passes.
    testWidgets('the plain jeeber thread has an EMPTY fee-banner trailing '
        'slot — no pill, no dismiss', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenJeeberAccepted);

      expect(find.text(_kFeeBannerNotice), findsOneWidget);
      expect(find.byKey(_kOrderPickedPill), findsNothing);
      // Scoped to the banner on purpose: the accepted banner stacked above the
      // thread carries a × of its own, so a bare `byIcon(Icons.close)` here
      // would assert the wrong widget's dismiss and pass for the wrong reason.
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
    // the nearest Navigator, so without a local one the sheet would be pushed
    // onto the harness's root navigator and cover the whole 800 pt surface —
    // in the canvas, the whole canvas. Confinement is measured, not assumed:
    // the sheet must sit inside the 390 pt card, which is centred on that
    // surface and therefore starts well right of x = 0.
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
    // failure that matters here is the wrong `DeliveryConfirmKind` reaching it.
    testWidgets('the heading-off selector opens the heading-off sheet, not '
        'the picking one', (WidgetTester tester) async {
      await pumpPreview(tester, devChatPreviewScreenJeeberConfirmHeadingOff);

      expect(find.text('Confirm Heading off'), findsOneWidget);
      expect(find.text('Confirm Picking the order'), findsNothing);
    });
  });
}
