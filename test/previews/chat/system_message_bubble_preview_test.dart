// Render tests for the SystemMessageBubble previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// Six previews of one centred pill look interchangeable from the outside — the
// widget's ONLY visible output is a single string — so the `expectedText` pins
// below are the whole point of the suite: each is a string only that state can
// produce. Without them a suite over six renderings of the same Container would
// pass even if every function returned the same fixture.
//
// The specifics group pins what a text pin cannot express: that the nameless
// payload really takes the NAMED branch (the generic fallback is dead code on
// every wire path), that the empty and wrong-kind rows really occupy zero
// height, that server `system` copy is passed through unlocalized AND
// un-direction-detected, and that the long notice degrades by growing rather
// than by overflowing at 200%.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/system_message_bubble.dart';

import '../preview_test_harness.dart';

/// The bubble keys its root `chat-system-<message id>`. A collapsed row returns
/// a bare [SizedBox.shrink] and carries NO key, which is why the collapse
/// assertions below address rows by key rather than by text.
Key _rowKey(String id) => Key('chat-system-$id');

/// Server copy on the `system` kind, rendered verbatim from `message.text`.
const String _serverNoticeEn =
    'Your request expired before a Jeeber accepted it.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SystemMessageBubble',
    const <String, Widget Function()>{
      'Offer accepted · named': systemMessageBubbleAccepted,
      'Offer accepted · nameless payload': systemMessageBubbleAcceptedNameless,
      'Offer withdrawn · named': systemMessageBubbleRejected,
      'Server notice · verbatim': systemMessageBubbleServerNotice,
      'Long name at 390dp': systemMessageBubbleLongName,
      'Empty + unsupported collapse': systemMessageBubbleCollapsed,
    },
    expectedText: const <String, String>{
      'Offer accepted · named': "Kamal Hajj's offer was accepted",
      // The possessive with nothing in front of it — see the preview doc.
      'Offer accepted · nameless payload': "'s offer was accepted",
      'Offer withdrawn · named': "Rana's offer was withdrawn",
      'Server notice · verbatim': _serverNoticeEn,
      'Long name at 390dp':
          "Abdulrahman Al-Muhandis Al-Trabulsi's offer was accepted",
      // The one row of the three that is supposed to paint.
      'Empty + unsupported collapse': "Ziad's offer was accepted",
    },
  );

  group('SystemMessageBubble preview specifics', () {
    testWidgets('the named notice uses the payload, not the generic copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleAccepted);

      expect(find.text("Kamal Hajj's offer was accepted"), findsOneWidget);
      expect(find.text('Offer accepted'), findsNothing);
      expect(find.byKey(_rowKey('sys-accepted-1')), findsOneWidget);
    });

    testWidgets('accepted and withdrawn never collapse to the same string', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleRejected);

      expect(find.text("Rana's offer was withdrawn"), findsOneWidget);
      expect(find.textContaining('accepted'), findsNothing);
    });

    testWidgets('a nameless payload takes the NAMED branch — the generic '
        'fallback is unreachable from any wire path', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleAcceptedNameless);

      // `SystemOfferPayload.fromWire` resolves a missing name to '' and never
      // to null, so `_copyFor`'s `payload == null` arm cannot fire and the
      // template is substituted with an empty name.
      expect(find.text("'s offer was accepted"), findsOneWidget);
      expect(find.text('Offer accepted'), findsNothing);
    });

    testWidgets('empty and wrong-kind rows occupy zero height', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, systemMessageBubbleCollapsed);

      // Three messages in, one pill out.
      expect(find.byType(SystemMessageBubble), findsNWidgets(3));
      expect(find.byKey(_rowKey('sys-accepted-4')), findsOneWidget);

      // An empty `system` row and a `text` row routed here both return
      // SizedBox.shrink — no key, no padding, no empty pill in the thread.
      expect(find.byKey(_rowKey('sys-empty')), findsNothing);
      expect(find.byKey(_rowKey('sys-wrong-kind')), findsNothing);
      expect(
        find.text('a text message must never paint as a system chip'),
        findsNothing,
      );
    });

    testWidgets('server `system` copy is passed through UNLOCALIZED', (
      WidgetTester tester,
    ) async {
      // The offer kinds read the ARB; this kind returns `message.text` as-is.
      // So an Arabic reader gets whatever language the gateway wrote — asserted
      // here so the gap is a recorded contract rather than a surprise.
      await pumpPreview(
        tester,
        systemMessageBubbleServerNotice,
        locale: const Locale('ar'),
      );

      expect(find.text(_serverNoticeEn), findsOneWidget);
    });

    testWidgets('the offer copy DOES localize', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        systemMessageBubbleAccepted,
        locale: const Locale('ar'),
      );

      expect(find.text('تم قبول عرض Kamal Hajj'), findsOneWidget);
      expect(find.text("Kamal Hajj's offer was accepted"), findsNothing);
    });

    testWidgets('the pill centres in both directionalities', (
      WidgetTester tester,
    ) async {
      // The default 800x600 viewport, so a centred pill sits at dx 400. It is
      // a Center with symmetric padding, so RTL must not move it.
      await pumpPreview(tester, systemMessageBubbleAccepted);
      expect(
        tester.getCenter(find.text("Kamal Hajj's offer was accepted")).dx,
        closeTo(400, 0.5),
      );

      await pumpPreview(
        tester,
        systemMessageBubbleAccepted,
        locale: const Locale('ar'),
      );
      expect(
        tester.getCenter(find.text('تم قبول عرض Kamal Hajj')).dx,
        closeTo(400, 0.5),
      );
    });

    testWidgets('long copy wraps inside the gutters instead of running past '
        'them', (WidgetTester tester) async {
      // pumpPreview ignores JeebPreview.size and uses an 800 dp viewport, so
      // this state clamps itself; without the clamp there is no phone width to
      // wrap against and the assertion below would be vacuous.
      await pumpPreview(tester, systemMessageBubbleLongName);

      expect(tester.getSize(find.byType(SystemMessageBubble)).width, 390);

      // 390 dp minus the 16 dp outer gutters and the 16 dp pill padding on
      // each side. The pill has no max-width token and no maxLines, so this is
      // the only thing keeping it off the edge.
      final double textWidth = tester
          .getSize(
            find.text(
              "Abdulrahman Al-Muhandis Al-Trabulsi's offer was accepted",
            ),
          )
          .width;
      expect(textWidth, lessThanOrEqualTo(390 - 32 - 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an Arabic server notice keeps the AMBIENT direction — no '
        'first-strong detection on this kind', (WidgetTester tester) async {
      // Recording a real gap, not asserting a desired behaviour. Sibling text
      // bubbles wrap their body in AutoDirectionText, so an Arabic line inside
      // an English thread gets an RTL paragraph. SystemMessageBubble uses a
      // bare Text, so the Arabic row below resolves to LTR: its sentence-final
      // '.' is laid out on the wrong side of the sentence.
      //
      // If this ever fails because the direction came back RTL, the bubble has
      // been given the same treatment as its siblings and this test should be
      // inverted rather than deleted.
      await pumpPreview(tester, systemMessageBubbleServerNotice);

      final RenderParagraph arabicRow = tester.renderObject<RenderParagraph>(
        find.text('انتهت مهلة الطلب قبل أن يقبله أي جيبر.'),
      );
      expect(arabicRow.textDirection, TextDirection.ltr);
      expect(arabicRow.textAlign, TextAlign.center);
    });

    testWidgets('the long notice grows instead of overflowing at 200% text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: previewCanvas(systemMessageBubbleLongName, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      final Size text = tester.getSize(
        find.text("Abdulrahman Al-Muhandis Al-Trabulsi's offer was accepted"),
      );
      // Measured at 390 dp with the bundled font: 326x48 (three lines) at 1x
      // and 326x160 (five lines) at 2x. The width is pinned by the gutters in
      // both, so the whole 2x cost is height — a ~3.3x taller row mid-thread,
      // which is a degradation and not a break.
      expect(text.width, lessThanOrEqualTo(390 - 32 - 32));
      expect(text.height, greaterThan(48));
      // No RenderFlex stripe: the pill has no maxLines, so it wraps rather
      // than clipping.
      expect(tester.takeException(), isNull);
    });
  });
}
