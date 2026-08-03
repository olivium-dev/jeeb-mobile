import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_card_test_harness.dart';

/// Gates for redesign-2026-08 §5 #3.
///
/// FAIL-WITHOUT: if the outlined card grows a shadow, loses the 1.5px outline,
/// or stops delegating `selected` to the navy card, ~20 screens drift together
/// and no other test in the suite notices.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;

  group('JeebOutlinedCard default state', () {
    testWidgets('is white, 1.5px outline, r16 and carries NO shadow',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebOutlinedCard(child: Text('body'))),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebOutlinedCard));

      expect(decoration.color, scheme.surface);
      expect(decoration.boxShadow, isNull, reason: 'outline-over-shadow (§4.5)');
      final Border border = decoration.border! as Border;
      expect(border.top.color, scheme.outline);
      expect(border.top.width, 1.5);
      expect(decoration.borderRadius, BorderRadius.circular(16));
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
      // 13/16 plus the 1.5px stroke, so the board's border-box maths holds.
      expect(padding.padding.resolve(TextDirection.ltr),
          const EdgeInsets.symmetric(horizontal: 17.5, vertical: 14.5));
    });

    testWidgets('honours a 2px primary border override (11 recommended)',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard(
            radius: 18,
            borderColor: scheme.primary,
            borderWidth: 2,
            child: const Text('body'),
          ),
        ),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebOutlinedCard));
      final Border border = decoration.border! as Border;
      expect(border.top.color, scheme.primary);
      expect(border.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(18));
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
      expect(
        tone.mutedInk,
        AppTheme.light().extension<JeebSemanticColors>()!.mutedText,
      );
    });
  });

  group('JeebOutlinedCard selected state', () {
    testWidgets('delegates to JeebNavySurfaceCard — a fill swap, not a border',
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
      expect(decoration.color, scheme.primary);
      expect(decoration.border, isNull, reason: 'never a thicker border');
      expect(decoration.boxShadow, JeebNavySurfaceCard.selectedShadow);
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

      // The four measured on-navy values (08 tpl 458-465).
      expect(tone.onNavy, isTrue);
      expect(tone.chipFill, scheme.onPrimary.withValues(alpha: 0.14));
      expect(tone.chipInk, scheme.onPrimary);
      expect(tone.mutedInk, scheme.onPrimary.withValues(alpha: 0.7));
      expect(tone.meterEmpty, scheme.onPrimary.withValues(alpha: 0.25));
      expect(tone.meterFill, scheme.onPrimary);
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
            radius: 18,
            padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
            child: Text('body'),
          ),
        ),
      );

      final JeebNavySurfaceCard navy =
          tester.widget<JeebNavySurfaceCard>(find.byType(JeebNavySurfaceCard));
      expect(navy.radius, 18);
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
          const EdgeInsets.all(1.5));
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

      // 1.5px border + 32px directional start padding, on the mirrored edge.
      expect(ltrGap, closeTo(33.5, 0.01));
      expect(rtlGap, closeTo(33.5, 0.01));
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
