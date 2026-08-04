import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_page_dots.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #28, re-cut on the MIDNIGHT token sheet.
///
/// FAIL-WITHOUT: the active page is a **pill**, not a larger dot. If it
/// regresses to a circle, 01 silently looks like every other pager in the store
/// and `OmdsDotIndicator` (which cannot draw a pill) becomes the tempting fix.
void main() {
  // Token sheet §1/§3: accent `#D73B00`, `glassBorderVivid` white 22% — the
  // board draws the inactive dot at .20, which snaps to the vivid rung, not 14%.
  const Color accent = Color(0xFFD73B00);
  const Color inactive = Color(0x38FFFFFF);

  Size sizeOfDot(WidgetTester tester, int index) {
    final Finder dots = find.descendant(
      of: find.byType(JeebPageDots),
      matching: find.byType(AnimatedContainer),
    );
    return tester.getSize(dots.at(index));
  }

  Color colorOfDot(WidgetTester tester, int index) {
    final Finder dots = find.descendant(
      of: find.byType(JeebPageDots),
      matching: find.byType(AnimatedContainer),
    );
    final AnimatedContainer container =
        tester.widget<AnimatedContainer>(dots.at(index));
    return (container.decoration! as BoxDecoration).color!;
  }

  BorderRadius radiusOfDot(WidgetTester tester, int index) {
    final Finder dots = find.descendant(
      of: find.byType(JeebPageDots),
      matching: find.byType(AnimatedContainer),
    );
    final AnimatedContainer container =
        tester.widget<AnimatedContainer>(dots.at(index));
    return (container.decoration! as BoxDecoration).borderRadius!
        as BorderRadius;
  }

  group('JeebPageDots geometry', () {
    testWidgets('active is a 22x8 accent pill, inactive a Ø8 vivid-glass dot',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebPageDots(count: 3, activeIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(sizeOfDot(tester, 0), const Size(22, 8));
      expect(sizeOfDot(tester, 1), const Size(8, 8));
      expect(colorOfDot(tester, 0), accent);
      expect(colorOfDot(tester, 1), inactive);
      expect(radiusOfDot(tester, 0), BorderRadius.circular(999));
      expect(radiusOfDot(tester, 1), BorderRadius.circular(999));
    });

    testWidgets('gap is 7 between dots', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebPageDots(count: 3, activeIndex: 0)),
      );
      await tester.pumpAndSettle();

      final Finder dots = find.descendant(
        of: find.byType(JeebPageDots),
        matching: find.byType(AnimatedContainer),
      );
      final double gap = tester.getTopLeft(dots.at(2)).dx -
          tester.getTopRight(dots.at(1)).dx;
      expect(gap, closeTo(7, 0.01));
    });

    testWidgets('honours the plan reading when asked for it', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebPageDots(
            count: 2,
            activeIndex: 0,
            activeWidth: JeebPageDots.planActiveWidth,
            gap: 6,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sizeOfDot(tester, 0), const Size(28, 8));
    });

    testWidgets('clamps an out-of-range index instead of throwing',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebPageDots(count: 3, activeIndex: 9)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(sizeOfDot(tester, 2), const Size(22, 8));
    });

    testWidgets('renders nothing for an empty pager', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebPageDots(count: 0, activeIndex: 0)),
      );

      expect(
        find.descendant(
          of: find.byType(JeebPageDots),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
      );
    });
  });

  group('JeebPageDots semantics', () {
    testWidgets('surfaces the identifier and the spoken label', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(
          const JeebPageDots(
            count: 3,
            activeIndex: 1,
            identifier: 'onboarding_page_dots',
            semanticLabel: 'Page 2 of 3',
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('onboarding_page_dots'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsIdentifier('onboarding_page_dots'))
            .label,
        'Page 2 of 3',
      );
    });

    testWidgets('adds no node when the consumer owns the id', (tester) async {
      await tester.pumpWidget(
        wrapRemainder(const JeebPageDots(count: 3, activeIndex: 0)),
      );

      expect(
        find.descendant(
          of: find.byType(JeebPageDots),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('JeebPageDots RTL smoke', () {
    testWidgets('index 0 stays on the start edge in both directions',
        (tester) async {
      const Widget dots = JeebPageDots(count: 3, activeIndex: 0);

      await tester.pumpWidget(wrapRemainder(dots));
      await tester.pumpAndSettle();
      final Finder all = find.descendant(
        of: find.byType(JeebPageDots),
        matching: find.byType(AnimatedContainer),
      );
      // LTR: the pill is the leftmost.
      expect(
        tester.getCenter(all.at(0)).dx,
        lessThan(tester.getCenter(all.at(2)).dx),
      );

      await tester.pumpWidget(
        wrapRemainder(dots, direction: TextDirection.rtl),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // RTL: the same logical index 0 is now the rightmost — mirrored for free.
      expect(
        tester.getCenter(all.at(0)).dx,
        greaterThan(tester.getCenter(all.at(2)).dx),
      );
    });
  });

  testWidgets('survives a bare ThemeData.light() harness', (tester) async {
    await tester.pumpWidget(
      wrapUnthemed(const JeebPageDots(count: 3, activeIndex: 1)),
    );
    expect(tester.takeException(), isNull);
  });
}
