import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_price_meter.dart';

import 'jeeb_meters_test_harness.dart';

/// Gates for the relative-price mark (§5 #21).
///
/// FAIL-WITHOUT: this widget exists only because the on-navy inversion is
/// where the bugs are — if the dots stop following `JeebSurfaceTone` the
/// selected tier on 08 paints orange-on-navy empties and a `surfaceContainer`
/// grey that vanishes into the card.
void main() {
  final ThemeData theme = AppTheme.light();
  final ColorScheme scheme = theme.colorScheme;
  final Color accent = theme.extension<JeebColorRoles>()!.accent;
  final Color muted = theme.extension<JeebSemanticColors>()!.mutedText;

  List<BoxDecoration> dots(WidgetTester tester) =>
      boxesUnder(tester, find.byType(JeebPriceMeter)).toList();

  group('light surface', () {
    testWidgets('draws 4 Ø7 dots, the first level filled with accent',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebPriceMeter(level: 3, caption: 'Higher price'),
        ),
      );

      final List<BoxDecoration> painted = dots(tester);
      expect(painted, hasLength(4));
      expect(
        painted.map((BoxDecoration d) => d.color).toList(),
        <Color>[accent, accent, accent, scheme.surfaceContainerHighest],
      );
      expect(painted.every((BoxDecoration d) => d.shape == BoxShape.circle),
          isTrue);

      final Finder firstDot = find
          .descendant(
            of: find.byType(JeebPriceMeter),
            matching: find.byType(DecoratedBox),
          )
          .first;
      expect(tester.getSize(firstDot), const Size(7, 7));
    });

    testWidgets('captions at 10.5 / w700 / mutedText', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebPriceMeter(level: 4, caption: 'Highest price'),
        ),
      );

      final TextStyle style =
          tester.widget<Text>(find.text('Highest price')).style!;
      expect(style.fontSize, 10.5);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, muted);
    });

    testWidgets('clamps the level to the dot count', (tester) async {
      await tester.pumpWidget(
        wrapMeter(const JeebPriceMeter(level: 9, caption: 'Highest price')),
      );
      expect(
        dots(tester).every((BoxDecoration d) => d.color == accent),
        isTrue,
      );

      await tester.pumpWidget(
        wrapMeter(const JeebPriceMeter(level: -2, caption: 'Lowest price')),
      );
      expect(
        dots(tester)
            .every((BoxDecoration d) => d.color == scheme.surfaceContainerHighest),
        isTrue,
      );
    });
  });

  group('on-navy inversion', () {
    testWidgets('inverts inside a JeebNavySurfaceCard', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebNavySurfaceCard(
            child: JeebPriceMeter(level: 2, caption: 'Balanced price'),
          ),
        ),
      );

      // 08 tpl 458-463: white / rgba(255,255,255,.25) dots, .7 caption.
      final Color onNavy = scheme.onPrimary;
      expect(
        dots(tester).map((BoxDecoration d) => d.color).toList(),
        <Color>[
          onNavy,
          onNavy,
          onNavy.withValues(alpha: 0.25),
          onNavy.withValues(alpha: 0.25),
        ],
      );
      expect(
        tester.widget<Text>(find.text('Balanced price')).style!.color,
        onNavy.withValues(alpha: 0.7),
      );
    });

    testWidgets('inverts via the selected state of an outlined card',
        (tester) async {
      // The consumer flips one enum on the card; the meter re-tones itself.
      await tester.pumpWidget(
        wrapMeter(
          const JeebOutlinedCard(
            state: JeebCardState.selected,
            child: JeebPriceMeter(level: 2, caption: 'Balanced price'),
          ),
        ),
      );

      expect(dots(tester).first.color, scheme.onPrimary);
      expect(
        tester.widget<Text>(find.text('Balanced price')).style!.color,
        scheme.onPrimary.withValues(alpha: 0.7),
      );
    });

    testWidgets('stays light inside a normal outlined card', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebOutlinedCard(
            child: JeebPriceMeter(level: 2, caption: 'Balanced price'),
          ),
        ),
      );

      expect(dots(tester).first.color, accent);
      expect(
        tester.widget<Text>(find.text('Balanced price')).style!.color,
        muted,
      );
    });
  });

  group('semantics', () {
    testWidgets('excludes the dots and leaves the caption as the signal',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebPriceMeter(level: 1, caption: 'Lowest price'),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(JeebPriceMeter),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(find.text('Lowest price'), findsOneWidget);
    });

    testWidgets('adds no node of its own without an identifier',
        (tester) async {
      // 08 nests this inside a tier row that owns `tier_option_<id>`; a bare
      // extra node between the container and its children breaks that.
      await tester.pumpWidget(
        wrapMeter(const JeebPriceMeter(level: 1, caption: 'Lowest price')),
      );

      expect(
        find.descendant(
          of: find.byType(JeebPriceMeter),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('applies the identifier via an explicit Semantics wrapper',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebPriceMeter(
            level: 1,
            caption: 'Lowest price',
            identifier: 'tier_price_meter_eco',
          ),
        ),
      );

      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebPriceMeter),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.properties.identifier, 'tier_price_meter_eco');
    });
  });

  group('RTL', () {
    testWidgets('the filled dots keep the start edge in both directions',
        (tester) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapMeter(
            const JeebPriceMeter(level: 1, caption: 'Lowest price'),
            direction: direction,
          ),
        );

        final Finder row = find.descendant(
          of: find.byType(JeebPriceMeter),
          matching: find.byType(Row),
        );
        final Finder firstDot = find
            .descendant(
              of: find.byType(JeebPriceMeter),
              matching: find.byType(DecoratedBox),
            )
            .first;

        expect(dots(tester).first.color, accent);
        if (direction == TextDirection.ltr) {
          expect(tester.getRect(firstDot).left, tester.getRect(row).left);
        } else {
          expect(tester.getRect(firstDot).right, tester.getRect(row).right);
        }
      }
    });

    testWidgets('the column end-aligns directionally', (tester) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapMeter(
            // A caption much wider than the dot row, so the alignment shows.
            const JeebPriceMeter(level: 1, caption: 'Lowest price of the lot'),
            direction: direction,
          ),
        );

        final Rect meter = tester.getRect(find.byType(JeebPriceMeter));
        final Rect row = tester.getRect(
          find.descendant(
            of: find.byType(JeebPriceMeter),
            matching: find.byType(Row),
          ),
        );
        if (direction == TextDirection.ltr) {
          expect(row.right, meter.right);
        } else {
          expect(row.left, meter.left);
        }
      }
    });
  });
}
