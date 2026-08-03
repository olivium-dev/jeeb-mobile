import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_card_test_harness.dart';

/// Gates for the MIDNIGHT emphasis surface (token sheet §4 hero glass).
///
/// FAIL-WITHOUT: the two things that silently break screens are (a) a shadow
/// appearing on 04's hero, and (b) a decorative ring laid out with
/// `Positioned(right:)` instead of `PositionedDirectional(end:)` — 19 §7.1
/// calls the latter a kit bug outright.
void main() {
  final ThemeData theme = AppTheme.midnight();
  final ColorScheme scheme = theme.colorScheme;
  final JeebSemanticColors semantics = theme.extension<JeebSemanticColors>()!;

  // Token sheet §3, typed out rather than read back off the implementation.
  const Color glassFillEmphasis = Color(0x1AFFFFFF);
  const Color glassBorderStrong = Color(0x29FFFFFF);

  group('JeebNavySurfaceCard surface', () {
    testWidgets('is emphasis glass with a 1px stroke and NO shadow',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebNavySurfaceCard(child: Text('hero'))),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebNavySurfaceCard));
      expect(decoration.color, glassFillEmphasis);
      final Border border = decoration.border! as Border;
      expect(border.top.color, glassBorderStrong);
      expect(border.top.width, 1);
      expect(decoration.boxShadow, JeebNavySurfaceCard.noShadow);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.lg));
    });

    testWidgets('takes a no-shadow hero (04) and a floating strip (19/23)',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebNavySurfaceCard(
            radius: 24,
            padding: EdgeInsetsDirectional.all(18),
            child: Text('hero'),
          ),
        ),
      );
      BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebNavySurfaceCard));
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(decoration.boxShadow, isEmpty);

      await tester.pumpWidget(
        wrapCard(
          const JeebNavySurfaceCard(
            radius: JeebRadii.xl,
            padding: EdgeInsets.all(20),
            shadow: JeebShadows.floatNav,
            child: Text('hero'),
          ),
        ),
      );
      decoration = decorationOf(tester, find.byType(JeebNavySurfaceCard));
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.xl));
      expect(decoration.boxShadow, JeebShadows.floatNav);
    });

    test('the kit-local shadows migrated off the dead navy-tinted set', () {
      // Selection is LIT, not lifted (R9/R22); the strip is a small float.
      expect(JeebNavySurfaceCard.selectedShadow, JeebShadows.glowRest);
      expect(JeebNavySurfaceCard.stripShadow, JeebShadows.overlay);
    });

    testWidgets('clips its content (overflow: hidden)', (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebNavySurfaceCard(child: Text('hero'))),
      );

      expect(
        find.descendant(
          of: find.byType(JeebNavySurfaceCard),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('publishes the navy tone to descendants', (tester) async {
      late JeebSurfaceToneData tone;
      await tester.pumpWidget(
        wrapCard(
          JeebNavySurfaceCard(
            child: ToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
          ),
        ),
      );

      expect(tone.kind, JeebSurfaceKind.navy);
      expect(tone.titleInk, scheme.onSurface);
      expect(tone.chipFill, semantics.glassFillPressed);
      expect(tone.mutedInk, semantics.inkSoft);
      expect(tone.meterEmpty, scheme.onSurface.withValues(alpha: 0.25));
      expect(tone.dividerInk, scheme.outlineVariant);
    });
  });

  group('JeebNavySurfaceCard decorative rings', () {
    testWidgets('renders nothing when rings is empty', (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebNavySurfaceCard(child: Text('hero'))),
      );
      expect(
        find.descendant(
          of: find.byType(JeebNavySurfaceCard),
          matching: find.byType(PositionedDirectional),
        ),
        findsNothing,
      );
    });

    testWidgets('04 hero ring is Ø140, accentRing stroked, 1.5px',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebNavySurfaceCard(
            radius: 24,
            rings: <JeebNavyRing>[JeebNavyRing.heroTopEnd],
            child: Text('hero'),
          ),
        ),
      );

      expect(tester.getSize(_rings()), const Size(140, 140));

      final Container ring = tester.widget<Container>(
        find.descendant(of: _rings(), matching: find.byType(Container)).first,
      );
      final BoxDecoration decoration = ring.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect((decoration.border! as Border).top.color, semantics.accentRing);
      expect((decoration.border! as Border).top.width, 1.5);
    });

    testWidgets('the corner is a parameter — 23 is bottom-END, not top-END',
        (tester) async {
      expect(JeebNavyRing.statBottomEnd.bottom, -50);
      expect(JeebNavyRing.statBottomEnd.top, isNull);
      expect(JeebNavyRing.statBottomEnd.diameter, 170);
      expect(JeebNavyRing.statTopEnd.top, -50);
      expect(JeebNavyRing.statTopEnd.diameter, 160);
      expect(JeebNavyRing.heroTopEnd.diameter, 140);

      await tester.pumpWidget(
        wrapCard(
          const JeebNavySurfaceCard(
            radius: 20,
            rings: <JeebNavyRing>[JeebNavyRing.statBottomEnd],
            child: SizedBox(height: 120),
          ),
        ),
      );

      final double cardBottom =
          tester.getBottomRight(find.byType(JeebNavySurfaceCard)).dy;
      final double ringBottom = tester.getBottomRight(_rings()).dy;
      expect(ringBottom - cardBottom, closeTo(50, 0.01));
    });

    testWidgets('02 band rings use the ink at 8%', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebNavySurfaceCard.topBand(
            rings: <JeebNavyRing>[
              JeebNavyRing.bandOuter,
              JeebNavyRing.bandInner,
            ],
            child: Text('hero'),
          ),
        ),
      );

      final Iterable<Container> rings = tester.widgetList<Container>(
        find.descendant(of: _rings(), matching: find.byType(Container)),
      );
      final List<Color> inks = rings
          .map((Container c) =>
              ((c.decoration! as BoxDecoration).border! as Border).top.color)
          .toList();
      expect(inks.first, scheme.onSurface.withValues(alpha: 0.08));
      expect(inks.last, semantics.accentRing);
    });
  });

  group('JeebNavySurfaceCard.topBand', () {
    testWidgets('is bottom-radius only and folds in the status-bar inset',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: 44)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: JeebNavySurfaceCard.topBand(child: Text('hero')),
            ),
          ),
        ),
      );

      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebNavySurfaceCard));
      expect(
        decoration.borderRadius,
        const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(JeebRadii.hero),
          bottomEnd: Radius.circular(JeebRadii.hero),
        ),
      );
      expect(
        decoration.border,
        isNull,
        reason: 'a full-bleed band has no edges to stroke',
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebNavySurfaceCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      // 16 (band top) + 44 (status bar).
      expect(padding.padding.resolve(TextDirection.ltr).top, 60);
      expect(padding.padding.resolve(TextDirection.ltr).bottom, 32);
    });
  });

  group('JeebNavySurfaceCard semantics', () {
    testWidgets('surfaces the identifier with container + explicitChildNodes',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebNavySurfaceCard(
            identifier: 'wallet_hero',
            semanticLabel: 'Available to bid',
            onTap: () {},
            child: const Text('hero'),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('wallet_hero'), findsOneWidget);
      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebNavySurfaceCard),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.container, isTrue);
      expect(node.explicitChildNodes, isTrue);
      expect(node.properties.button, isTrue);
    });

    testWidgets('adds no node at all when the consumer owns the id',
        (tester) async {
      // 23 nests `Semantics(identifier: wallet_available_balance)` INSIDE the
      // card so the decorative ring stays out of the node.
      await tester.pumpWidget(
        wrapCard(
          JeebNavySurfaceCard(
            rings: const <JeebNavyRing>[JeebNavyRing.statBottomEnd],
            child: Semantics(
              identifier: 'wallet_available_balance',
              container: true,
              explicitChildNodes: true,
              child: const Text('\$6.40'),
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(JeebNavySurfaceCard),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
        reason: 'only the consumer node — the card adds none',
      );
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCard(
          JeebNavySurfaceCard(
            onTap: () => taps++,
            child: const Text('hero'),
          ),
        ),
      );
      await tester.tap(find.text('hero'));
      expect(taps, 1);
    });
  });

  group('JeebNavySurfaceCard RTL smoke', () {
    testWidgets('the top-END ring mirrors to the start edge under RTL',
        (tester) async {
      const Widget card = JeebNavySurfaceCard(
        radius: 24,
        rings: <JeebNavyRing>[JeebNavyRing.heroTopEnd],
        child: SizedBox(height: 90),
      );

      await tester.pumpWidget(wrapCard(card));
      final double ltrOverhang = tester.getBottomRight(_rings()).dx -
          tester.getBottomRight(find.byType(JeebNavySurfaceCard)).dx;

      await tester.pumpWidget(wrapCard(card, direction: TextDirection.rtl));
      expect(tester.takeException(), isNull);
      final double rtlOverhang =
          tester.getTopLeft(find.byType(JeebNavySurfaceCard)).dx -
              tester.getTopLeft(_rings()).dx;

      expect(ltrOverhang, closeTo(40, 0.01));
      expect(rtlOverhang, closeTo(40, 0.01),
          reason: 'PositionedDirectional(end:), never Positioned(right:)');
    });

    testWidgets('topBand renders in RTL without exception', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebNavySurfaceCard.topBand(
            rings: <JeebNavyRing>[JeebNavyRing.bandInner],
            child: Text('hero'),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// The decorative ring wrappers of the card under test. Scoped, because
/// `ModalRoute` puts its own `IgnorePointer` above every route.
Finder _rings() => find.descendant(
      of: find.byType(JeebNavySurfaceCard),
      matching: find.byType(IgnorePointer),
    );
