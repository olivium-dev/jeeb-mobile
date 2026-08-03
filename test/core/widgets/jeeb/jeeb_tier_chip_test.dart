import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_chip.dart';

/// Local harness — private so concurrent kit lanes cannot break each other.
Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(child: SizedBox(width: 340, child: child)),
      ),
    ),
  );
}

BoxDecoration _pillDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(JeebTierChip),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('JeebTier lexicon (kit-owned, plan risk 7)', () {
    test('the five emoji are fixed and unknown renders nothing', () {
      expect(JeebTier.flash.emoji, '⚡');
      expect(JeebTier.express.emoji, '🚀');
      expect(JeebTier.standard.emoji, '🟦');
      expect(JeebTier.onTheWay.emoji, '🤝');
      expect(JeebTier.eco.emoji, '🌿');
      expect(JeebTier.unknown.emoji, '');
    });

    test('fromId is case- and separator-insensitive and never throws', () {
      expect(JeebTier.fromId('flash'), JeebTier.flash);
      expect(JeebTier.fromId('onTheWay'), JeebTier.onTheWay);
      expect(JeebTier.fromId('on_the_way'), JeebTier.onTheWay);
      expect(JeebTier.fromId('ON-THE-WAY'), JeebTier.onTheWay);
      expect(JeebTier.fromId('eco'), JeebTier.eco);
      expect(JeebTier.fromId('teleport'), JeebTier.unknown);
      expect(JeebTier.fromId(null), JeebTier.unknown);
    });

    test('emojiFor is the static 12 consumes without drawing a pill', () {
      expect(JeebTierChip.emojiFor('flash'), '⚡');
      expect(JeebTierChip.emojiFor('standard'), '🟦');
      expect(JeebTierChip.emojiFor(null), '');
    });
  });

  group('JeebTierChip — shape', () {
    testWidgets('surfaceContainerHigh pill, navy 11.5/w700, pad 4/10', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTierChip(tier: JeebTier.flash, label: 'Flash'),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTierChip));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration = _pillDecoration(tester);

      expect(decoration.color, scheme.surfaceContainerHigh);
      expect(decoration.borderRadius, jeebPillRadius);
      // Outline-over-shadow: a meta chip never casts one, and never strokes.
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNull);

      final TextStyle style = tester.widget<Text>(find.text('Flash')).style!;
      expect(style.fontSize, 11.5);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, scheme.onSurface);

      expect(
        JeebTierChip.defaultPadding.resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      );
    });

    testWidgets('emoji and label are TWO Text children, never one string', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const JeebTierChip(tier: JeebTier.flash, label: 'سريع')),
      );

      // The pinned assertions on 04 / 10 are exactly these.
      expect(find.text('سريع'), findsOneWidget);
      expect(find.text('⚡'), findsOneWidget);
      expect(find.text('⚡ سريع'), findsNothing);
    });

    testWidgets('an unknown tier draws the label alone (render-nothing branch)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebTierChip(tier: JeebTier.unknown, label: 'Whatever')),
      );

      expect(find.text('Whatever'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JeebTierChip),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('custom takes raw (emoji, label) strings — 24 WR-3', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          JeebTierChip.custom(
            emoji: JeebTierChip.emojiFor('onTheWay'),
            label: 'On-the-Way',
          ),
        ),
      );

      expect(find.text('🤝'), findsOneWidget);
      expect(find.text('On-the-Way'), findsOneWidget);
    });

    testWidgets('meta is the same pill with no emoji — 06 W4', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const JeebTierChip.meta(label: '≤ 1 hr')),
      );

      final BuildContext context = tester.element(find.byType(JeebTierChip));
      expect(
        _pillDecoration(tester).color,
        Theme.of(context).colorScheme.surfaceContainerHigh,
      );
      expect(
        find.descendant(
          of: find.byType(JeebTierChip),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(find.text('≤ 1 hr'), findsOneWidget);
    });
  });

  group('JeebTierChip — the re-tone is structural', () {
    testWidgets('inside a navy card it flips to white14 fill + white ink', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebNavySurfaceCard(
            child: JeebTierChip.meta(label: '≤ 4 hr'),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTierChip));
      final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
      final ColorScheme scheme = Theme.of(context).colorScheme;

      expect(tone.kind, JeebSurfaceKind.navy);
      expect(_pillDecoration(tester).color, scheme.onPrimary.withValues(alpha: 0.14));
      expect(
        tester.widget<Text>(find.text('≤ 4 hr')).style!.color,
        scheme.onPrimary,
      );
    });

    testWidgets('a selected outlined card re-tones it without any parameter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            child: JeebTierChip(tier: JeebTier.standard, label: 'Standard'),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebTierChip));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      expect(
        tester.widget<Text>(find.text('Standard')).style!.color,
        scheme.onPrimary,
      );
    });

    testWidgets('standalone (no card above) it falls back to the light tone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const JeebTierChip(tier: JeebTier.eco, label: 'Eco')),
      );

      final BuildContext context = tester.element(find.byType(JeebTierChip));
      expect(
        _pillDecoration(tester).color,
        Theme.of(context).colorScheme.surfaceContainerHigh,
      );
    });
  });

  group('JeebTierChip — semantics', () {
    testWidgets('no identifier adds no container node', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const JeebTierChip(tier: JeebTier.flash, label: 'Flash')),
      );

      expect(
        find.descendant(
          of: find.byType(JeebTierChip),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is Semantics && widget.container,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('an identifier is findable', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebTierChip(
            tier: JeebTier.flash,
            label: 'Flash',
            identifier: 'order_summary_tier',
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('order_summary_tier'), findsOneWidget);
    });
  });

  group('RTL smoke', () {
    testWidgets('the emoji leads on the start side in both directions', (
      WidgetTester tester,
    ) async {
      Future<void> pump(TextDirection direction) => tester.pumpWidget(
            _wrap(
              const JeebTierChip(tier: JeebTier.flash, label: 'سريع'),
              direction: direction,
            ),
          );

      await pump(TextDirection.ltr);
      expect(
        tester.getCenter(find.text('⚡')).dx,
        lessThan(tester.getCenter(find.text('سريع')).dx),
      );

      await pump(TextDirection.rtl);
      expect(
        tester.getCenter(find.text('⚡')).dx,
        greaterThan(tester.getCenter(find.text('سريع')).dx),
      );
    });

    testWidgets('padding is directional, so it mirrors with the text', (
      WidgetTester tester,
    ) async {
      expect(JeebTierChip.defaultPadding, isA<EdgeInsetsDirectional>());

      await tester.pumpWidget(
        _wrap(
          const JeebTierChip(tier: JeebTier.express, label: 'إكسبرس'),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.text('إكسبرس'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
