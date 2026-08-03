// `jDash` — stroke-dashoffset → −40, 2s linear ∞.
//
// Two things have to be right and neither is visible from a screenshot:
//
//   * the SIGN convention — a decreasing offset must walk the dashes FORWARD
//     along the path, as SVG does, which is why the board writes −40 rather
//     than +40. Get it backwards and the map route crawls towards the client;
//   * the loop must be SEAMLESS — the dash pattern after a full −40 travel has
//     to be pixel-identical to the pattern at 0, or the route visibly stutters
//     twice a second.

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';

Path _line({double length = 100}) => Path()
  ..moveTo(0, 0)
  ..lineTo(length, 0);

/// Total inked length of [path] and how many dashes it is cut into.
({double inked, int dashes}) _measure(Path path) {
  double inked = 0;
  int dashes = 0;
  for (final PathMetric metric in path.computeMetrics()) {
    inked += metric.length;
    dashes++;
  }
  return (inked: inked, dashes: dashes);
}

void main() {
  group('JDashedPathPainter.dashed — geometry', () {
    test('cuts a 100px line into 5/5 dashes', () {
      final Path dashed = JDashedPathPainter.dashed(
        _line(),
        dashLength: 5,
        gapLength: 5,
      );
      final ({double inked, int dashes}) measured = _measure(dashed);
      expect(measured.dashes, 10);
      expect(measured.inked, closeTo(50, 0.01));
      expect(dashed.getBounds().left, closeTo(0, 0.01));
    });

    test('a negative offset walks the dashes forward along the path', () {
      final Path dashed = JDashedPathPainter.dashed(
        _line(),
        dashLength: 5,
        gapLength: 5,
        dashOffset: -5,
      );
      // The first dash has moved 5px along the path, not backwards off it.
      expect(dashed.getBounds().left, closeTo(5, 0.01));
      expect(_measure(dashed).inked, closeTo(50, 0.01));
    });

    test('one full −40 travel is seamless with offset 0', () {
      final ({double inked, int dashes}) start = _measure(
        JDashedPathPainter.dashed(_line(), dashLength: 5, gapLength: 5),
      );
      final Path wrapped = JDashedPathPainter.dashed(
        _line(),
        dashLength: JeebMotion.dashLength,
        gapLength: JeebMotion.dashGap,
        dashOffset: JeebMotion.dashTravel,
      );
      final ({double inked, int dashes}) end = _measure(wrapped);
      expect(end.dashes, start.dashes);
      expect(end.inked, closeTo(start.inked, 0.01));
      expect(wrapped.getBounds().left, closeTo(0, 0.01));
    });

    test('an empty path yields no dashes', () {
      expect(
        _measure(
          JDashedPathPainter.dashed(Path(), dashLength: 5, gapLength: 5),
        ).dashes,
        0,
      );
    });
  });

  group('JDashOffset — 0 → −40 over 2s, linear ∞', () {
    testWidgets('travels the full −40 in one period, then restarts', (
      WidgetTester tester,
    ) async {
      Animation<double>? offset;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: JDashOffset(
              builder:
                  (
                    BuildContext context,
                    Animation<double> dashOffset,
                    Widget? child,
                  ) {
                    offset = dashOffset;
                    return const SizedBox.shrink();
                  },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(offset!.value, 0);
      // Linear: a quarter of the period is a quarter of the travel.
      await tester.pump(JeebMotion.dashDuration ~/ 4);
      expect(offset!.value, closeTo(-10, 0.01));
      await tester.pump(JeebMotion.dashDuration ~/ 4);
      expect(offset!.value, closeTo(-20, 0.01));
      await tester.pump(
        JeebMotion.dashDuration ~/ 2 - const Duration(milliseconds: 10),
      );
      expect(offset!.value, closeTo(-39.8, 0.05));
      await tester.pump(const Duration(milliseconds: 10));
      expect(offset!.value, closeTo(0, 0.01), reason: 'wrapped, seamlessly');
    });

    testWidgets('disableAnimations pins the offset at 0 (still dashes)', (
      WidgetTester tester,
    ) async {
      Animation<double>? offset;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: JDashOffset(
              builder:
                  (
                    BuildContext context,
                    Animation<double> dashOffset,
                    Widget? child,
                  ) {
                    offset = dashOffset;
                    return const SizedBox.shrink();
                  },
            ),
          ),
        ),
      );

      expect(offset!.value, 0);
      await tester.pump(JeebMotion.dashDuration);
      expect(offset!.value, 0);
      await tester.pumpAndSettle();
      expect(offset!.value, 0);
    });
  });

  group('JDashedPath — the ready widget', () {
    Future<JDashedPathPainter> pumpPath(
      WidgetTester tester,
      Widget path, {
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SizedBox(width: 200, height: 200, child: path)),
          ),
        ),
      );
      await tester.pump();
      return tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(JDashedPath),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as JDashedPathPainter;
    }

    testWidgets('.line dashes across the vertical centre and marches', (
      WidgetTester tester,
    ) async {
      final JDashedPathPainter painter = await pumpPath(
        tester,
        const JDashedPath.line(color: Color(0xFF8A93D8)),
      );

      expect(
        painter.pathBuilder(const Size(200, 200)).getBounds().center.dy,
        100,
      );
      expect(painter.dashOffset.value, 0);
      await tester.pump(JeebMotion.dashDuration ~/ 2);
      expect(painter.dashOffset.value, closeTo(-20, 0.01));
    });

    testWidgets('.oval inscribes the ring in its box', (
      WidgetTester tester,
    ) async {
      final JDashedPathPainter painter = await pumpPath(
        tester,
        const JDashedPath.oval(color: Color(0xFF8A93D8)),
      );
      expect(
        painter.pathBuilder(const Size(200, 200)).getBounds(),
        const Rect.fromLTWH(0, 0, 200, 200),
      );
    });

    testWidgets('renders statically under disableAnimations', (
      WidgetTester tester,
    ) async {
      final JDashedPathPainter painter = await pumpPath(
        tester,
        const JDashedPath.line(color: Color(0xFF8A93D8)),
        disableAnimations: true,
      );
      await tester.pump(JeebMotion.dashDuration);
      expect(painter.dashOffset.value, 0);
      await tester.pumpAndSettle();
      expect(painter.dashOffset.value, 0);
    });
  });
}
