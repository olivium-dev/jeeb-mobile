import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_card_test_harness.dart';

/// Gates for the MIDNIGHT rest-glass card (token sheet §4).
///
/// FAIL-WITHOUT: if the card grows a shadow, loses its 1px glass stroke, or
/// stops delegating `selected` to the emphasis card, ~20 screens drift
/// together and no other test in the suite notices.
void main() {
  final ThemeData theme = AppTheme.midnight();
  final ColorScheme scheme = theme.colorScheme;
  final JeebSemanticColors semantics = theme.extension<JeebSemanticColors>()!;

  // Token sheet §3, typed out rather than read back off the implementation.
  const Color glassFill = Color(0x12FFFFFF);
  const Color glassBorder = Color(0x1FFFFFFF);
  const Color glassFillEmphasis = Color(0x1AFFFFFF);
  const Color glassBorderStrong = Color(0x29FFFFFF);

  group('JeebOutlinedCard default state', () {
    testWidgets('is glass, a 1px glass stroke, r-lg and carries NO shadow',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebOutlinedCard(child: Text('body'))),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebOutlinedCard));

      expect(decoration.color, glassFill);
      expect(decoration.boxShadow, isNull, reason: 'glass never lifts');
      final Border border = decoration.border! as Border;
      expect(border.top.color, glassBorder);
      expect(border.top.width, 1);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.lg));
    });

    testWidgets('defaults to 13/16 padding', (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebOutlinedCard(child: Text('body'))),
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebOutlinedCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      // 13/16 plus the 1px stroke, so the board's border-box maths holds.
      expect(padding.padding.resolve(TextDirection.ltr),
          const EdgeInsets.symmetric(horizontal: 17, vertical: 14));
    });

    testWidgets('honours the 2px accent stroke of a lit frame (R9/R22)',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          Builder(
            builder: (BuildContext context) => JeebOutlinedCard(
              radius: JeebRadii.xl,
              borderColor: context.jeebRoles.accent,
              borderWidth: 2,
              child: const Text('body'),
            ),
          ),
        ),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebOutlinedCard));
      final Border border = decoration.border! as Border;
      expect(border.top.color, const Color(0xFFD73B00));
      expect(border.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.xl));
    });

    testWidgets('renders the action row', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            actions: Text('Accept'),
            child: Text('body'),
          ),
        ),
      );

      expect(find.text('Accept'), findsOneWidget);
    });

    testWidgets('publishes the light tone to descendants', (tester) async {
      late JeebSurfaceToneData tone;
      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard(
            child: ToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
          ),
        ),
      );

      expect(tone.kind, JeebSurfaceKind.light);
      expect(tone.onNavy, isFalse);
      expect(tone.chipFill, scheme.surfaceContainerHigh);
      expect(tone.chipInk, scheme.onSurface);
      expect(tone.meterEmpty, scheme.surfaceContainerHighest);
      expect(tone.mutedInk, semantics.mutedText);
    });
  });

  group('JeebOutlinedCard selected state', () {
    testWidgets('delegates to JeebNavySurfaceCard — a fill swap, not a stroke',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            child: Text('body'),
          ),
        ),
      );

      expect(find.byType(JeebNavySurfaceCard), findsOneWidget);

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebNavySurfaceCard));
      expect(decoration.color, glassFillEmphasis);
      final Border border = decoration.border! as Border;
      expect(border.top.color, glassBorderStrong);
      expect(border.top.width, 1, reason: 'never a thicker border');
      // Wave-A: no glow by default — the fill swap IS the selection.
      expect(decoration.boxShadow, isEmpty);
    });

    testWidgets('a consumer can still opt the glow back in', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            selectedShadow: JeebShadows.glowRest,
            child: Text('body'),
          ),
        ),
      );

      expect(
        decorationOf(tester, find.byType(JeebNavySurfaceCard)).boxShadow,
        JeebShadows.glowRest,
      );
    });

    testWidgets('re-tones internal chips/meters without consumer help',
        (tester) async {
      late JeebSurfaceToneData tone;
      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard(
            state: JeebCardState.selected,
            child: ToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
          ),
        ),
      );

      expect(tone.onNavy, isTrue);
      expect(tone.chipFill, const Color(0x24FFFFFF));
      expect(tone.chipInk, scheme.onSurface);
      expect(tone.mutedInk, semantics.inkSoft);
      expect(tone.meterEmpty, scheme.onSurface.withValues(alpha: 0.25));
      expect(tone.meterFill, scheme.onSurface);
    });

    testWidgets('keeps the action row', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            actions: Text('Accept'),
            child: Text('body'),
          ),
        ),
      );

      expect(find.text('Accept'), findsOneWidget);
    });

    testWidgets('carries the selected radius and padding through',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            radius: JeebRadii.xl,
            padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
            child: Text('body'),
          ),
        ),
      );

      final JeebNavySurfaceCard navy =
          tester.widget<JeebNavySurfaceCard>(find.byType(JeebNavySurfaceCard));
      expect(navy.radius, JeebRadii.xl);
      expect(
        navy.padding,
        const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      );
    });
  });

  group('JeebOutlinedCard dormant state', () {
    testWidgets('dims to .75 AND drops the action row', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard(
            state: JeebCardState.dormant,
            actions: Text('Accept'),
            child: Text('body'),
          ),
        ),
      );

      final Opacity opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(JeebOutlinedCard),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.75);
      expect(find.text('body'), findsOneWidget);
      expect(
        find.text('Accept'),
        findsNothing,
        reason: 'dormant removes the action row — the explicit half of §5 #3',
      );
    });
  });

  group('JeebOutlinedCard.grouped', () {
    testWidgets('emits n-1 dividers inset 16 and zero own padding',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard.grouped(
            children: <Widget>[Text('one'), Text('two'), Text('three')],
          ),
        ),
      );

      final Finder dividers = find.descendant(
        of: find.byType(JeebOutlinedCard),
        matching: find.byType(ColoredBox),
      );
      expect(dividers, findsNWidgets(2));
      expect(
        tester.widget<ColoredBox>(dividers.first).color,
        scheme.outlineVariant,
      );

      final Padding dividerPadding = tester.widget<Padding>(
        find.ancestor(of: dividers.first, matching: find.byType(Padding)).first,
      );
      expect(
        dividerPadding.padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 16),
      );

      final Padding cardPadding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebOutlinedCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(cardPadding.padding.resolve(TextDirection.ltr),
          const EdgeInsets.all(1));
    });

    testWidgets('dividers: false emits none', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard.grouped(
            dividers: false,
            children: <Widget>[Text('one'), Text('two')],
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(JeebOutlinedCard),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });

  group('JeebOutlinedCard semantics', () {
    testWidgets('surfaces the identifier and fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard(
            identifier: 'tier_selection_card_flash',
            semanticLabel: 'Flash tier',
            onTap: () => taps++,
            child: const Text('body'),
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('tier_selection_card_flash'),
        findsOneWidget,
      );
      await tester.tap(find.text('body'));
      expect(taps, 1);
    });

    testWidgets('adds no Semantics node when nothing needs one',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebOutlinedCard(child: Text('body'))),
      );

      // 23 nests its own container node inside the card; an unconditional
      // wrapper here would swallow it.
      expect(
        find.descendant(
          of: find.byType(JeebOutlinedCard),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('a tappable card reports selected in both polarities',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard(
            identifier: 'card',
            onTap: () {},
            child: const Text('body'),
          ),
        ),
      );
      final Semantics unselected = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebOutlinedCard),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(unselected.properties.selected, isFalse);

      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard(
            identifier: 'card',
            state: JeebCardState.selected,
            onTap: () {},
            child: const Text('body'),
          ),
        ),
      );
      final Semantics selected = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebNavySurfaceCard),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(selected.properties.selected, isTrue);
    });
  });

  group('JeebOutlinedCard RTL smoke', () {
    testWidgets('mirrors directional padding', (tester) async {
      const Key probe = Key('probe');
      const Widget card = JeebOutlinedCard(
        padding: EdgeInsetsDirectional.fromSTEB(32, 8, 4, 8),
        child: Row(
          children: <Widget>[SizedBox(key: probe, width: 20, height: 20)],
        ),
      );

      await tester.pumpWidget(wrapCard(card));
      final double ltrGap = tester.getTopLeft(find.byKey(probe)).dx -
          tester.getTopLeft(find.byType(JeebOutlinedCard)).dx;

      await tester.pumpWidget(wrapCard(card, direction: TextDirection.rtl));
      expect(tester.takeException(), isNull);
      final double rtlGap =
          tester.getTopRight(find.byType(JeebOutlinedCard)).dx -
              tester.getTopRight(find.byKey(probe)).dx;

      // 1px stroke + 32px directional start padding, on the mirrored edge.
      expect(ltrGap, closeTo(33, 0.01));
      expect(rtlGap, closeTo(33, 0.01));
    });

    testWidgets('grouped dividers and selected state survive RTL',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebOutlinedCard.grouped(
            state: JeebCardState.selected,
            children: <Widget>[Text('one'), Text('two')],
          ),
          direction: TextDirection.rtl,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(JeebNavySurfaceCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JeebOutlinedCard),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });
  });
}
