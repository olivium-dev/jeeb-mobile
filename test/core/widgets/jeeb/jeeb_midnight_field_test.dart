// The field is the one widget every Midnight screen mounts, so its contracts
// are pinned here: variant → layer set, directional glow, reduce-motion rest,
// full-bleed child, and the §5 radii ladder it ships alongside.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';

const Key _fieldKey = Key('field');
const Size _fieldSize = Size(360, 560);

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required JeebFieldVariant variant,
    TextDirection direction = TextDirection.ltr,
    bool disableAnimations = false,
    Widget? child,
    JeebFieldGlowPlacement? glowPlacement,
    Color? glowColor,
    JeebFieldWashPlacement? washPlacement,
    bool? showRings,
    bool? showTwinkles,
    bool animateDecor = true,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: direction,
          child: Center(
            child: RepaintBoundary(
              key: _fieldKey,
              child: SizedBox.fromSize(
                size: _fieldSize,
                child: JeebMidnightField(
                  variant: variant,
                  glowPlacement: glowPlacement,
                  glowColor: glowColor,
                  washPlacement: washPlacement,
                  showRings: showRings,
                  showTwinkles: showTwinkles,
                  animateDecor: animateDecor,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Rasterises the field and returns a sampler over fractional coordinates.
  Future<Color Function(double, double)> sampler(WidgetTester tester) async {
    final RenderRepaintBoundary boundary = tester.renderObject(
      find.byKey(_fieldKey),
    );
    late final ByteData pixels;
    late final ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage();
      pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return (double fx, double fy) {
      final int x = (fx * (image.width - 1)).round();
      final int y = (fy * (image.height - 1)).round();
      final int i = (y * image.width + x) * 4;
      return Color.fromARGB(
        pixels.getUint8(i + 3),
        pixels.getUint8(i),
        pixels.getUint8(i + 1),
        pixels.getUint8(i + 2),
      );
    };
  }

  void expectColor(Color actual, Color expected, {double tolerance = 2 / 255}) {
    expect(actual.r, closeTo(expected.r, tolerance));
    expect(actual.g, closeTo(expected.g, tolerance));
    expect(actual.b, closeTo(expected.b, tolerance));
  }

  /// Walks radially across one orbit arc and returns the strongest red delta
  /// between two renders, with the blue delta of that same pixel — orange
  /// pushes blue DOWN, white pushes it up.
  ({double dr, double db}) arcDelta(
    Color Function(double, double) on,
    Color Function(double, double) off,
    double radiusFactor,
    double angleDegrees,
  ) {
    final Offset centre = Offset(0.90 * _fieldSize.width, 0.05 * _fieldSize.height);
    final double radius = radiusFactor * _fieldSize.width;
    final double angle = angleDegrees * math.pi / 180;
    double dr = 0;
    double db = 0;
    for (double step = -6; step <= 6; step += 0.25) {
      final Offset p =
          centre + Offset(math.cos(angle), math.sin(angle)) * (radius + step);
      final double fx = p.dx / _fieldSize.width;
      final double fy = p.dy / _fieldSize.height;
      if (fx < 0 || fx > 1 || fy < 0 || fy > 1) {
        continue;
      }
      final double delta = on(fx, fy).r - off(fx, fy).r;
      if (delta.abs() > dr.abs()) {
        dr = delta;
        db = on(fx, fy).b - off(fx, fy).b;
      }
    }
    return (dr: dr, db: db);
  }

  Finder baseLayer() => find
      .descendant(
        of: find.byType(JeebMidnightField),
        matching: find.byType(CustomPaint),
      )
      .first;

  Finder decorLayer() => find
      .descendant(
        of: find.byType(JeebMidnightField),
        matching: find.byType(CustomPaint),
      )
      .last;

  group('JeebRadii', () {
    test('carries the §5 ladder', () {
      expect(JeebRadii.sm, 9);
      expect(JeebRadii.md, 14);
      expect(JeebRadii.lg, 18);
      expect(JeebRadii.xl, 22);
      expect(JeebRadii.sheet, 26);
      expect(JeebRadii.hero, 34);
      expect(JeebRadii.capsule, 40);
      expect(JeebRadii.pill, 999);
    });

    test('rungs ascend', () {
      const List<double> ladder = <double>[
        JeebRadii.sm,
        JeebRadii.md,
        JeebRadii.lg,
        JeebRadii.xl,
        JeebRadii.sheet,
        JeebRadii.hero,
        JeebRadii.capsule,
        JeebRadii.pill,
      ];
      for (int i = 1; i < ladder.length; i++) {
        expect(ladder[i], greaterThan(ladder[i - 1]));
      }
    });
  });

  group('glow placement', () {
    test('carries the §8 fractions', () {
      expect(JeebFieldGlowPlacement.topEnd.fx, 0.88);
      expect(JeebFieldGlowPlacement.topEnd.fy, -0.06);
      expect(JeebFieldGlowPlacement.centerUpper.fx, 0.50);
      expect(JeebFieldGlowPlacement.centerUpper.fy, 0.38);
      expect(JeebFieldGlowPlacement.bottom.fx, 0.50);
      expect(JeebFieldGlowPlacement.bottom.fy, 0.94);
    });

    test('is directional — topEnd mirrors under RTL', () {
      final AlignmentDirectional topEnd =
          JeebFieldGlowPlacement.topEnd.alignment;
      expect(topEnd.resolve(TextDirection.ltr).x, closeTo(0.76, 1e-9));
      expect(topEnd.resolve(TextDirection.rtl).x, closeTo(-0.76, 1e-9));
      expect(topEnd.resolve(TextDirection.rtl).y, closeTo(-1.12, 1e-9));
    });

    test('centre placements do not move under RTL', () {
      for (final JeebFieldGlowPlacement placement in <JeebFieldGlowPlacement>[
        JeebFieldGlowPlacement.centerUpper,
        JeebFieldGlowPlacement.bottom,
      ]) {
        expect(placement.alignment.resolve(TextDirection.ltr).x, 0);
        expect(placement.alignment.resolve(TextDirection.rtl).x, 0);
      }
    });

    test('topStart carries the measured R4/R9/R17 ORANGE anchor', () {
      expect(JeebFieldGlowPlacement.topStart.fx, 0.12);
      expect(JeebFieldGlowPlacement.topStart.fy, -0.08);

      // Above the canvas, and higher than the periwinkle twin: the three orange
      // tiles declare −8%, the four wash tiles −6%.
      expect(JeebFieldGlowPlacement.topStart.fy, lessThan(0));
      expect(
        JeebFieldGlowPlacement.topStart.fy,
        lessThan(JeebFieldWashPlacement.topStart.fy),
      );

      // The exact start-side mirror of the ratified topEnd 0.88.
      expect(
        JeebFieldGlowPlacement.topStart.fx,
        closeTo(1 - JeebFieldGlowPlacement.topEnd.fx, 1e-9),
      );
      expect(
        JeebFieldGlowPlacement.topStart.alignment.resolve(TextDirection.ltr).x,
        closeTo(-0.76, 1e-9),
      );
      expect(
        JeebFieldGlowPlacement.topStart.alignment.resolve(TextDirection.rtl).x,
        closeTo(0.76, 1e-9),
      );
      expect(
        JeebFieldGlowPlacement.topStart.alignment.resolve(TextDirection.ltr).y,
        closeTo(-1.16, 1e-9),
      );
    });

    test('topStart was APPENDED — the shipped three keep their indices', () {
      expect(JeebFieldGlowPlacement.values, <JeebFieldGlowPlacement>[
        JeebFieldGlowPlacement.topEnd,
        JeebFieldGlowPlacement.centerUpper,
        JeebFieldGlowPlacement.bottom,
        JeebFieldGlowPlacement.topStart,
      ]);
      expect(JeebFieldGlowPlacement.topEnd.index, 0);
      expect(JeebFieldGlowPlacement.centerUpper.index, 1);
      expect(JeebFieldGlowPlacement.bottom.index, 2);
      expect(JeebFieldGlowPlacement.topStart.index, 3);
    });
  });

  group('variant layers', () {
    testWidgets('hero paints wash + glow + periwinkle + two dotted rings', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.hero);

      expect(baseLayer(), paintsExactlyCountTimes(#drawRect, 3));
      expect(baseLayer(), paintsExactlyCountTimes(#drawPath, 2));
    });

    testWidgets('content paints wash + one glow and no rings', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);

      expect(baseLayer(), paintsExactlyCountTimes(#drawRect, 2));
      expect(baseLayer(), paintsExactlyCountTimes(#drawPath, 0));
      expect(find.byType(JMotionLoop), findsNothing);
    });

    testWidgets('sheet paints a navy surface under its glow', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.sheet);

      expect(baseLayer(), paintsExactlyCountTimes(#drawRect, 2));
      expect(baseLayer(), paintsExactlyCountTimes(#drawPath, 0));

      final Color Function(double, double) pixel = await sampler(tester);
      expect(pixel(0.5, 0.98), JeebMidnight.surface);
    });

    testWidgets('map dims the edges and leaves the centre transparent', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.map);

      expect(baseLayer(), paintsExactlyCountTimes(#drawRect, 2));

      final Color Function(double, double) pixel = await sampler(tester);
      expect(pixel(0.5, 0.5).a, 0);
      expect(pixel(0.5, 0.01).a, greaterThan(0.3));
      expect(pixel(0.5, 0.99).a, greaterThan(0.3));
    });

    testWidgets('hero decor draws two arcs and the twinkle field', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.hero);

      expect(decorLayer(), paintsExactlyCountTimes(#drawArc, 2));
      expect(decorLayer(), paintsExactlyCountTimes(#drawCircle, 6));
    });

    testWidgets('showRings/showTwinkles override the variant', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        showRings: true,
        showTwinkles: false,
      );

      expect(baseLayer(), paintsExactlyCountTimes(#drawPath, 2));
      expect(decorLayer(), paintsExactlyCountTimes(#drawArc, 2));
      expect(decorLayer(), paintsExactlyCountTimes(#drawCircle, 0));
    });

    testWidgets('hero drops the rings when asked', (WidgetTester tester) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        showRings: false,
        showTwinkles: false,
      );

      expect(baseLayer(), paintsExactlyCountTimes(#drawPath, 0));
      expect(find.byType(JMotionLoop), findsNothing);
    });
  });

  group('glow geometry', () {
    testWidgets('topEnd lands at the end edge and mirrors under RTL', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);
      final Color Function(double, double) ltr = await sampler(tester);
      expect(ltr(0.88, 0.02).r, greaterThan(ltr(0.12, 0.02).r));

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        direction: TextDirection.rtl,
      );
      final Color Function(double, double) rtl = await sampler(tester);
      expect(rtl(0.12, 0.02).r, greaterThan(rtl(0.88, 0.02).r));

      expect(ltr(0.88, 0.02).r, closeTo(rtl(0.12, 0.02).r, 2 / 255));
    });

    testWidgets('bottom placement moves the glow off the top', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.bottom,
      );
      final Color Function(double, double) pixel = await sampler(tester);

      expect(pixel(0.5, 0.97).r, greaterThan(pixel(0.5, 0.5).r));
      expect(pixel(0.5, 0.02).r, lessThan(pixel(0.5, 0.97).r));
    });

    testWidgets('glowColor swaps the orange for the success wash', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowColor: JeebMidnightField.successGlow,
      );
      final Color Function(double, double) pixel = await sampler(tester);

      final Color glowed = pixel(0.88, 0.02);
      final Color plain = pixel(0.12, 0.4);
      expect(glowed.g, greaterThan(plain.g));
      expect(glowed.r, lessThan(glowed.g));
    });

    testWidgets('the glow ellipse is the board\'s 520×420 radii', (
      WidgetTester tester,
    ) async {
      // Centre-anchored so the whole ellipse is measurable on-canvas, and
      // differenced against a fully transparent glow so the base wash cancels.
      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.centerUpper,
      );
      final Color Function(double, double) lit = await sampler(tester);

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.centerUpper,
        glowColor: const Color(0x00D73B00),
      );
      final Color Function(double, double) bare = await sampler(tester);

      const double centreY = 0.38;
      double delta(double fy) => lit(0.5, fy).r - bare(0.5, fy).r;
      final double peak = delta(centreY);
      expect(peak, greaterThan(0.1));

      // CSS `radial-gradient(520px 420px …)` are RADII on the 440 board frame,
      // so rx = 520/440 of the width; the ramp is linear to nothing at the 60%
      // stop, which puts half-peak at exactly 0.3 × ry.
      final double rx = _fieldSize.width * 520 / 440;
      final double ry = rx * 420 / 520;

      double halfMax = 1;
      for (double fy = centreY; fy <= 1; fy += 0.001) {
        if (delta(fy) <= peak / 2) {
          halfMax = fy;
          break;
        }
      }
      expect(
        (halfMax - centreY) * _fieldSize.height,
        closeTo(0.3 * ry, 7),
        reason: 'the shipped 1.35× factor lands 15px past this',
      );
    });

    testWidgets('topStart\'s ORANGE falloff resolves the anchor itself', (
      WidgetTester tester,
    ) async {
      // Corner-only checks pass with the anchor points out of place, so this
      // solves the gradient's own centre back out of the rendered ramp.
      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topStart,
      );
      final Color Function(double, double) lit = await sampler(tester);

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topStart,
        glowColor: const Color(0x00D73B00),
      );
      final Color Function(double, double) bare = await sampler(tester);

      // src-over inverted: (lit − bare) = a × (orange − bare), so this reads the
      // gradient's alpha back out of the frame with the base wash cancelled.
      double alphaAt(double x, double y) {
        final double fx = x / _fieldSize.width;
        final double fy = y / _fieldSize.height;
        return (lit(fx, fy).r - bare(fx, fy).r) /
            (JeebMidnight.orange.r - bare(fx, fy).r);
      }

      final double rx = _fieldSize.width * 520 / 440;
      const double squash = 420 / 520;
      // Linear to nothing at the 60% stop, so down the anchor column
      // alpha(y) = a0 × (1 − (y − cy) / ramp) — a straight line in y.
      final double ramp = squash * 0.6 * rx;
      final double anchorX = 0.12 * _fieldSize.width;

      double columnAlpha(double y) {
        double sum = 0;
        for (double x = anchorX - 12; x <= anchorX + 12; x++) {
          sum += alphaAt(x, y);
        }
        return sum / 25;
      }

      // The bloom must already be dying at the very first row — an anchor
      // INSIDE the canvas would climb to a peak first.
      for (double y = 0; y < 120; y += 8) {
        expect(
          columnAlpha(y + 8),
          lessThan(columnAlpha(y)),
          reason: 'alpha must fall monotonically from row 0 down',
        );
      }

      // Least-squares the ramp: alpha(y) = b + m·y, with a0 = −m·ramp and
      // alpha(cy) = a0, hence cy = −ramp − b/m.
      double sy = 0, sa = 0, syy = 0, sya = 0;
      int n = 0;
      for (double y = 4; y <= 140; y += 4) {
        final double a = columnAlpha(y);
        sy += y;
        sa += a;
        syy += y * y;
        sya += y * a;
        n++;
      }
      final double m = (n * sya - sy * sa) / (n * syy - sy * sy);
      final double b = (sa - m * sy) / n;
      final double a0 = -m * ramp;
      final double cy = -ramp - b / m;

      expect(a0, closeTo(0.22, 0.01), reason: 'content variant glow alpha');
      expect(cy, lessThan(0), reason: 'the anchor sits ABOVE the canvas');
      expect(
        cy / _fieldSize.height,
        closeTo(-0.08, 0.012),
        reason: 'board −8%, NOT the wash twin\'s −6% and NOT a positive fy',
      );

      // Now cx, from the same alpha field: d² = (x − cx)² + k², so (d² − x²) is
      // LINEAR in x with slope −2cx — unbiased under pixel noise, unlike a sqrt.
      double cxSum = 0;
      int rows = 0;
      for (double y = 4; y <= 64; y += 4) {
        double sx = 0, sq = 0, sxx = 0, sxq = 0;
        int p = 0;
        for (double x = 110; x <= 220; x += 5) {
          final double d = 0.6 * rx * (1 - alphaAt(x, y) / a0);
          final double q = d * d - x * x;
          sx += x;
          sq += q;
          sxx += x * x;
          sxq += x * q;
          p++;
        }
        cxSum += -0.5 * (p * sxq - sx * sq) / (p * sxx - sx * sx);
        rows++;
      }
      final double cx = cxSum / rows;
      expect(
        cx / _fieldSize.width,
        closeTo(0.12, 0.012),
        reason: 'board 10–20%, shipped at the 0.12 median',
      );
    });

    testWidgets('topStart mirrors to the end side under RTL', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topStart,
      );
      final Color Function(double, double) ltr = await sampler(tester);
      expect(ltr(0.12, 0.02).r, greaterThan(ltr(0.88, 0.02).r));

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topStart,
        direction: TextDirection.rtl,
      );
      final Color Function(double, double) rtl = await sampler(tester);

      expect(rtl(0.88, 0.02).r, greaterThan(rtl(0.12, 0.02).r));
      expect(rtl(0.88, 0.02).r, closeTo(ltr(0.12, 0.02).r, 2 / 255));
    });

    testWidgets('topStart did NOT become the default — topEnd still is', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);
      final Color Function(double, double) fallback = await sampler(tester);

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
      );
      final Color Function(double, double) explicit = await sampler(tester);

      expect(fallback(0.88, 0.02), explicit(0.88, 0.02));
      expect(fallback(0.88, 0.02).r, greaterThan(fallback(0.12, 0.02).r));
    });

    testWidgets('the wash runs light at the top and deepest at the bottom', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);
      final Color Function(double, double) pixel = await sampler(tester);

      expectColor(pixel(0.02, 0.005), JeebMidnight.surfaceHigh);
      expectColor(pixel(0.5, 0.995), JeebMidnight.page);
      expect(pixel(0.5, 0.45).b, lessThan(pixel(0.5, 0.01).b));
    });
  });

  group('periwinkle wash', () {
    test('carries both attested anchors', () {
      expect(JeebFieldWashPlacement.startMid.fx, 0.0);
      expect(JeebFieldWashPlacement.startMid.fy, 0.39);
      expect(JeebFieldWashPlacement.startMid.alpha, 0.18);
      expect(JeebFieldWashPlacement.bottomEnd.fx, 0.90);
      expect(JeebFieldWashPlacement.bottomEnd.fy, 1.0);
      expect(JeebFieldWashPlacement.bottomEnd.alpha, 0.22);
    });

    test('is directional', () {
      final AlignmentDirectional start =
          JeebFieldWashPlacement.startMid.alignment;
      expect(start.resolve(TextDirection.ltr).x, -1);
      expect(start.resolve(TextDirection.rtl).x, 1);
    });

    testWidgets('hero washes the START side at mid-height and dies by x 0.45', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.hero);
      final Color Function(double, double) ltr = await sampler(tester);

      expect(ltr(0.02, 0.39).r, greaterThan(ltr(0.98, 0.39).r));
      expect(ltr(0.45, 0.39).r, closeTo(ltr(0.98, 0.39).r, 2 / 255));

      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        direction: TextDirection.rtl,
      );
      final Color Function(double, double) rtl = await sampler(tester);

      expect(rtl(0.98, 0.39).r, greaterThan(rtl(0.02, 0.39).r));
      expect(rtl(0.98, 0.39).r, closeTo(ltr(0.02, 0.39).r, 2 / 255));
    });

    testWidgets('bottomEnd moves the wash to the far corner', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        washPlacement: JeebFieldWashPlacement.bottomEnd,
      );
      final Color Function(double, double) pixel = await sampler(tester);

      expect(pixel(0.95, 0.99).r, greaterThan(pixel(0.05, 0.99).r));
      expect(pixel(0.02, 0.39).r, closeTo(pixel(0.98, 0.39).r, 2 / 255));
    });

    test('topStart carries the measured R14/R7/R21/E4 anchor', () {
      expect(JeebFieldWashPlacement.topStart.fx, 0.12);
      expect(JeebFieldWashPlacement.topStart.fy, -0.06);
      expect(JeebFieldWashPlacement.topStart.alpha, 0.22);
      // Board `480px 400px` are RADII on the 440 canvas.
      expect(
        JeebFieldWashPlacement.topStart.radiusFactor,
        closeTo(480 / 440, 1e-9),
      );
      expect(JeebFieldWashPlacement.topStart.aspect, closeTo(400 / 480, 1e-9));
      // The start-side mirror of the topEnd glow: above the top edge, not mid.
      expect(JeebFieldWashPlacement.topStart.fy, JeebFieldGlowPlacement.topEnd.fy);
      expect(
        JeebFieldWashPlacement.topStart.alignment.resolve(TextDirection.ltr).x,
        lessThan(0),
      );
      expect(
        JeebFieldWashPlacement.topStart.alignment.resolve(TextDirection.rtl).x,
        greaterThan(0),
      );
    });

    testWidgets('topStart blooms over the START corner, not at mid-height', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);
      final Color Function(double, double) bare = await sampler(tester);

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        washPlacement: JeebFieldWashPlacement.topStart,
      );
      final Color Function(double, double) lit = await sampler(tester);

      // Periwinkle over navy lifts blue; every other anchor's corner must not.
      double lift(double fx, double fy) => lit(fx, fy).b - bare(fx, fy).b;

      expect(lift(0.05, 0.02), greaterThan(0.03));
      // The centre sits ABOVE the canvas, so the lift is already falling off at
      // the top edge instead of peaking inside it.
      expect(lift(0.12, 0), greaterThan(lift(0.12, 0.10) * 1.35));
      expect(lift(0.02, 0.39), closeTo(0, 0.005));
      expect(lift(0.95, 0.02), closeTo(0, 0.005));
      expect(lift(0.95, 0.99), closeTo(0, 0.005));
    });

    test('endMid carries the ratified R4 anchor', () {
      expect(JeebFieldWashPlacement.endMid.fx, 1.17);
      expect(JeebFieldWashPlacement.endMid.fy, 0.65);
      expect(JeebFieldWashPlacement.endMid.alpha, 0.21);
      expect(JeebFieldWashPlacement.endMid.radiusFactor, 1.78);
      expect(JeebFieldWashPlacement.endMid.aspect, 0.714);
      // Board `at 110% 65%`: past the END edge, at MID height. On the 956-tall
      // canvas that is 335px above the corner `bottomEnd` was drawing.
      expect(JeebFieldWashPlacement.endMid.fx, greaterThan(1));
      expect(
        (JeebFieldWashPlacement.bottomEnd.fy -
                JeebFieldWashPlacement.endMid.fy) *
            956,
        closeTo(335, 1),
      );
      expect(
        JeebFieldWashPlacement.endMid.alignment.resolve(TextDirection.ltr).x,
        greaterThan(1),
      );
      expect(
        JeebFieldWashPlacement.endMid.alignment.resolve(TextDirection.rtl).x,
        lessThan(-1),
      );
    });

    test('endMid is APPENDED — the older anchors keep their indices', () {
      expect(JeebFieldWashPlacement.values.last, JeebFieldWashPlacement.endMid);
      expect(JeebFieldWashPlacement.startMid.index, 0);
      expect(JeebFieldWashPlacement.bottomEnd.index, 1);
      expect(JeebFieldWashPlacement.topStart.index, 2);
      // bottomEnd keeps its own value; endMid is a sibling, not a rename.
      expect(JeebFieldWashPlacement.bottomEnd.fy, 1.0);
      expect(JeebFieldWashPlacement.bottomEnd.alpha, 0.22);
    });

    testWidgets('endMid peaks at the END edge mid-height, not the corner', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);
      final Color Function(double, double) bare = await sampler(tester);

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        washPlacement: JeebFieldWashPlacement.endMid,
      );
      final Color Function(double, double) lit = await sampler(tester);

      double lift(double fx, double fy) => lit(fx, fy).b - bare(fx, fy).b;

      expect(lift(0.98, 0.65), greaterThan(0.03));
      // The corner `bottomEnd` lit is now well down the falloff instead of at
      // the peak — the 335px move, read in pixels.
      expect(lift(0.98, 0.65), greaterThan(lift(0.98, 0.99) * 2));
      // rx 1.78 still reaches past the mid-line; ry 0.714 of it dies before the
      // top edge, and neither reaches the start edge.
      expect(lift(0.30, 0.65), greaterThan(0.01));
      expect(lift(0.02, 0.65), closeTo(0, 0.004));
      expect(lift(0.98, 0.02), closeTo(0, 0.004));
    });

    testWidgets('a non-hero variant can opt in', (WidgetTester tester) async {
      await pumpField(tester, variant: JeebFieldVariant.content);
      expect(baseLayer(), paintsExactlyCountTimes(#drawRect, 2));

      await pumpField(
        tester,
        variant: JeebFieldVariant.content,
        washPlacement: JeebFieldWashPlacement.startMid,
      );
      expect(baseLayer(), paintsExactlyCountTimes(#drawRect, 3));
    });
  });

  group('orbit arcs', () {
    testWidgets('the inner arc is orange and the outer stays white', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        disableAnimations: true,
      );
      final Color Function(double, double) rest = await sampler(tester);

      // Both arcs ride one loop; 440ms puts the outer (delay A) on its peak
      // with the inner still near its own.
      await pumpField(tester, variant: JeebFieldVariant.hero);
      await tester.pump(const Duration(milliseconds: 440));
      final Color Function(double, double) lit = await sampler(tester);

      final ({double db, double dr}) outer = arcDelta(lit, rest, 0.40, 131);
      final ({double db, double dr}) inner = arcDelta(lit, rest, 0.26, 159);

      expect(outer.dr, greaterThan(0.02));
      expect(outer.db, greaterThan(0));
      expect(inner.dr, greaterThan(0.02));
      expect(inner.db, lessThan(0));
    });
  });

  group('motion', () {
    testWidgets('hero animates its arcs and twinkles', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.hero);

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('reduce motion parks a STAGGERED twinkle on keyframe one', (
      WidgetTester tester,
    ) async {
      // The third dot carries jTwinkle's 1.3s stagger; a stagger written as a
      // phase offset would park it mid-cycle instead of at rest opacity .2.
      const Offset dot = Offset(0.62, 0.21);

      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        disableAnimations: true,
        showTwinkles: false,
      );
      final Color Function(double, double) bare = await sampler(tester);
      final Color background = bare(dot.dx, dot.dy);

      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      final Color Function(double, double) rest = await sampler(tester);
      expectColor(
        rest(dot.dx, dot.dy),
        Color.lerp(background, Colors.white, JeebMotion.twinkleRestOpacity)!,
        tolerance: 6 / 255,
      );

      await tester.pump(JeebMotion.twinkleDuration ~/ 3);
      final Color Function(double, double) later = await sampler(tester);
      expect(later(dot.dx, dot.dy), rest(dot.dx, dot.dy));
    });

    testWidgets('the static layers schedule nothing of their own', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animateDecor:false keeps the decor at its rest frame', (
      WidgetTester tester,
    ) async {
      // R1 is board-still: the arcs and twinkles must still PAINT, but with no
      // ticker and no drift over time.
      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        animateDecor: false,
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      final Color Function(double, double) rest = await sampler(tester);
      await tester.pump(JeebMotion.arcPulseDuration ~/ 3);
      final Color Function(double, double) later = await sampler(tester);
      expect(later(0.62, 0.21), rest(0.62, 0.21));

      // …and the decor layer is still there, unlike `showTwinkles: false`.
      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        animateDecor: false,
        showTwinkles: false,
      );
      final Color Function(double, double) bare = await sampler(tester);
      expect(later(0.62, 0.21), isNot(bare(0.62, 0.21)));
    });
  });

  group('layout', () {
    testWidgets('the child is laid out full-bleed over every layer', (
      WidgetTester tester,
    ) async {
      const Key childKey = Key('child');
      await pumpField(
        tester,
        variant: JeebFieldVariant.hero,
        child: const SizedBox.expand(key: childKey),
      );

      expect(tester.getSize(find.byKey(childKey)), _fieldSize);
      expect(tester.getSize(baseLayer()), _fieldSize);
      expect(tester.getSize(decorLayer()), _fieldSize);
      expect(
        tester.getTopLeft(find.byKey(childKey)),
        tester.getTopLeft(baseLayer()),
      );
    });

    testWidgets('the field fills its constraints without a child', (
      WidgetTester tester,
    ) async {
      await pumpField(tester, variant: JeebFieldVariant.content);

      expect(tester.getSize(find.byType(JeebMidnightField)), _fieldSize);
    });
  });
}
