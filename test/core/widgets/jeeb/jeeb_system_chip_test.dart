import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_system_chip.dart';

import 'jeeb_chat_test_harness.dart';

/// Gates for the centred timeline chip (kit §5 #17).
///
/// FAIL-WITHOUT: the two tones collapse into one and the settled-fact chip
/// starts drawing a border it does not have, or the countdown pill re-invents a
/// fourth orange.
void main() {
  final ThemeData theme = AppTheme.light();
  final ColorScheme scheme = theme.colorScheme;

  group('JeebSystemChip tones', () {
    testWidgets('filled is surfaceContainerHigh with no border, pad 4/12',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(const JeebSystemChip.filled(label: 'Offer accepted · 9:12')),
      );

      final ShapeDecoration decoration =
          chatShapeOf(tester, find.byType(JeebSystemChip));
      expect(decoration.color, scheme.surfaceContainerHigh);
      expect(decoration.shape, isA<StadiumBorder>());
      expect((decoration.shape as StadiumBorder).side.style, BorderStyle.none);

      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(JeebSystemChip),
          matching: find.byType(Container),
        ),
      );
      expect(
        box.padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 4),
      );

      final Text label = tester.widget<Text>(find.text('Offer accepted · 9:12'));
      expect(label.style!.fontSize, 10.5);
      expect(label.style!.fontWeight, FontWeight.w700);
      // onSecondaryContainer IS the periwinkle; mutedText is decorative-only.
      expect(label.style!.color, scheme.onSecondaryContainer);
    });

    testWidgets('outlined is a 1.5px outline with pad 5/13 + the stroke',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebSystemChip.outlined(label: 'Karim is on the way'),
        ),
      );

      final ShapeDecoration decoration =
          chatShapeOf(tester, find.byType(JeebSystemChip));
      expect(decoration.color, isNull);
      final StadiumBorder shape = decoration.shape as StadiumBorder;
      expect(shape.side.color, scheme.outline);
      expect(shape.side.width, 1.5);

      // border-box: the stroke sits outside the 5/13 inset. Measured, not read
      // off the widget, because `Container` folds the border dimensions in
      // itself — asserting the field would hide a double-count.
      final Rect box = tester.getRect(
        find.descendant(
          of: find.byType(JeebSystemChip),
          matching: find.byType(Container),
        ),
      );
      final Rect label = tester.getRect(find.text('Karim is on the way'));
      expect(label.left - box.left, closeTo(13 + 1.5, 0.01));
      expect(label.top - box.top, closeTo(5 + 1.5, 0.01));

      expect(
        tester.widget<Text>(find.text('Karim is on the way')).style!.color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('accent is the outlined geometry in jeebRoles.accent',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(const JeebSystemChip.accent(label: 'Expires in 2:00')),
      );

      final ShapeDecoration decoration =
          chatShapeOf(tester, find.byType(JeebSystemChip));
      final Color accent = theme.extension<JeebColorRoles>()!.accent;
      expect((decoration.shape as StadiumBorder).side.color, accent);
      expect(
        tester.widget<Text>(find.text('Expires in 2:00')).style!.color,
        accent,
      );
    });

    testWidgets('the runtime constructor picks the same tone', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebSystemChip(
            label: 'Offer rejected',
            tone: JeebSystemChipTone.filled,
          ),
        ),
      );

      expect(
        chatShapeOf(tester, find.byType(JeebSystemChip)).color,
        scheme.surfaceContainerHigh,
      );
    });
  });

  group('JeebSystemChip layout & semantics', () {
    testWidgets('centres itself and never fills the row', (tester) async {
      await tester.pumpWidget(
        wrapChat(const JeebSystemChip.filled(label: 'x')),
      );

      final Rect chip = tester.getRect(
        find.descendant(
          of: find.byType(JeebSystemChip),
          matching: find.byType(Container),
        ),
      );
      expect(chip.center.dx, closeTo(kChatFrameWidth / 2, 0.5));
      expect(chip.width, lessThan(kChatFrameWidth));
    });

    testWidgets('center: false leaves positioning to the caller',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const Row(
            children: <Widget>[
              JeebSystemChip.filled(label: 'x', center: false),
            ],
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(JeebSystemChip),
          matching: find.byType(Align),
        ),
        findsNothing,
      );
    });

    testWidgets('emits the identifier', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebSystemChip.filled(
            label: 'Today',
            identifier: 'chat_detail_date_separator',
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('chat_detail_date_separator'),
        findsOneWidget,
      );
    });

    testWidgets('adds no Semantics node when nothing needs one',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(const JeebSystemChip.filled(label: 'x')),
      );

      expect(
        find.descendant(
          of: find.byType(JeebSystemChip),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('JeebSystemChip RTL', () {
    testWidgets('stays centred and directional under RTL', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebSystemChip.outlined(label: 'كريم في الطريق'),
          direction: TextDirection.rtl,
        ),
      );

      final Finder box = find.descendant(
        of: find.byType(JeebSystemChip),
        matching: find.byType(Container),
      );
      expect(
        tester.getRect(box).center.dx,
        closeTo(kChatFrameWidth / 2, 0.5),
      );
      expect(find.text('كريم في الطريق'), findsOneWidget);

      // No physical bias: the inset resolves identically in both directions,
      // so nothing is pinned to a hardcoded left/right.
      final EdgeInsetsGeometry padding =
          tester.widget<Container>(box).padding!;
      expect(
        padding.resolve(TextDirection.rtl),
        padding.resolve(TextDirection.ltr),
      );
      // ...and the un-folded filled inset is directional by construction.
      expect(JeebSystemChip.filledPadding, isA<EdgeInsetsDirectional>());
      expect(JeebSystemChip.outlinedPadding, isA<EdgeInsetsDirectional>());
    });
  });
}
