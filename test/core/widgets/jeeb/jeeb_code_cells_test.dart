import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_code_cells.dart';
import 'package:omds/omds.dart';

import 'jeeb_code_test_harness.dart';

ColorScheme get _scheme => AppTheme.light().colorScheme;
Color get _accent => JeebColorRoles.light().accent;

/// The `DecoratedBox` of cell [index], skipping the caret's own decoration by
/// taking only the boxes that carry a fill.
BoxDecoration _cellBox(WidgetTester tester, int index) {
  final Iterable<BoxDecoration> filled =
      decorationsUnder(tester, find.byType(JeebCodeCells))
          .where((BoxDecoration d) => d.color != null && d.borderRadius != null)
          .toList();
  // Cells paint before their carets, and the caret is 2 px wide — filter it
  // out by radius, which is 2 on the caret and 16/20 on a cell.
  final List<BoxDecoration> cells = filled
      .where((BoxDecoration d) =>
          (d.borderRadius! as BorderRadius).topLeft.x > 4)
      .toList();
  return cells[index];
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('JeebCodeCells.input74 — 03 keypad-driven entry', () {
    testWidgets('renders one cell per length and only the entered digits',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '12')),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // Empty cells draw nothing at all — no placeholder, no underscore
      // (`03 tpl 126`).
      expect(find.byType(Text), findsNWidgets(2));
      expect(find.byType(Expanded), findsNWidgets(4));
    });

    testWidgets('length reports the cell count, not value.length',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '12')),
      );

      // `otp_verification_screen_test.dart` pins the input length this way.
      expect(
        tester.widget<JeebCodeCells>(find.byType(JeebCodeCells)).length,
        4,
      );
    });

    testWidgets('cells are h74 r16 surfaceContainerHigh at gap 12, flex 1',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '1')),
      );

      final BoxDecoration first = _cellBox(tester, 0);
      expect(first.color, _scheme.surfaceContainerHigh);
      expect(
        (first.borderRadius! as BorderRadius).topLeft.x,
        JeebCodeCells.inputRadius,
      );
      // No shadow anywhere on the light entry row.
      expect(first.boxShadow, isNull);

      final List<Rect> rects = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .map((Expanded e) => tester.getRect(find.byWidget(e)))
          .toList();
      for (final Rect rect in rects) {
        expect(rect.height, JeebCodeCells.inputBoxHeight);
      }
      // 392 - 3 gaps of 12 = 356, split four ways.
      expect(rects[0].width, closeTo(89, 0.01));
      expect(rects[1].left - rects[0].right, JeebCodeCells.inputCellGap);
    });

    testWidgets('the next empty cell is framed 2px accent and carries a caret',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '12')),
      );

      // Filled cells: fill only, no stroke.
      expect(_cellBox(tester, 0).border, isNull);
      expect(_cellBox(tester, 1).border, isNull);

      final BoxBorder active = _cellBox(tester, 2).border!;
      expect(active.top.color, _accent);
      expect(active.top.width, JeebCodeCells.activeBorderWidth);
      // The cell after the active one is untouched.
      expect(_cellBox(tester, 3).border, isNull);

      final Finder caret = find.byWidgetPredicate(
        (Widget w) =>
            w is SizedBox &&
            w.width == JeebCodeCells.caretWidth &&
            w.height == JeebCodeCells.caretHeight,
      );
      expect(caret, findsOneWidget);
      expect(tester.getRect(caret).center.dx,
          closeTo(tester.getRect(find.byType(Expanded).at(2)).center.dx, 0.01));
    });

    testWidgets('a complete code frames nothing — the caret is gone',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '1234')),
      );

      for (var i = 0; i < 4; i++) {
        expect(_cellBox(tester, i).border, isNull, reason: 'cell $i');
      }
    });

    testWidgets('hasError strokes every cell 2px colorScheme.error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input74(length: 4, value: '12', hasError: true),
        ),
      );

      for (var i = 0; i < 4; i++) {
        final BoxBorder border = _cellBox(tester, i).border!;
        expect(border.top.color, _scheme.error, reason: 'cell $i');
        expect(border.top.width, JeebCodeCells.activeBorderWidth);
      }
    });

    testWidgets('digits use jeebText.codeInput (29/w800) in navy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '7')),
      );

      final TextStyle style = _styleOf(tester, '7');
      expect(style.fontSize, 29);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, _scheme.primary);
    });

    testWidgets('cellIdentifier emits one addressable leaf per cell',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input74(
            length: 4,
            value: '12',
            cellIdentifier: 'phone_otp_input',
          ),
        ),
      );

      for (var i = 0; i < 4; i++) {
        expect(
          find.bySemanticsIdentifier('phone_otp_input_$i'),
          findsOneWidget,
          reason: 'phone_otp_input_$i',
        );
      }
    });

    testWidgets('identifier adds a container node; null adds none at all',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input74(
            length: 4,
            value: '12',
            identifier: 'phone_otp_input',
            cellIdentifier: 'phone_otp_input',
          ),
        ),
      );
      // Exactly one node owns the bare id — the per-cell leaves are suffixed,
      // so a Maestro `tapOn` is never ambiguous.
      expect(find.bySemanticsIdentifier('phone_otp_input'), findsOneWidget);

      // Nothing passed → the kit adds no node at all, so a consumer that owns
      // its own wrapper (03 and 18 both do) never gets a duplicate.
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input74(length: 4, value: '12')),
      );
      expect(find.bySemanticsIdentifier('phone_otp_input'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(JeebCodeCells),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('survives a theme with no Jeeb extensions registered',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCodeUnthemed(const JeebCodeCells.input74(length: 4, value: '9')),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('digits shrink rather than overflow at 200% text scale',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input74(length: 4, value: '1234'),
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
      for (final Element element in find.byType(Expanded).evaluate()) {
        expect(tester.getRect(find.byWidget(element.widget)).height,
            JeebCodeCells.inputBoxHeight);
      }
    });
  });

  group('JeebCodeCells.input52 — 18 keyboard-driven entry', () {
    testWidgets('wraps OmdsOtpInput at h52 gap 9 with flex-emulated widths',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.input52()),
      );

      final OmdsOtpInput input =
          tester.widget<OmdsOtpInput>(find.byType(OmdsOtpInput));
      expect(input.length, 4);
      expect(input.boxHeight, JeebCodeCells.compactBoxHeight);
      expect(input.spacing, JeebCodeCells.compactCellGap);
      // 392 - 3 gaps of 9 = 365, split four ways.
      expect(input.boxWidth, closeTo(91.25, 0.01));
      expect(input.fillColor, _scheme.surfaceContainerHigh);
      expect(input.focusedBorderColor, _accent);
      expect(input.errorBorderColor, _scheme.error);
      // Never steal focus on mount: 18's card is already on screen.
      expect(input.autoFocus, isFalse);
    });

    testWidgets('digits are 22/w800 — NOT codeInput\'s 29',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapCode(const JeebCodeCells.input52()));

      final TextStyle style =
          tester.widget<OmdsOtpInput>(find.byType(OmdsOtpInput)).textStyle!;
      expect(style.fontSize, JeebCodeCells.compactDigitSize);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, _scheme.primary);
    });

    testWidgets('kills the resting hairline and tints the caret accent',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapCode(const JeebCodeCells.input52()));

      final OmdsColorTokensProvider provider = tester.widget(
        find.byType(OmdsColorTokensProvider),
      );
      expect(provider.tokens.inputBorderColor, _scheme.surfaceContainerHigh);

      final TextSelectionTheme selection =
          tester.widget(find.byType(TextSelectionTheme));
      expect(selection.data.cursorColor, _accent);
    });

    testWidgets('cellIdentifier reaches OMDS so the editable leaves keep RC-7',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input52(
            identifier: 'mark_delivered_otp_input',
            cellIdentifier: 'mark_delivered_otp_input',
          ),
        ),
      );

      expect(
        tester.widget<OmdsOtpInput>(find.byType(OmdsOtpInput)).identifier,
        'mark_delivered_otp_input',
      );
      for (var i = 0; i < 4; i++) {
        expect(
          find.bySemanticsIdentifier('mark_delivered_otp_input_$i'),
          findsOneWidget,
        );
      }
      expect(
        find.bySemanticsIdentifier('mark_delivered_otp_input'),
        findsOneWidget,
      );
    });

    testWidgets('forwards hasError and both callbacks',
        (WidgetTester tester) async {
      String? changed;
      String? completed;
      await tester.pumpWidget(
        wrapCode(
          JeebCodeCells.input52(
            hasError: true,
            onChanged: (String v) => changed = v,
            onCompleted: (String v) => completed = v,
          ),
        ),
      );

      final OmdsOtpInput input =
          tester.widget<OmdsOtpInput>(find.byType(OmdsOtpInput));
      expect(input.hasError, isTrue);

      await tester.enterText(find.byType(TextField).first, '5');
      await tester.pump();
      expect(changed, '5');
      expect(completed, isNull);
    });
  });

  group('JeebCodeCells.display — 13 share tiles', () {
    testWidgets('four 74×92 r20 navy tiles with heroNavy at gap 13',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapCode(const JeebCodeCells.display('2144')));

      final List<BoxDecoration> tiles =
          decorationsUnder(tester, find.byType(JeebCodeCells)).toList();
      expect(tiles, hasLength(4));
      for (final BoxDecoration tile in tiles) {
        expect(tile.color, _scheme.primary);
        expect(
          (tile.borderRadius! as BorderRadius).topLeft.x,
          JeebCodeCells.displayTileRadius,
        );
        expect(tile.boxShadow, JeebShadows.heroNavy);
        expect(tile.border, isNull);
      }

      final Finder box = find.byWidgetPredicate(
        (Widget w) =>
            w is SizedBox &&
            w.width == JeebCodeCells.displayTileWidth &&
            w.height == JeebCodeCells.displayTileHeight,
      );
      expect(box, findsNWidgets(4));
      // 4×74 + 3×13 = 335 fits the board's 392, so nothing is scaled here.
      expect(tester.getRect(box.at(1)).left - tester.getRect(box.at(0)).right,
          closeTo(JeebCodeCells.displayTileGap, 0.01));
    });

    testWidgets('digits are statDisplay (42/w800) in onPrimary',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapCode(const JeebCodeCells.display('2144')));

      final TextStyle style = _styleOf(tester, '2');
      expect(style.fontSize, 42);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, _scheme.onPrimary);
    });

    testWidgets('length reports value.length', (WidgetTester tester) async {
      await tester.pumpWidget(wrapCode(const JeebCodeCells.display('2144')));

      expect(
        tester.widget<JeebCodeCells>(find.byType(JeebCodeCells)).length,
        4,
      );
    });

    testWidgets('scales the whole row down on a narrow phone, never up',
        (WidgetTester tester) async {
      // 360 pt phone inside 24 pt gutters: 312 < the row's intrinsic 335.
      await tester.pumpWidget(
        wrapCode(const JeebCodeCells.display('2144'), width: 312),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(JeebCodeCells)).width,
          lessThanOrEqualTo(312));
    });
  });

  group('JeebCodeCells.strip — 12 inline code', () {
    testWidgets('renders ONE Text at 20/w800 ls5, key forwarded',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.strip(
            '2144',
            textKey: Key('tracking.codeRowValue'),
          ),
        ),
      );

      // Per-character widgets would break `find.text('2144')` AND the key.
      expect(find.byType(Text), findsOneWidget);
      expect(find.text('2144'), findsOneWidget);
      expect(find.byKey(const Key('tracking.codeRowValue')), findsOneWidget);

      final TextStyle style = _styleOf(tester, '2144');
      expect(style.fontSize, JeebCodeCells.stripFontSize);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.letterSpacing, JeebCodeCells.stripLetterSpacing);
      expect(style.color, _scheme.primary);
    });

    testWidgets('a key on the widget also resolves for find.byKey',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.strip(
            '2144',
            key: Key('tracking.codeRowValue'),
          ),
        ),
      );

      expect(find.byKey(const Key('tracking.codeRowValue')), findsOneWidget);
    });
  });

  group('RTL smoke — digits never mirror', () {
    testWidgets('input74 cell 0 stays at the LEFT under rtl',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input74(
            length: 4,
            value: '12',
            cellIdentifier: 'phone_otp_input',
          ),
          direction: TextDirection.rtl,
        ),
      );

      final double first =
          tester.getRect(find.bySemanticsIdentifier('phone_otp_input_0')).left;
      final double second =
          tester.getRect(find.bySemanticsIdentifier('phone_otp_input_1')).left;
      final double last =
          tester.getRect(find.bySemanticsIdentifier('phone_otp_input_3')).left;
      expect(first, lessThan(second));
      expect(second, lessThan(last));

      // And the digits stay in the order they were typed.
      expect(tester.getRect(find.text('1')).left,
          lessThan(tester.getRect(find.text('2')).left));
    });

    testWidgets('display tiles read 2-1-4-4 left to right under rtl',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.display('2144'),
          direction: TextDirection.rtl,
        ),
      );

      // `2` is the first digit of the code: it must paint furthest to the LEFT
      // even in Arabic, or the customer reads the jeeber a different code.
      expect(tester.getRect(find.text('2')).left,
          lessThan(tester.getRect(find.text('1')).left));
    });

    testWidgets('input52 keeps its cells in issue order under rtl',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.input52(cellIdentifier: 'mark_delivered_otp'),
          direction: TextDirection.rtl,
        ),
      );

      expect(
        tester.getRect(find.bySemanticsIdentifier('mark_delivered_otp_0')).left,
        lessThan(
          tester
              .getRect(find.bySemanticsIdentifier('mark_delivered_otp_3'))
              .left,
        ),
      );
    });

    testWidgets('strip renders the code unreordered under rtl',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          const JeebCodeCells.strip('2144'),
          direction: TextDirection.rtl,
        ),
      );

      expect(find.text('2144'), findsOneWidget);
      expect(
        tester.widget<Directionality>(
          find
              .descendant(
                of: find.byType(JeebCodeCells),
                matching: find.byType(Directionality),
              )
              .first,
        ).textDirection,
        TextDirection.ltr,
      );
    });
  });
}
