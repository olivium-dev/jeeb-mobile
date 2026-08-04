import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';

import 'jeeb_meters_test_harness.dart';

/// Gates for the progress track (§5 #20).
///
/// FAIL-WITHOUT: a hard `left:` inverts the playhead under `ar` (06's stated
/// kit ask); a non-nullable value makes 11 fabricate a fraction it does not
/// have; a knob that clips loses its shadow and overflows its own box.
void main() {
  final ColorScheme scheme = AppTheme.midnight().colorScheme;
  final Color accent = AppTheme.midnight().extension<JeebColorRoles>()!.accent;
  // Token sheet §2 accent / §1 onPrimary.
  const Color midnightAccent = Color(0xFFD73B00);
  const Color midnightOnAccent = Color(0xFFFFFFFF);

  Finder trackBox() => find
      .descendant(of: find.byType(JeebMeter), matching: find.byType(DecoratedBox))
      .first;

  Finder fillBox() => find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      );

  // `Center` IS an `Align`, so every finder below has to be scoped to the
  // widget under test.
  Finder knobBox() => find.descendant(
        of: find.descendant(
          of: find.byType(JeebMeter),
          matching: find.byType(Align),
        ),
        matching: find.byType(DecoratedBox),
      );

  group('bar', () {
    testWidgets('defaults to 11 measured 70x5 r9, accent over highest',
        (tester) async {
      await tester.pumpWidget(wrapMeter(const JeebMeter(value: 0.65)));

      expect(tester.getSize(find.byType(JeebMeter)), const Size(70, 5));

      final BoxDecoration track = boxOf(tester, trackBox());
      expect(track.color, scheme.surfaceContainerHighest);
      expect(track.borderRadius, BorderRadius.circular(JeebRadii.sm));
      expect(JeebRadii.sm, 9);

      expect(boxOf(tester, fillBox()).color, accent);
      expect(accent, midnightAccent);
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        0.65,
      );
    });

    testWidgets('a null value renders the track with no fill', (tester) async {
      // 11's window total is session-observed; the honest degraded state is
      // track-only, never a fabricated fraction.
      await tester.pumpWidget(wrapMeter(const JeebMeter()));

      expect(find.byType(FractionallySizedBox), findsNothing);
      expect(boxOf(tester, trackBox()).color, scheme.surfaceContainerHighest);
    });

    testWidgets('clamps out-of-range values', (tester) async {
      await tester.pumpWidget(wrapMeter(const JeebMeter(value: 1.4)));
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        1.0,
      );

      await tester.pumpWidget(wrapMeter(const JeebMeter(value: -0.3)));
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        0.0,
      );
    });

    testWidgets('explicit colours win over the tone', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          JeebMeter(
            value: 0.5,
            trackColor: scheme.errorContainer,
            fillColor: scheme.error,
          ),
        ),
      );

      expect(boxOf(tester, trackBox()).color, scheme.errorContainer);
      expect(boxOf(tester, fillBox()).color, scheme.error);
    });
  });

  group('surface tone', () {
    testWidgets('inverts on a navy card without being asked', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebNavySurfaceCard(child: JeebMeter(value: 0.5)),
        ),
      );

      // Emphasis glass: the meter goes ink-on-glass, not accent-on-navy.
      expect(boxOf(tester, fillBox()).color, scheme.onSurface);
      expect(scheme.onSurface, const Color(0xFFEDEFFC));
      expect(
        boxOf(tester, trackBox()).color,
        scheme.onSurface.withValues(alpha: 0.25),
      );
    });
  });

  group('scrubber', () {
    testWidgets('reserves the knob height and paints the Ø14 white knob',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(const JeebMeter.scrubber(value: 0.55)),
      );

      // Full width of the 320 harness slot, 14 tall (not 5) so the knob and
      // its shadow live inside the widget's own box.
      expect(tester.getSize(find.byType(JeebMeter)), const Size(320, 14));

      expect(tester.getSize(knobBox()), const Size(14, 14));

      final BoxDecoration decoration = boxOf(tester, knobBox());
      // Midnight board R6: the knob is white on the orange fill, not tinted.
      expect(decoration.color, midnightOnAccent);
      expect(decoration.shape, BoxShape.circle);

      // Token sheet §7 `overlay` — `0 2px 8px rgba(0,0,0,.4)`.
      expect(decoration.boxShadow, JeebShadows.overlay);
      final BoxShadow shadow = decoration.boxShadow!.single;
      expect(shadow.color, const Color.fromRGBO(0, 0, 0, 0.40));
      expect(shadow.color.a, closeTo(JeebMeter.knobShadowOpacity, 0.005));
      expect(shadow.offset, const Offset(0, 2));
      expect(shadow.blurRadius, 8);
    });

    testWidgets('the knob stays white on a navy card', (tester) async {
      // It rides on the accent fill, so `onAccent` is right on both tones.
      await tester.pumpWidget(
        wrapMeter(
          const JeebNavySurfaceCard(child: JeebMeter.scrubber(value: 0.5)),
        ),
      );

      expect(boxOf(tester, knobBox()).color, midnightOnAccent);
    });

    testWidgets('never clips the knob', (tester) async {
      await tester.pumpWidget(
        wrapMeter(const JeebMeter.scrubber(value: 1)),
      );

      expect(
        tester
            .widget<Stack>(
              find.descendant(
                of: find.byType(JeebMeter),
                matching: find.byType(Stack),
              ),
            )
            .clipBehavior,
        Clip.none,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops the knob when the value is null', (tester) async {
      await tester.pumpWidget(wrapMeter(const JeebMeter.scrubber()));

      expect(
        find.descendant(
          of: find.byType(JeebMeter),
          matching: find.byType(Align),
        ),
        findsNothing,
      );
    });

    testWidgets('is not a gesture target without onSeek', (tester) async {
      // A knob with no seek handler is a display-only mark, not a false
      // affordance (06 degrades to exactly this).
      await tester.pumpWidget(
        wrapMeter(const JeebMeter.scrubber(value: 0.55)),
      );

      expect(
        find.descendant(
          of: find.byType(JeebMeter),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('onSeek reports the tapped fraction in ltr', (tester) async {
      final List<double> seeks = <double>[];
      await tester.pumpWidget(
        wrapMeter(
          JeebMeter.scrubber(value: 0.1, onSeek: seeks.add),
        ),
      );

      final Rect rect = tester.getRect(find.byType(JeebMeter));
      await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));

      expect(seeks.single, closeTo(0.25, 0.01));
    });

    testWidgets('onSeek mirrors the fraction under rtl', (tester) async {
      final List<double> seeks = <double>[];
      await tester.pumpWidget(
        wrapMeter(
          JeebMeter.scrubber(value: 0.1, onSeek: seeks.add),
          direction: TextDirection.rtl,
          locale: const Locale('ar'),
        ),
      );

      final Rect rect = tester.getRect(find.byType(JeebMeter));
      // A quarter in from the LEFT is three quarters through the track when
      // the start edge is on the right.
      await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));

      expect(seeks.single, closeTo(0.75, 0.01));
    });
  });

  group('segmented', () {
    testWidgets('fills the leading n segments at h6 gap 8', (tester) async {
      await tester.pumpWidget(
        wrapMeter(const JeebMeter.segmented(steps: 2, filled: 1)),
      );

      final List<BoxDecoration> cells =
          boxesUnder(tester, find.byType(JeebMeter)).toList();
      expect(cells, hasLength(2));
      expect(cells.first.color, accent);
      expect(cells.last.color, scheme.surfaceContainerHighest);
      expect(cells.first.borderRadius, BorderRadius.circular(JeebRadii.sm));

      final Rect first = tester.getRect(
        find
            .descendant(
              of: find.byType(JeebMeter),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(first.height, 6);
      // 320 slot, 2 cells, one 8px gap.
      expect(first.width, 156);
    });
  });

  group('semantics', () {
    testWidgets('adds no node of its own by default', (tester) async {
      // 06 owns the node (`Semantics(slider: true, value: …)`); a nested one
      // would split the announcement.
      await tester.pumpWidget(wrapMeter(const JeebMeter(value: 0.5)));

      expect(
        find.descendant(
          of: find.byType(JeebMeter),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('applies the identifier via an explicit Semantics wrapper',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebMeter(
            value: 0.5,
            identifier: 'offer_review_window_meter',
            semanticLabel: 'Window closing',
          ),
        ),
      );

      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebMeter),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.properties.identifier, 'offer_review_window_meter');
      expect(node.properties.label, 'Window closing');
    });
  });

  group('RTL', () {
    testWidgets('the fill grows from the start edge in both directions',
        (tester) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapMeter(
            const JeebMeter(value: 0.5),
            direction: direction,
          ),
        );

        final Rect track = tester.getRect(find.byType(JeebMeter));
        final Rect fill = tester.getRect(fillBox());
        expect(fill.width, closeTo(35, 0.01));
        if (direction == TextDirection.ltr) {
          expect(fill.left, track.left);
        } else {
          expect(fill.right, track.right);
        }
      }
    });

    testWidgets('the scrubber knob mirrors with the playhead', (tester) async {
      final Map<TextDirection, double> knobCentre = <TextDirection, double>{};
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapMeter(
            const JeebMeter.scrubber(value: 0.25),
            direction: direction,
          ),
        );
        knobCentre[direction] = tester.getRect(knobBox()).center.dx -
            tester.getRect(find.byType(JeebMeter)).left;
      }

      // 320 wide: a quarter in from the start is x≈80 in ltr and x≈240 in rtl.
      expect(knobCentre[TextDirection.ltr]!, lessThan(160));
      expect(knobCentre[TextDirection.rtl]!, greaterThan(160));
    });

    testWidgets('segments mirror under rtl', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebMeter.segmented(steps: 2, filled: 1),
          direction: TextDirection.rtl,
          locale: const Locale('ar'),
        ),
      );

      final Finder cells = find.descendant(
        of: find.byType(JeebMeter),
        matching: find.byType(DecoratedBox),
      );
      // The filled segment is still first in the list and now sits on the
      // right — a plain Row, no positional maths.
      expect(boxOf(tester, cells.first).color, accent);
      expect(
        tester.getRect(cells.first).right,
        tester.getRect(find.byType(JeebMeter)).right,
      );
    });
  });
}
