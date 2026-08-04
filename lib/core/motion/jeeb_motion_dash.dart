// **jDash** — `stroke-dashoffset → −40`, 2s linear ∞. Dashed route and orbit
// lines (the map path, the empty-state ring).
//
// This is the one §2.6 primitive that cannot be a wrapper: CSS animates a
// stroke property, and Flutter has no stroke-dash support on `Path`, so the
// dashes have to be re-cut every frame from path metrics. Two entry points:
//
//   * [JDashOffset] — hands the caller the raw `Animation<double>` for its own
//     `CustomPainter`, which is what a map overlay or a hand-drawn orbit needs.
//   * [JDashedPath] — the ready widget: give it a path (or use the `.line` /
//     `.oval` constructors) and it paints marching ants.
//
// Both inherit the reduce-motion contract from `JMotionLoop`: the rest frame is
// dash offset 0, i.e. a still dashed line — the dashes stay, they stop marching.

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'jeeb_motion_loop.dart';
import 'jeeb_motion_tokens.dart';

/// Builds the path to dash, given the box the painter was handed.
typedef JDashPathBuilder = Path Function(Size size);

/// Signature for [JDashOffset.builder].
typedef JDashOffsetBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> dashOffset,
      Widget? child,
    );

/// **jDash** as a raw animation source: `dashOffset` runs 0 → −40 linearly over
/// 2s, forever, and is handed to [builder] as an `Animation<double>`.
///
/// Feed it to a `CustomPaint(painter: …)` whose painter takes it as `repaint:`
/// and calls [JDashedPathPainter.dashed] — that is the whole contract. Use
/// [JDashedPath] instead when the path is a plain line or ring.
///
/// Reduce motion pins the offset at 0.
class JDashOffset extends StatelessWidget {
  const JDashOffset({
    super.key,
    required this.builder,
    this.duration = JeebMotion.dashDuration,
    this.delay = Duration.zero,
    this.travel = JeebMotion.dashTravel,
    this.child,
  });

  /// Receives the dash-offset animation.
  final JDashOffsetBuilder builder;

  /// One full travel of [travel] pixels.
  final Duration duration;

  /// Stagger — the offset holds 0 until it elapses.
  final Duration delay;

  /// Pixels of dash travel per cycle; negative advances along the path.
  /// Keep `travel.abs()` an exact multiple of the dash period or the loop
  /// point jumps.
  final double travel;

  /// Passed through to [builder] untouched.
  final Widget? child;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        builder(
          context,
          animation.drive(
            travel == JeebMotion.dashTravel
                ? JeebMotion.dashOffset
                : JeebMotion.dashOffsetFor(travel),
          ),
          c,
        ),
  );
}

/// **jDash** as a ready widget: a dashed path whose dashes march at the board's
/// 2s / −40px cadence.
///
/// The path comes from [pathBuilder], which is called with the painter's box, so
/// the geometry is resolution-independent. [JDashedPath.line] and
/// [JDashedPath.oval] cover the two shapes §2.6 names (map route, orbit ring).
///
/// Sizing: with a [child] the widget takes the child's size; without one it takes
/// [size], defaulting to `Size.infinite` — which means "as large as the parent
/// allows" and therefore needs bounded constraints.
///
/// Reduce motion renders the same dashes, still.
class JDashedPath extends StatelessWidget {
  const JDashedPath({
    super.key,
    required this.pathBuilder,
    required this.color,
    this.strokeWidth = 2,
    this.dashLength = JeebMotion.dashLength,
    this.gapLength = JeebMotion.dashGap,
    this.strokeCap = StrokeCap.round,
    this.duration = JeebMotion.dashDuration,
    this.delay = Duration.zero,
    this.travel = JeebMotion.dashTravel,
    this.size,
    this.child,
  });

  /// A horizontal dashed line across the vertical centre of the box — the map
  /// route / connector read.
  const JDashedPath.line({
    super.key,
    required this.color,
    this.strokeWidth = 2,
    this.dashLength = JeebMotion.dashLength,
    this.gapLength = JeebMotion.dashGap,
    this.strokeCap = StrokeCap.round,
    this.duration = JeebMotion.dashDuration,
    this.delay = Duration.zero,
    this.travel = JeebMotion.dashTravel,
    this.size,
    this.child,
  }) : pathBuilder = horizontalLinePath;

  /// A dashed ellipse inscribed in the box — the orbit ring the §2.7 empty
  /// states put medallions on.
  const JDashedPath.oval({
    super.key,
    required this.color,
    this.strokeWidth = 2,
    this.dashLength = JeebMotion.dashLength,
    this.gapLength = JeebMotion.dashGap,
    this.strokeCap = StrokeCap.round,
    this.duration = JeebMotion.dashDuration,
    this.delay = Duration.zero,
    this.travel = JeebMotion.dashTravel,
    this.size,
    this.child,
  }) : pathBuilder = inscribedOvalPath;

  /// Builds the path to dash from the painter's box.
  final JDashPathBuilder pathBuilder;

  /// Stroke colour. Motion ships geometry only, so the caller owns this.
  final Color color;

  /// Stroke thickness.
  final double strokeWidth;

  /// Length of one dash.
  final double dashLength;

  /// Length of one gap.
  final double gapLength;

  /// Cap on each dash. Round is the board's soft route-dot read.
  final StrokeCap strokeCap;

  /// One full travel of [travel] pixels.
  final Duration duration;

  /// Stagger — dashes hold offset 0 until it elapses.
  final Duration delay;

  /// Pixels of dash travel per cycle; negative advances along the path.
  final double travel;

  /// Painter size when there is no [child]. Defaults to `Size.infinite`.
  final Size? size;

  /// Painted on top of the dashes, and what the widget sizes itself to.
  final Widget? child;

  /// [JDashedPath.line]'s geometry, exposed so it can be passed to the default
  /// constructor or reused inside a bigger painter.
  static Path horizontalLinePath(Size size) => Path()
    ..moveTo(0, size.height / 2)
    ..lineTo(size.width, size.height / 2);

  /// [JDashedPath.oval]'s geometry.
  static Path inscribedOvalPath(Size size) =>
      Path()..addOval(Offset.zero & size);

  @override
  Widget build(BuildContext context) => JDashOffset(
    duration: duration,
    delay: delay,
    travel: travel,
    child: child,
    builder: (BuildContext context, Animation<double> dashOffset, Widget? c) =>
        CustomPaint(
          size: size ?? Size.infinite,
          painter: JDashedPathPainter(
            dashOffset: dashOffset,
            pathBuilder: pathBuilder,
            color: color,
            strokeWidth: strokeWidth,
            dashLength: dashLength,
            gapLength: gapLength,
            strokeCap: strokeCap,
          ),
          child: c,
        ),
  );
}

/// Paints a path as marching dashes. Public so a screen with its own canvas
/// (a map overlay, a composed illustration) can dash inside it rather than
/// stacking another layer.
class JDashedPathPainter extends CustomPainter {
  JDashedPathPainter({
    required this.dashOffset,
    required this.pathBuilder,
    required this.color,
    this.strokeWidth = 2,
    this.dashLength = JeebMotion.dashLength,
    this.gapLength = JeebMotion.dashGap,
    this.strokeCap = StrokeCap.round,
  }) : assert(dashLength > 0, 'dashLength must be positive'),
       assert(gapLength >= 0, 'gapLength cannot be negative'),
       super(repaint: dashOffset);

  /// The travelling offset, typically from [JDashOffset].
  final Animation<double> dashOffset;

  /// Builds the path to dash.
  final JDashPathBuilder pathBuilder;

  /// Stroke colour.
  final Color color;

  /// Stroke thickness.
  final double strokeWidth;

  /// Length of one dash.
  final double dashLength;

  /// Length of one gap.
  final double gapLength;

  /// Cap on each dash.
  final StrokeCap strokeCap;

  /// Re-cuts [source] into dash segments, shifted by [dashOffset].
  ///
  /// A point at distance `d` along the path is inked when
  /// `(d + dashOffset) % (dashLength + gapLength) < dashLength`, so a
  /// *decreasing* offset walks the dashes FORWARD along the path — the same sign
  /// convention as SVG's `stroke-dashoffset`, which is why §2.6 writes −40.
  ///
  /// Static and pure: safe to call from any `CustomPainter`.
  static Path dashed(
    Path source, {
    required double dashLength,
    required double gapLength,
    double dashOffset = 0,
  }) {
    assert(dashLength > 0, 'dashLength must be positive');
    assert(gapLength >= 0, 'gapLength cannot be negative');
    final double period = dashLength + gapLength;
    final Path result = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      // Dart's `%` is non-negative for a positive divisor, so this lands in
      // (-period, 0] — the first dash boundary at or before the path start.
      double cursor = -(dashOffset % period);
      while (cursor < metric.length) {
        final double start = math.max(cursor, 0);
        final double end = math.min(cursor + dashLength, metric.length);
        if (end > start) {
          result.addPath(metric.extractPath(start, end), Offset.zero);
        }
        cursor += period;
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Path path = dashed(
      pathBuilder(size),
      dashLength: dashLength,
      gapLength: gapLength,
      dashOffset: dashOffset.value,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = strokeCap,
    );
  }

  @override
  bool shouldRepaint(JDashedPathPainter oldDelegate) =>
      oldDelegate.dashOffset != dashOffset ||
      oldDelegate.pathBuilder != pathBuilder ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength ||
      oldDelegate.strokeCap != strokeCap;
}
