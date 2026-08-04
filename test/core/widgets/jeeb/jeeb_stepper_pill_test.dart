import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_stepper_pill.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #27, re-cut on the MIDNIGHT token sheet.
///
/// FAIL-WITHOUT: the `offer_composer_price_decrement` / `_increment`
/// identifiers are frozen Maestro targets. If this widget stops emitting them,
/// 17's E2E goes green while the price stepper is unreachable. And: the label
/// is WHITE — an orange `−1`/`+1` pair spends 17's orange budget twice over.
void main() {
  // Token sheet §1/§3: ink `#EDEFFC`, `glassFillEmphasis` white 10%,
  // `glassBorderStrong` white 16%.
  const Color ink = Color(0xFFEDEFFC);
  const Color glassFillEmphasis = Color(0x1AFFFFFF);
  const Color glassBorderStrong = Color(0x29FFFFFF);

  group('JeebStepperPill visuals', () {
    testWidgets('is a 1px glass pill with 12.5/w700 white ink', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          JeebStepperPill(label: '+1', onTap: () {}),
        ),
      );

      final BoxDecoration decoration =
          remainderDecorationOf(tester, find.byType(JeebStepperPill));
      expect(decoration.borderRadius, BorderRadius.circular(999));
      final Border border = decoration.border! as Border;
      expect(border.top.color, glassBorderStrong);
      expect(border.top.width, 1);
      expect(decoration.color, glassFillEmphasis);

      final TextStyle style = tester.widget<Text>(find.text('+1')).style!;
      expect(style.fontSize, 12.5);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, ink);
    });

    testWidgets('insets 6/12 plus the 1px stroke (border-box)', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(JeebStepperPill(label: '-1', onTap: () {})),
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebStepperPill),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      );
    });

    testWidgets('pairs sit 6 apart', (tester) async {
      expect(JeebStepperPill.spacing, 6);
    });
  });

  group('JeebStepperPill behaviour', () {
    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapRemainder(JeebStepperPill(label: '+1', onTap: () => taps++)),
      );

      await tester.tap(find.byType(JeebStepperPill));
      expect(taps, 1);
    });

    testWidgets('a disabled pill dims and swallows the tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapRemainder(
          JeebStepperPill(
            label: '-1',
            isEnabled: false,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(JeebStepperPill));
      expect(taps, 0);

      final Opacity opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(JeebStepperPill),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, JeebStepperPill.disabledOpacity);
    });
  });

  group('JeebStepperPill semantics', () {
    testWidgets('emits one button node carrying the frozen identifier',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          JeebStepperPill(
            label: '+1',
            identifier: 'offer_composer_price_increment',
            semanticLabel: 'Increase price by one',
            onTap: () {},
          ),
        ),
      );

      final Finder node =
          find.bySemanticsIdentifier('offer_composer_price_increment');
      expect(node, findsOneWidget);
      final SemanticsNode semantics = tester.getSemantics(node);
      expect(semantics.label, 'Increase price by one');
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
    });

    testWidgets('reports enabled: false at the price floor', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          JeebStepperPill(
            label: '-1',
            identifier: 'offer_composer_price_decrement',
            isEnabled: false,
            onTap: () {},
          ),
        ),
      );

      final SemanticsNode semantics = tester.getSemantics(
        find.bySemanticsIdentifier('offer_composer_price_decrement'),
      );
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });
  });

  group('JeebStepperPill RTL smoke', () {
    testWidgets('renders and taps under RTL', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapRemainder(
          JeebStepperPill(label: '+1', onTap: () => taps++),
          direction: TextDirection.rtl,
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(JeebStepperPill));
      expect(taps, 1);
    });

    testWidgets('directional padding mirrors', (tester) async {
      const EdgeInsetsGeometry lopsided =
          EdgeInsetsDirectional.fromSTEB(24, 6, 4, 6);
      final Widget pill =
          JeebStepperPill(label: '+1', padding: lopsided, onTap: () {});

      await tester.pumpWidget(wrapRemainder(pill));
      final double ltrGap = tester.getTopLeft(find.text('+1')).dx -
          tester.getTopLeft(find.byType(JeebStepperPill)).dx;

      await tester.pumpWidget(
        wrapRemainder(pill, direction: TextDirection.rtl),
      );
      final double rtlGap =
          tester.getTopRight(find.byType(JeebStepperPill)).dx -
              tester.getTopRight(find.text('+1')).dx;

      // 24 start + 1 stroke, on the mirrored edge.
      expect(ltrGap, closeTo(25, 0.01));
      expect(rtlGap, closeTo(25, 0.01));
    });
  });

  testWidgets('survives a bare ThemeData.light() harness', (tester) async {
    await tester.pumpWidget(
      wrapUnthemed(JeebStepperPill(label: '+1', onTap: () {})),
    );
    expect(tester.takeException(), isNull);
  });
}
