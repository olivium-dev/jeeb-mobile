import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #5, re-cut on the MIDNIGHT token sheet.
///
/// FAIL-WITHOUT: the frame form must stay a `JeebOutlinedCard` with a different
/// stroke. The moment it paints its own surface it becomes a fourth card
/// primitive and 16/18/20/24 start drifting from 08/11/23 on radius, padding
/// and semantics. The card's own FILL is asserted by the card lane's harness,
/// not here — this file owns the stroke, the radius and the shadow.
void main() {
  // Token sheet §1/§2: accent `#D73B00`, `onAccent` `#FFFFFF`, ink `#EDEFFC`.
  const Color accent = Color(0xFFD73B00);
  const Color onAccent = Color(0xFFFFFFFF);
  const Color ink = Color(0xFFEDEFFC);

  group('JeebAccentFrameCard frame form', () {
    testWidgets('is a JeebOutlinedCard with a 2px accent stroke and no shadow',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebAccentFrameCard(child: Text('body')),
        ),
      );

      expect(
        find.byType(JeebOutlinedCard),
        findsOneWidget,
        reason: 'one card implementation, not a fourth primitive',
      );

      final BoxDecoration decoration =
          remainderDecorationOf(tester, find.byType(JeebAccentFrameCard));
      expect(decoration.boxShadow, isNull);
      final Border border = decoration.border! as Border;
      expect(border.top.color, accent);
      expect(border.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.lg));
    });

    testWidgets('carries a non-default radius and padding through',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebAccentFrameCard(
            radius: JeebRadii.xl,
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Text('body'),
          ),
        ),
      );

      final JeebOutlinedCard card =
          tester.widget<JeebOutlinedCard>(find.byType(JeebOutlinedCard));
      expect(card.radius, JeebRadii.xl);
      expect(card.borderWidth, 2);
      expect(
        remainderDecorationOf(tester, find.byType(JeebAccentFrameCard))
            .borderRadius,
        BorderRadius.circular(JeebRadii.xl),
      );
    });

    testWidgets('keeps the rest tone — an orange frame is not an orange fill',
        (tester) async {
      late JeebSurfaceToneData tone;
      await tester.pumpWidget(
        wrapRemainder(
          JeebAccentFrameCard(
            child: RemainderToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
          ),
        ),
      );

      expect(tone.kind, JeebSurfaceKind.light);
      expect(tone.titleInk, ink);
    });

    testWidgets('is tappable and surfaces its identifier', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapRemainder(
          JeebAccentFrameCard(
            identifier: 'settings-row-become-jeeber',
            semanticLabel: 'Become a Jeeber',
            onTap: () => taps++,
            child: const Text('body'),
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('settings-row-become-jeeber'),
        findsOneWidget,
      );
      await tester.tap(find.text('body'));
      expect(taps, 1);
    });
  });

  group('JeebAccentFrameCard frame fill (wave-C ruling 10)', () {
    Color fillOf(WidgetTester tester) =>
        remainderDecorationOf(tester, find.byType(JeebAccentFrameCard)).color!;

    testWidgets('defaults to rest glass — a frame is not a fill',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebAccentFrameCard(child: Text('body'))),
      );

      expect(
        tester
            .widget<JeebAccentFrameCard>(find.byType(JeebAccentFrameCard))
            .fill,
        JeebAccentFrameFill.glass,
      );
      expect(fillOf(tester), JeebMidnight.glassFill);
    });

    testWidgets('accentTint is the measured orange 12% (R21 in-motion row)',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebAccentFrameCard(
            fill: JeebAccentFrameFill.accentTint,
            child: Text('body'),
          ),
        ),
      );

      expect(fillOf(tester), JeebMidnight.accentTint);
      // Still the outlined card, still the 2px accent stroke, still no lift —
      // only the fill rung moved.
      expect(find.byType(JeebOutlinedCard), findsOneWidget);
      final BoxDecoration decoration =
          remainderDecorationOf(tester, find.byType(JeebAccentFrameCard));
      expect((decoration.border! as Border).top.color, accent);
      expect((decoration.border! as Border).top.width, 2);
      expect(decoration.boxShadow, isNull);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(JeebRadii.lg),
      );
    });

    testWidgets('accentSelected offers R9\'s 20% rung without R9\'s glow',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebAccentFrameCard(
            fill: JeebAccentFrameFill.accentSelected,
            child: Text('body'),
          ),
        ),
      );

      expect(fillOf(tester), JeebMidnight.accentSelectedFill);
      expect(
        remainderDecorationOf(tester, find.byType(JeebAccentFrameCard))
            .boxShadow,
        isNull,
        reason: 'the lit glow belongs to JeebCardState.accentSelected, not here',
      );
    });

    testWidgets('the tint reaches the card and NOT its content',
        (tester) async {
      late Color inner;
      await tester.pumpWidget(
        wrapRemainder(
          JeebAccentFrameCard(
            fill: JeebAccentFrameFill.accentTint,
            child: Builder(
              builder: (BuildContext context) {
                inner = Theme.of(context)
                    .extension<JeebSemanticColors>()!
                    .glassFill;
                return const Text('body');
              },
            ),
          ),
        ),
      );

      expect(fillOf(tester), JeebMidnight.accentTint);
      // A nested kit widget must still read the true glass ladder, or every
      // card inside a tinted frame turns orange too.
      expect(inner, JeebMidnight.glassFill);
    });

    testWidgets('a tinted frame keeps the rest tone and the padding correction',
        (tester) async {
      late JeebSurfaceToneData tone;
      await tester.pumpWidget(
        wrapRemainder(
          JeebAccentFrameCard(
            fill: JeebAccentFrameFill.accentTint,
            child: RemainderToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
          ),
        ),
      );

      expect(tone.kind, JeebSurfaceKind.light);
      expect(tone.titleInk, ink);
      // 13/16 plus the 2px border-box stroke, exactly as the glass frame.
      expect(
        tester
            .widget<Padding>(
              find
                  .descendant(
                    of: find.byType(JeebOutlinedCard),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding
            .resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      );
    });

    testWidgets('the filled banner ignores the rung', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebAccentFrameCard.filled(child: Text('body'))),
      );

      expect(
        tester
            .widget<JeebAccentFrameCard>(find.byType(JeebAccentFrameCard))
            .fill,
        JeebAccentFrameFill.glass,
      );
      expect(fillOf(tester), accent);
    });

    testWidgets('a tinted frame survives a bare ThemeData.light() harness',
        (tester) async {
      await tester.pumpWidget(
        wrapUnthemed(
          const JeebAccentFrameCard(
            fill: JeebAccentFrameFill.accentTint,
            child: Text('frame'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(fillOf(tester), JeebMidnight.accentTint);
    });
  });

  group('JeebAccentFrameCard.filled', () {
    testWidgets('is an accent surface with the ctaOrange shadow (13)',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebAccentFrameCard.filled(child: Text('body')),
        ),
      );

      expect(
        find.byType(JeebOutlinedCard),
        findsNothing,
        reason: 'no primitive has an accent fill, so this form paints its own',
      );

      final BoxDecoration decoration =
          remainderDecorationOf(tester, find.byType(JeebAccentFrameCard));
      expect(decoration.color, accent);
      expect(
        decoration.boxShadow,
        JeebShadows.ctaOrange,
        reason: 'the navy-tinted accentBanner is dead (§7 migration map)',
      );
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.lg));
    });

    testWidgets('defaults to 14/16 padding (tpl 799)', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebAccentFrameCard.filled(child: Text('body'))),
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebAccentFrameCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      // No border-box correction here: the filled form has no stroke.
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    });

    testWidgets('re-tones its subtree to light ink, like a navy card',
        (tester) async {
      late JeebSurfaceToneData tone;
      await tester.pumpWidget(
        wrapRemainder(
          JeebAccentFrameCard.filled(
            child: RemainderToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
          ),
        ),
      );

      expect(tone.onNavy, isTrue, reason: 'a saturated fill needs light ink');
      expect(tone.titleInk, onAccent);
      expect(tone.mutedInk, onAccent.withValues(alpha: 0.7));
      expect(tone.chipFill, onAccent.withValues(alpha: 0.14));
      expect(tone.meterEmpty, onAccent.withValues(alpha: 0.25));
    });

    testWidgets('adds no Semantics node when the consumer owns the id',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebAccentFrameCard.filled(child: Text('body'))),
      );

      expect(
        find.descendant(
          of: find.byType(JeebAccentFrameCard),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('JeebAccentFrameCard RTL smoke', () {
    testWidgets('directional padding mirrors in both forms', (tester) async {
      const Key probe = Key('probe');
      const EdgeInsetsGeometry lopsided =
          EdgeInsetsDirectional.fromSTEB(32, 8, 4, 8);
      const Widget body = Row(
        children: <Widget>[SizedBox(key: probe, width: 20, height: 20)],
      );

      for (final (Widget card, double stroke) in <(Widget, double)>[
        (const JeebAccentFrameCard(padding: lopsided, child: body), 2),
        (const JeebAccentFrameCard.filled(padding: lopsided, child: body), 0),
      ]) {
        await tester.pumpWidget(wrapRemainder(card));
        final double ltrGap = tester.getTopLeft(find.byKey(probe)).dx -
            tester.getTopLeft(find.byType(JeebAccentFrameCard)).dx;

        await tester.pumpWidget(
          wrapRemainder(card, direction: TextDirection.rtl),
        );
        expect(tester.takeException(), isNull);
        final double rtlGap =
            tester.getTopRight(find.byType(JeebAccentFrameCard)).dx -
                tester.getTopRight(find.byKey(probe)).dx;

        expect(ltrGap, closeTo(32 + stroke, 0.01));
        expect(rtlGap, closeTo(32 + stroke, 0.01));
      }
    });
  });

  testWidgets('both forms survive a bare ThemeData.light() harness',
      (tester) async {
    await tester.pumpWidget(
      wrapUnthemed(
        const Column(
          children: <Widget>[
            JeebAccentFrameCard(child: Text('frame')),
            JeebAccentFrameCard.filled(child: Text('filled')),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
