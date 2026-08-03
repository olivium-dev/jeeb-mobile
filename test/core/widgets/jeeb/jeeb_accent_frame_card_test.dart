import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #5.
///
/// FAIL-WITHOUT: the frame form must stay a `JeebOutlinedCard` with a different
/// stroke. The moment it paints its own surface it becomes a fourth card
/// primitive and 16/18/20/24 start drifting from 08/11/23 on radius, padding
/// and semantics.
void main() {
  final ThemeData theme = AppTheme.light();
  final ColorScheme scheme = theme.colorScheme;
  final JeebColorRoles roles = theme.extension<JeebColorRoles>()!;

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
      expect(decoration.color, scheme.surface);
      expect(decoration.boxShadow, isNull);
      final Border border = decoration.border! as Border;
      expect(border.top.color, roles.accent);
      expect(border.top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('carries radius and padding through (18 §T7, 24 §5)',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebAccentFrameCard(
            radius: 18,
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
      expect(card.radius, 18);
      expect(card.borderWidth, 2);
      expect(
        remainderDecorationOf(tester, find.byType(JeebAccentFrameCard))
            .borderRadius,
        BorderRadius.circular(18),
      );
    });

    testWidgets('keeps the light tone — an orange frame is not an orange fill',
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
      expect(tone.titleInk, scheme.onSurface);
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

  group('JeebAccentFrameCard.filled', () {
    testWidgets('is an accent surface with the accentBanner shadow (13)',
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
      expect(decoration.color, roles.accent);
      expect(decoration.boxShadow, JeebShadows.accentBanner);
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, BorderRadius.circular(16));
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
      expect(tone.titleInk, roles.onAccent);
      expect(tone.mutedInk, roles.onAccent.withValues(alpha: 0.7));
      expect(tone.chipFill, roles.onAccent.withValues(alpha: 0.14));
      expect(tone.meterEmpty, roles.onAccent.withValues(alpha: 0.25));
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
