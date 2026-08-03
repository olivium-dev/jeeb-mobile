import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_chat_composer.dart';

import 'jeeb_chat_test_harness.dart';

/// Gates for the single-pill composer (kit §5 #18).
///
/// FAIL-WITHOUT: the mic comes back (B-04), the frozen composer keys stop being
/// tappable, or the 19px glyph ships with a 19px tap target.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;
  const Key fieldKey = Key('chat-composer-text-field');
  const Key attachKey = Key('chat-composer-attach-button');
  const Key sendKey = Key('chat-composer-send-button');

  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget composer({
    VoidCallback? onSend,
    VoidCallback? onAttach,
    bool isAttaching = false,
    TextDirection direction = TextDirection.ltr,
  }) {
    return wrapChat(
      JeebChatComposer(
        controller: controller,
        hintText: 'Message…',
        onSend: onSend,
        onAttach: onAttach,
        isAttaching: isAttaching,
        fieldKey: fieldKey,
        attachKey: attachKey,
        sendKey: sendKey,
        inputIdentifier: 'chat_detail_message_input',
        attachIdentifier: 'chat_detail_attach_button',
        sendIdentifier: 'chat_detail_send_button',
      ),
      direction: direction,
    );
  }

  group('JeebChatComposer B-04', () {
    testWidgets('renders SEND and never a mic', (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.bySemanticsIdentifier('chat_detail_voice_button'),
          findsNothing);
    });

    testWidgets('the attach glyph is the photo mark, not a plus',
        (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      final Icon glyph =
          tester.widget<Icon>(find.byIcon(Icons.image_outlined));
      expect(glyph.size, 19);
      expect(glyph.color, scheme.onSecondaryContainer);
    });
  });

  group('JeebChatComposer pill', () {
    testWidgets('is 52 high inside 10/24 padding', (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      // 10 top + 52 pill + 10 bottom (the board's 30 is the home indicator,
      // supplied by SafeArea, which is zero in the test MediaQuery).
      expect(tester.getSize(find.byType(JeebChatComposer)).height, 72);
    });

    testWidgets('fill and 1px border come from the tokens', (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      final ShapeDecoration decoration =
          chatShapeOf(tester, find.byType(JeebChatComposer));
      expect(decoration.color, scheme.surfaceContainerHigh);
      final StadiumBorder shape = decoration.shape as StadiumBorder;
      expect(shape.side.color, scheme.surfaceContainerHighest);
      expect(shape.side.width, 1);
    });

    testWidgets('placeholder is body in the periwinkle ink', (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      final TextField field = tester.widget<TextField>(find.byKey(fieldKey));
      expect(field.decoration!.hintText, 'Message…');
      expect(field.decoration!.hintStyle!.fontSize, 13.5);
      expect(field.decoration!.hintStyle!.color, scheme.onSecondaryContainer);
      // The pill IS the decoration — the field must paint nothing.
      expect(field.decoration!.border, InputBorder.none);
      expect(field.decoration!.filled, isFalse);
    });
  });

  group('JeebChatComposer actions', () {
    testWidgets('keeps the frozen keys tappable at 48dp', (tester) async {
      var sends = 0;
      var attaches = 0;
      await tester.pumpWidget(
        composer(onSend: () => sends++, onAttach: () => attaches++),
      );

      expect(tester.getSize(find.byKey(attachKey)), const Size(48, 48));
      expect(tester.getSize(find.byKey(sendKey)), const Size(48, 48));

      await tester.tap(find.byKey(attachKey));
      await tester.tap(find.byKey(sendKey));
      expect(attaches, 1);
      expect(sends, 1);
    });

    testWidgets('the Ø38 circle keeps its measured size inside the target',
        (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      final Size circle = tester.getSize(
        find.descendant(
          of: find.byKey(sendKey),
          matching: find.byType(Container),
        ),
      );
      expect(circle, const Size(38, 38));
      expect(tester.widget<Icon>(find.byIcon(Icons.send)).size, 18);

      // ...and it still lands where the board puts it: 1px border + 8 inset.
      // That is what the pill's `end: 3` buys back after the Ø38 circle is
      // centred inside its 48dp target.
      final Rect pill = tester.getRect(
        find.descendant(
          of: find.byType(JeebChatComposer),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      final Rect circleRect = tester.getRect(
        find.descendant(
          of: find.byKey(sendKey),
          matching: find.byType(Container),
        ),
      );
      expect(pill.right - circleRect.right, closeTo(9, 0.01));
    });

    testWidgets('a null onSend fades the circle and reports disabled',
        (tester) async {
      await tester.pumpWidget(composer(onAttach: () {}));

      final Container circle = tester.widget<Container>(
        find.descendant(
          of: find.byKey(sendKey),
          matching: find.byType(Container),
        ),
      );
      expect(
        (circle.decoration! as BoxDecoration).color,
        scheme.primary.withValues(alpha: 0.38),
      );
      expect(
        find.descendant(
          of: find.byKey(sendKey),
          matching: find.byType(InkResponse),
        ),
        findsNothing,
      );
    });

    testWidgets('isAttaching swaps the glyph for a spinner and blocks the tap',
        (tester) async {
      var attaches = 0;
      await tester.pumpWidget(
        composer(onSend: () {}, onAttach: () => attaches++, isAttaching: true),
      );

      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(attachKey));
      expect(attaches, 0);
    });

    testWidgets('emits all three identifiers', (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));

      expect(find.bySemanticsIdentifier('chat_detail_message_input'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_detail_attach_button'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_detail_send_button'),
          findsOneWidget);
    });
  });

  group('JeebChatComposer RTL', () {
    testWidgets('both actions move to the leading edge under RTL',
        (tester) async {
      await tester.pumpWidget(composer(onSend: () {}, onAttach: () {}));
      final Rect sendLtr = tester.getRect(find.byKey(sendKey));
      final Rect attachLtr = tester.getRect(find.byKey(attachKey));
      expect(sendLtr.center.dx, greaterThan(kChatFrameWidth / 2));
      // attach sits before send in the reading order
      expect(attachLtr.center.dx, lessThan(sendLtr.center.dx));

      await tester.pumpWidget(
        composer(
          onSend: () {},
          onAttach: () {},
          direction: TextDirection.rtl,
        ),
      );
      final Rect sendRtl = tester.getRect(find.byKey(sendKey));
      final Rect attachRtl = tester.getRect(find.byKey(attachKey));
      expect(sendRtl.center.dx, lessThan(kChatFrameWidth / 2));
      expect(attachRtl.center.dx, greaterThan(sendRtl.center.dx));

      // Mirrored, not merely shifted: the pill inset is directional.
      expect(
        kChatFrameWidth - sendLtr.right,
        closeTo(sendRtl.left, 0.01),
      );
    });
  });
}
