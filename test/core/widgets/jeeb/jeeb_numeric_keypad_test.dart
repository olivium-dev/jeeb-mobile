import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_numeric_keypad.dart';

import 'jeeb_code_test_harness.dart';

ColorScheme get _scheme => AppTheme.light().colorScheme;

/// A pad with recording callbacks, so every test can assert what a tap did.
JeebNumericKeypad _pad({
  required List<String> digits,
  required List<int> backspaces,
  String? identifierPrefix = 'phone_otp_keypad',
  String? identifier,
  bool forceLtr = true,
}) {
  return JeebNumericKeypad(
    onDigit: digits.add,
    onBackspace: () => backspaces.add(1),
    backspaceLabel: 'Delete last digit',
    identifierPrefix: identifierPrefix,
    identifier: identifier,
    forceLtr: forceLtr,
  );
}

Rect _keyRect(WidgetTester tester, String identifier) =>
    tester.getRect(find.bySemanticsIdentifier(identifier));

void main() {
  group('JeebNumericKeypad — layout', () {
    testWidgets('renders 0-9 exactly once plus one backspace',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      for (var d = 0; d <= 9; d++) {
        expect(find.text('$d'), findsOneWidget, reason: 'digit $d');
      }
      expect(find.byIcon(Icons.backspace), findsOneWidget);
      // 10 digits + backspace = 11 tappable keys; the blank is NOT one.
      expect(find.byType(InkWell), findsNWidgets(11));
    });

    testWidgets('keys are h62 r16 surfaceContainerHigh at gap 10 in 3 columns',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      final Rect one = _keyRect(tester, 'phone_otp_keypad_1');
      final Rect two = _keyRect(tester, 'phone_otp_keypad_2');
      final Rect four = _keyRect(tester, 'phone_otp_keypad_4');
      expect(one.height, JeebNumericKeypad.keyHeight);
      expect(two.left - one.right, closeTo(JeebNumericKeypad.keyGap, 0.01));
      expect(four.top - one.bottom, closeTo(JeebNumericKeypad.keyGap, 0.01));
      // 392 gutter-to-gutter, minus the pad's own 20+20, minus two 10 gaps,
      // split three ways.
      expect(one.width, closeTo((392 - 40 - 20) / 3, 0.01));

      final BoxDecoration key = decorationsUnder(
        tester,
        find.bySemanticsIdentifier('phone_otp_keypad_1'),
      ).first;
      expect(key.color, _scheme.surfaceContainerHigh);
      expect(
        (key.borderRadius! as BorderRadius).topLeft.x,
        JeebNumericKeypad.keyRadius,
      );
      // Flat: no keypad key casts a shadow on the board.
      expect(key.boxShadow, isNull);
    });

    testWidgets('digits use jeebText.keypadDigit (23/w700) in navy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      final TextStyle style = tester.widget<Text>(find.text('7')).style!;
      expect(style.fontSize, 23);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, _scheme.primary);
    });

    testWidgets('the backspace key has NO fill and a 24px navy glyph',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      final BoxDecoration back = decorationsUnder(
        tester,
        find.bySemanticsIdentifier('phone_otp_keypad_backspace'),
      ).first;
      expect(back.color, isNull, reason: '`tpl 145` draws no background');

      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.backspace));
      expect(icon.size, JeebNumericKeypad.backspaceSize);
      expect(icon.color, _scheme.primary);
    });

    testWidgets('the pad carries its own 0/20/30 gutter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      final Rect pad = tester.getRect(find.byType(JeebNumericKeypad));
      expect(_keyRect(tester, 'phone_otp_keypad_1').left - pad.left, 20);
      expect(pad.right - _keyRect(tester, 'phone_otp_keypad_3').right, 20);
      expect(pad.bottom - _keyRect(tester, 'phone_otp_keypad_0').bottom, 30);
      expect(_keyRect(tester, 'phone_otp_keypad_1').top - pad.top, 0);
    });

    testWidgets('bottom row is blank-start, 0-centre, backspace-end',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      final Rect zero = _keyRect(tester, 'phone_otp_keypad_0');
      final Rect back = _keyRect(tester, 'phone_otp_keypad_backspace');
      final Rect seven = _keyRect(tester, 'phone_otp_keypad_7');
      final Rect nine = _keyRect(tester, 'phone_otp_keypad_9');

      // Same row, one row below 7-8-9.
      expect(zero.top, greaterThan(seven.bottom));
      expect(zero.top, back.top);
      // `0` sits under `8`, backspace under `9`, and the start column is empty.
      expect(zero.center.dx, closeTo(_keyRect(tester, 'phone_otp_keypad_8').center.dx, 0.01));
      expect(back.center.dx, closeTo(nine.center.dx, 0.01));
      expect(back.left, greaterThan(zero.right));
    });
  });

  group('JeebNumericKeypad — behaviour', () {
    testWidgets('every digit key reports its own ASCII digit',
        (WidgetTester tester) async {
      final List<String> digits = <String>[];
      final List<int> backspaces = <int>[];
      await tester.pumpWidget(
        wrapCode(_pad(digits: digits, backspaces: backspaces)),
      );

      for (final String d in <String>['1', '2', '3', '4', '0']) {
        await tester.tap(find.bySemanticsIdentifier('phone_otp_keypad_$d'));
      }
      await tester.pump();

      expect(digits, <String>['1', '2', '3', '4', '0']);
      expect(backspaces, isEmpty);
    });

    testWidgets('backspace fires onBackspace, never onDigit',
        (WidgetTester tester) async {
      final List<String> digits = <String>[];
      final List<int> backspaces = <int>[];
      await tester.pumpWidget(
        wrapCode(_pad(digits: digits, backspaces: backspaces)),
      );

      await tester
          .tap(find.bySemanticsIdentifier('phone_otp_keypad_backspace'));
      await tester.pump();

      expect(backspaces, hasLength(1));
      expect(digits, isEmpty);
    });

    testWidgets('the blank bottom-start cell is not tappable',
        (WidgetTester tester) async {
      final List<String> digits = <String>[];
      final List<int> backspaces = <int>[];
      await tester.pumpWidget(
        wrapCode(_pad(digits: digits, backspaces: backspaces)),
      );

      final Rect zero = _keyRect(tester, 'phone_otp_keypad_0');
      final Rect seven = _keyRect(tester, 'phone_otp_keypad_7');
      // The blank sits under `7`, on `0`'s row.
      await tester.tapAt(Offset(seven.center.dx, zero.center.dy));
      await tester.pump();

      expect(digits, isEmpty);
      expect(backspaces, isEmpty);
    });
  });

  group('JeebNumericKeypad — semantics', () {
    testWidgets('identifierPrefix emits <prefix>_0..9 and <prefix>_backspace',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      for (var d = 0; d <= 9; d++) {
        expect(
          find.bySemanticsIdentifier('phone_otp_keypad_$d'),
          findsOneWidget,
          reason: 'phone_otp_keypad_$d',
        );
      }
      expect(
        find.bySemanticsIdentifier('phone_otp_keypad_backspace'),
        findsOneWidget,
      );
    });

    testWidgets('the icon-only backspace announces its l10n label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );

      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('phone_otp_keypad_backspace'),
            )
            .label,
        'Delete last digit',
      );
      // Digit keys announce the digit, not a bare "button".
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('phone_otp_keypad_5'))
            .label,
        '5',
      );
    });

    testWidgets('identifier adds a container node; null adds none',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          _pad(
            digits: <String>[],
            backspaces: <int>[],
            identifier: 'phone_otp_keypad_root',
          ),
        ),
      );
      expect(
        find.bySemanticsIdentifier('phone_otp_keypad_root'),
        findsOneWidget,
      );
      // The wrapper must not swallow the per-key leaves.
      expect(find.bySemanticsIdentifier('phone_otp_keypad_9'), findsOneWidget);

      await tester.pumpWidget(
        wrapCode(_pad(digits: <String>[], backspaces: <int>[])),
      );
      expect(
        find.bySemanticsIdentifier('phone_otp_keypad_root'),
        findsNothing,
      );
    });

    testWidgets('no identifierPrefix → keys carry no ids but still work',
        (WidgetTester tester) async {
      final List<String> digits = <String>[];
      await tester.pumpWidget(
        wrapCode(
          _pad(
            digits: digits,
            backspaces: <int>[],
            identifierPrefix: null,
          ),
        ),
      );

      await tester.tap(find.text('6'));
      await tester.pump();
      expect(digits, <String>['6']);
    });
  });

  group('JeebNumericKeypad — RTL smoke', () {
    testWidgets('under rtl the grid stays 1-2-3 with backspace at the RIGHT',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          _pad(digits: <String>[], backspaces: <int>[]),
          direction: TextDirection.rtl,
        ),
      );

      // No dialer on either platform mirrors a number pad.
      expect(
        _keyRect(tester, 'phone_otp_keypad_1').left,
        lessThan(_keyRect(tester, 'phone_otp_keypad_3').left),
      );
      expect(
        _keyRect(tester, 'phone_otp_keypad_backspace').left,
        greaterThan(_keyRect(tester, 'phone_otp_keypad_0').right),
      );
    });

    testWidgets('taps still land on the right key under rtl',
        (WidgetTester tester) async {
      final List<String> digits = <String>[];
      final List<int> backspaces = <int>[];
      await tester.pumpWidget(
        wrapCode(
          _pad(digits: digits, backspaces: backspaces),
          direction: TextDirection.rtl,
        ),
      );

      await tester.tap(find.bySemanticsIdentifier('phone_otp_keypad_3'));
      await tester
          .tap(find.bySemanticsIdentifier('phone_otp_keypad_backspace'));
      await tester.pump();

      expect(digits, <String>['3']);
      expect(backspaces, hasLength(1));
    });

    testWidgets('forceLtr: false genuinely mirrors — nothing is hardcoded LTR',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          _pad(digits: <String>[], backspaces: <int>[], forceLtr: false),
          direction: TextDirection.rtl,
        ),
      );

      // Every position in the pad is expressed start/end, so dropping the
      // isolate flips the whole grid rather than half of it.
      expect(
        _keyRect(tester, 'phone_otp_keypad_1').left,
        greaterThan(_keyRect(tester, 'phone_otp_keypad_3').left),
      );
      expect(
        _keyRect(tester, 'phone_otp_keypad_backspace').right,
        lessThan(_keyRect(tester, 'phone_otp_keypad_0').left),
      );
    });
  });

  group('JeebNumericKeypad — resilience', () {
    testWidgets('survives a theme with no Jeeb extensions registered',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCodeUnthemed(_pad(digits: <String>[], backspaces: <int>[])),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('keys hold h62 and digits shrink at 200% text scale',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapCode(
          _pad(digits: <String>[], backspaces: <int>[]),
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        _keyRect(tester, 'phone_otp_keypad_1').height,
        JeebNumericKeypad.keyHeight,
      );
    });
  });
}
