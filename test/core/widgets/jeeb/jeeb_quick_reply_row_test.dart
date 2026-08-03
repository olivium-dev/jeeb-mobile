import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_quick_reply_row.dart';

import 'jeeb_chat_test_harness.dart';

/// Gates for the quick-reply row (kit §5 #26).
///
/// FAIL-WITHOUT: the row force-LTRs itself and the Arabic pill inside an
/// English thread renders backwards, `reverse: true` is added and the row opens
/// at the wrong edge under RTL, or the label ink falls back to
/// `colorScheme.primary` — now ORANGE and outside the §2.2 budget.
void main() {
  final ColorScheme scheme = kChatTheme.colorScheme;

  List<JeebQuickReply> replies({VoidCallback? onHome}) => <JeebQuickReply>[
        JeebQuickReply(
          label: "I'm home",
          onTap: onHome,
          identifier: 'order_chat_quick_reply_home',
        ),
        const JeebQuickReply(
          label: 'Call me at the door',
          identifier: 'order_chat_quick_reply_door',
        ),
        const JeebQuickReply(
          label: 'شكراً',
          identifier: 'order_chat_quick_reply_thanks',
        ),
      ];

  group('JeebQuickReplyRow pills', () {
    testWidgets('rest-glass pills, 12.5/w600 ink, gap 8', (tester) async {
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies())),
      );

      final ShapeDecoration decoration =
          chatShapeOf(tester, find.byType(JeebQuickReplyRow));
      // Token sheet §4: rest glass = white 7% + 1px white 12%.
      expect(decoration.color, const Color(0x12FFFFFF));
      expect(decoration.color, kChatSemantics.glassFill);
      final StadiumBorder shape = decoration.shape as StadiumBorder;
      expect(shape.side.color, const Color(0x1FFFFFFF));
      expect(shape.side.color, kChatSemantics.glassBorder);
      expect(shape.side.width, 1);

      final Text label = tester.widget<Text>(find.text("I'm home"));
      // Ramp re-cut §6: bodySmall is 12.5/w600.
      expect(label.style!.fontSize, 12.5);
      expect(label.style!.fontWeight, FontWeight.w600);
      expect(label.style!.color, JeebMidnight.ink);
      expect(label.style!.color, isNot(scheme.primary));
      expect(label.softWrap, isFalse);

      final Rect first = tester.getRect(find.text("I'm home"));
      final Rect second = tester.getRect(find.text('Call me at the door'));
      // 8 gap + the 13 inset and 1px stroke on each of the facing edges
      expect(second.left - first.right, closeTo(8 + 2 * (13 + 1), 0.01));
    });

    testWidgets('folds the 1px stroke into the 8/13 inset', (tester) async {
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies())),
      );

      // Measured, not read off the widget: `Container` adds the border
      // dimensions itself, so asserting the field would hide a double-count.
      final Rect pill = tester.getRect(
        find.descendant(
          of: find.byType(JeebQuickReplyRow),
          matching: find.byType(Container),
        ).first,
      );
      final Rect label = tester.getRect(find.text("I'm home"));
      expect(label.left - pill.left, closeTo(13 + 1, 0.01));
      expect(label.top - pill.top, closeTo(8 + 1, 0.01));
    });

    testWidgets('fires onTap and emits the intent-keyed identifiers',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies(onHome: () => taps++))),
      );

      await tester.tap(find.text("I'm home"));
      expect(taps, 1);

      for (final String id in <String>[
        'order_chat_quick_reply_home',
        'order_chat_quick_reply_door',
        'order_chat_quick_reply_thanks',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget);
      }
    });

    testWidgets('an inert pill reports disabled rather than vanishing',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies())),
      );

      expect(
        find.descendant(
          of: find.byType(JeebQuickReplyRow),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(find.text('شكراً'), findsOneWidget);
    });
  });

  group('JeebQuickReplyRow container', () {
    testWidgets('scrolls horizontally with the 10/24/0 inset', (tester) async {
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies())),
      );

      final SingleChildScrollView scroller =
          tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroller.scrollDirection, Axis.horizontal);
      // `reverse: true` would open the row at the wrong edge under RTL.
      expect(scroller.reverse, isFalse);
      expect(
        scroller.padding!.resolve(TextDirection.ltr),
        const EdgeInsets.fromLTRB(24, 10, 24, 0),
      );

      // 24 gutter + 13 pill inset + the 1px stroke
      expect(
        tester.getRect(find.text("I'm home")).left,
        closeTo(24 + 13 + 1, 0.01),
      );
    });

    testWidgets('the row node keeps the per-pill ids visible', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          JeebQuickReplyRow(
            replies: replies(),
            identifier: 'order_chat_quick_reply_row',
            semanticLabel: 'Quick replies',
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('order_chat_quick_reply_row'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_chat_quick_reply_home'),
        findsOneWidget,
      );

      final Semantics node = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(JeebQuickReplyRow),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(node.container, isTrue);
      expect(node.explicitChildNodes, isTrue);
    });
  });

  group('JeebQuickReplyRow RTL', () {
    testWidgets('never forces LTR on its labels', (tester) async {
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies())),
      );

      // The Arabic pill sits inside an English thread and must inherit the
      // ambient direction rather than be isolated.
      expect(
        find.descendant(
          of: find.byType(JeebQuickReplyRow),
          matching: find.byType(Directionality),
        ),
        findsNothing,
      );
    });

    testWidgets('opens at the leading edge in both directions',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(JeebQuickReplyRow(replies: replies())),
      );
      expect(tester.getRect(find.text("I'm home")).left, lessThan(60));

      await tester.pumpWidget(
        wrapChat(
          JeebQuickReplyRow(replies: replies()),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getRect(find.text("I'm home")).right,
        greaterThan(kChatFrameWidth - 60),
      );
    });
  });
}
