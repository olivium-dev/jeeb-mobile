import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../motion/jeeb_motion.dart';
import '../../theme/jeeb_midnight_palette.dart';

/// The layered field of token sheet §8 — the background every Midnight screen
/// mounts instead of a flat `scaffoldBackgroundColor`.
enum JeebFieldVariant {
  /// Wash + orange glow + periwinkle wash + orbit rings + twinkles.
  hero,

  /// Wash + one quiet glow. No rings.
  content,

  /// Dimmed edges over a `GoogleMap`; the base stays transparent.
  map,

  /// Navy surface + top glow, for bottom sheets.
  sheet,
}

/// Glow anchors as fractions of the field (§8). Directional: `topEnd` sits at
/// 0.88 in LTR and at 0.12 in RTL.
enum JeebFieldGlowPlacement {
  topEnd(0.88, -0.06),
  centerUpper(0.50, 0.38),
  bottom(0.50, 0.94);

  const JeebFieldGlowPlacement(this.fx, this.fy);

  final double fx;
  final double fy;

  AlignmentDirectional get alignment =>
      AlignmentDirectional(fx * 2 - 1, fy * 2 - 1);
}

/// Periwinkle-wash anchors, both attested. Directional, like the glow.
enum JeebFieldWashPlacement {
  /// R1's own wash, measured: start edge at mid-height, dying by x ≈ 0.40.
  startMid(0.0, 0.39, 0.18, 0.667, 1.35),

  /// The §8 anchor, drawn by other tiles.
  bottomEnd(0.90, 1.0, 0.22, 1.0, _glowAspect);

  const JeebFieldWashPlacement(
    this.fx,
    this.fy,
    this.alpha,
    this.radiusFactor,
    this.aspect,
  );

  final double fx;
  final double fy;
  final double alpha;
  final double radiusFactor;
  final double aspect;

  AlignmentDirectional get alignment =>
      AlignmentDirectional(fx * 2 - 1, fy * 2 - 1);
}

/// Paints the Midnight field behind [child].
///
/// [variant] picks the layer set; the remaining arguments override one layer
/// each and default to the variant's own value when null.
class JeebMidnightField extends StatelessWidget {
  const JeebMidnightField({
    super.key,
    required this.variant,
    this.child,
    this.glowPlacement,
    this.glowColor,
    this.washPlacement,
    this.showRings,
    this.showTwinkles,
    this.animateDecor = true,
  });

  /// §8's money-screen wash. Pass as [glowColor] on earnings/wallet screens.
  static final Color successGlow = JeebMidnight.success.withValues(alpha: 0.16);

  final JeebFieldVariant variant;

  /// Laid out full-bleed over every layer.
  final Widget? child;

  final JeebFieldGlowPlacement? glowPlacement;

  /// Carries its own alpha; the variant only supplies the default.
  final Color? glowColor;

  /// Turns the periwinkle wash on for any variant, not just `hero`.
  final JeebFieldWashPlacement? washPlacement;

  final bool? showRings;

  final bool? showTwinkles;

  /// False draws the arcs and twinkles at their rest frame with no ticker —
  /// what a board-still tile (R1) needs while keeping every static layer.
  final bool animateDecor;

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = Directionality.of(context);
    final _FieldSpec spec = _FieldSpec.resolve(
      variant: variant,
      glowPlacement: glowPlacement,
      glowColor: glowColor,
      washPlacement: washPlacement,
      showRings: showRings,
      showTwinkles: showTwinkles,
    );

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _FieldPainter(spec: spec, direction: direction),
            ),
          ),
        ),
        if (spec.rings || spec.twinkles)
          // Its own boundary: without it every pulse re-records the screen.
          Positioned.fill(
            child: RepaintBoundary(
              child: animateDecor
                  ? JMotionLoop(
                      duration: JeebMotion.arcPulseDuration,
                      builder:
                          (
                            BuildContext context,
                            Animation<double> phase,
                            Widget? _,
                          ) => CustomPaint(
                            painter: _FieldDecorPainter(
                              phase: phase,
                              spec: spec,
                              direction: direction,
                              // A stagger is a phase offset once the loop runs;
                              // at rest it would park elements off keyframe one.
                              stagger: !MediaQuery.disableAnimationsOf(context),
                            ),
                          ),
                    )
                  : CustomPaint(
                      painter: _FieldDecorPainter(
                        phase: const AlwaysStoppedAnimation<double>(0),
                        spec: spec,
                        direction: direction,
                        stagger: false,
                      ),
                    ),
            ),
          ),
        ?child,
      ],
    );
  }
}

// §8 glow: an ellipse of rx = 1.35 × field width, ry/rx = 420/520, fading to
// transparent at the 60% stop.
const double _glowRadiusFactor = 1.35;
const double _glowAspect = 420 / 520;
const double _glowFade = 0.6;

// Orbit rings, measured off R1: two concentric circles at (0.90, 0.05).
const AlignmentDirectional _ringAnchor = AlignmentDirectional(0.80, -0.90);
const List<double> _ringRadii = <double>[0.40, 0.26];
const double _ringStroke = 1.5;
const double _ringDash = 1;
const double _ringGap = 9;
const double _ringAlpha = 0.07;

/// R1's inner arc is drawn orange, which the tile sanctions against the orange
/// budget; the outer stays white. Both are multiplied by the jArcPulse opacity.
const double _arcWhiteAlpha = 0.07;
const double _arcOrangeAlpha = 0.15;

// Derived: map dimming has no board measurement — R3/R11 draw the map itself.
const double _mapVignetteAlpha = 0.45;
const double _mapScrimAlpha = 0.5;
const double _mapScrimHeight = 0.2;

const List<_FieldArc> _arcs = <_FieldArc>[
  _FieldArc(
    radius: 0.40,
    start: 100,
    sweep: 62,
    delay: JeebMotion.arcPulseDelayA,
    ink: _ArcInk.white,
  ),
  _FieldArc(
    radius: 0.26,
    start: 132,
    sweep: 54,
    delay: JeebMotion.arcPulseDelayB,
    ink: _ArcInk.orange,
  ),
];

const List<_FieldTwinkle> _twinkles = <_FieldTwinkle>[
  _FieldTwinkle(-0.64, -0.72, 1.4, Duration.zero),
  _FieldTwinkle(-0.30, -0.86, 1.0, JeebMotion.twinkleDelayA),
  _FieldTwinkle(0.24, -0.58, 2.2, JeebMotion.twinkleDelayB),
  _FieldTwinkle(0.56, -0.80, 1.0, JeebMotion.twinkleDelayA),
  _FieldTwinkle(0.0, -0.40, 1.4, JeebMotion.twinkleDelayB),
  _FieldTwinkle(0.76, -0.46, 1.0, Duration.zero),
];

enum _FieldBase { wash, navy, vignette }

enum _ArcInk {
  white(Colors.white, _arcWhiteAlpha),
  orange(JeebMidnight.orange, _arcOrangeAlpha);

  const _ArcInk(this.color, this.alpha);

  final Color color;
  final double alpha;

  Color at(double opacity) => color.withValues(alpha: alpha * opacity);
}

@immutable
class _FieldArc {
  const _FieldArc({
    required this.radius,
    required this.start,
    required this.sweep,
    required this.delay,
    required this.ink,
  });

  final double radius;
  final double start;
  final double sweep;
  final Duration delay;
  final _ArcInk ink;
}

@immutable
class _FieldTwinkle {
  const _FieldTwinkle(this.x, this.y, this.radius, this.delay);

  final double x;
  final double y;
  final double radius;
  final Duration delay;

  AlignmentDirectional get alignment => AlignmentDirectional(x, y);
}

@immutable
class _FieldSpec {
  const _FieldSpec({
    required this.base,
    required this.glow,
    required this.placement,
    required this.wash,
    required this.rings,
    required this.twinkles,
  });

  factory _FieldSpec.resolve({
    required JeebFieldVariant variant,
    required JeebFieldGlowPlacement? glowPlacement,
    required Color? glowColor,
    required JeebFieldWashPlacement? washPlacement,
    required bool? showRings,
    required bool? showTwinkles,
  }) {
    final bool hero = variant == JeebFieldVariant.hero;
    final bool glows =
        variant != JeebFieldVariant.map ||
        glowPlacement != null ||
        glowColor != null;
    final double alpha = switch (variant) {
      JeebFieldVariant.hero => 0.28,
      JeebFieldVariant.sheet => 0.26,
      JeebFieldVariant.content || JeebFieldVariant.map => 0.22,
    };
    return _FieldSpec(
      base: switch (variant) {
        JeebFieldVariant.hero || JeebFieldVariant.content => _FieldBase.wash,
        JeebFieldVariant.map => _FieldBase.vignette,
        JeebFieldVariant.sheet => _FieldBase.navy,
      },
      glow: glows
          ? glowColor ?? JeebMidnight.orange.withValues(alpha: alpha)
          : null,
      placement: glowPlacement ?? JeebFieldGlowPlacement.topEnd,
      wash: washPlacement ?? (hero ? JeebFieldWashPlacement.startMid : null),
      rings: showRings ?? hero,
      twinkles: showTwinkles ?? hero,
    );
  }

  final _FieldBase base;
  final Color? glow;
  final JeebFieldGlowPlacement placement;
  final JeebFieldWashPlacement? wash;
  final bool rings;
  final bool twinkles;

  @override
  bool operator ==(Object other) =>
      other is _FieldSpec &&
      other.base == base &&
      other.glow == glow &&
      other.placement == placement &&
      other.wash == wash &&
      other.rings == rings &&
      other.twinkles == twinkles;

  @override
  int get hashCode =>
      Object.hash(base, glow, placement, wash, rings, twinkles);
}

/// Every layer that never animates, in one pass — stacking a `DecoratedBox`
/// per layer would cost four full-screen fills and as many layers.
class _FieldPainter extends CustomPainter {
  const _FieldPainter({required this.spec, required this.direction});

  final _FieldSpec spec;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect rect = Offset.zero & size;
    switch (spec.base) {
      case _FieldBase.wash:
        _paintWash(canvas, rect);
      case _FieldBase.navy:
        canvas.drawRect(rect, Paint()..color = JeebMidnight.surface);
      case _FieldBase.vignette:
        _paintVignette(canvas, rect);
    }

    final Color? glow = spec.glow;
    if (glow != null) {
      final double rx = rect.width * _glowRadiusFactor;
      _paintEllipseGradient(
        canvas,
        rect,
        _resolve(spec.placement.alignment, rect),
        rx,
        rx * _glowAspect,
        <Color>[glow, glow.withValues(alpha: 0)],
        const <double>[0, _glowFade],
      );
    }

    final JeebFieldWashPlacement? placement = spec.wash;
    if (placement != null) {
      final Color wash = JeebMidnight.periwinkleWash.withValues(
        alpha: placement.alpha,
      );
      final double rx = rect.width * placement.radiusFactor;
      _paintEllipseGradient(
        canvas,
        rect,
        _resolve(placement.alignment, rect),
        rx,
        rx * placement.aspect,
        <Color>[wash, wash.withValues(alpha: 0)],
        const <double>[0, _glowFade],
      );
    }

    if (spec.rings) {
      _paintRings(canvas, rect);
    }
  }

  // Squashed to an ellipse by the shader's local matrix — no saveLayer, no clip.
  static void _paintEllipseGradient(
    Canvas canvas,
    Rect rect,
    Offset centre,
    double rx,
    double ry,
    List<Color> colors,
    List<double> stops,
  ) {
    final double squash = ry / rx;
    final Matrix4 matrix = Matrix4.identity()
      ..setEntry(1, 1, squash)
      ..setEntry(1, 3, centre.dy * (1 - squash));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          rx,
          colors,
          stops,
          TileMode.clamp,
          matrix.storage,
        ),
    );
  }

  Offset _resolve(AlignmentDirectional alignment, Rect rect) =>
      alignment.resolve(direction).alongSize(rect.size) + rect.topLeft;

  void _paintWash(Canvas canvas, Rect rect) {
    const double angle = 175 * math.pi / 180;
    final double dx =
        math.sin(angle) * (direction == TextDirection.rtl ? -1 : 1);
    final double dy = -math.cos(angle);
    final double length =
        (rect.width * dx).abs() + (rect.height * dy).abs();
    final Offset half = Offset(dx, dy) * (length / 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.center - half,
          rect.center + half,
          const <Color>[
            JeebMidnight.surfaceHigh,
            JeebMidnight.surface,
            JeebMidnight.page,
          ],
          const <double>[0, 0.45, 1],
        ),
    );
  }

  void _paintVignette(Canvas canvas, Rect rect) {
    final Color edge = JeebMidnight.page.withValues(alpha: _mapVignetteAlpha);
    _paintEllipseGradient(
      canvas,
      rect,
      rect.center,
      rect.width / 2,
      rect.height / 2,
      <Color>[edge.withValues(alpha: 0), edge],
      const <double>[0.55, 1],
    );
    final Color scrim = JeebMidnight.page.withValues(alpha: _mapScrimAlpha);
    final double bottom = rect.top + rect.height * _mapScrimHeight;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top, rect.right, bottom),
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          Offset(rect.left, bottom),
          <Color>[scrim, scrim.withValues(alpha: 0)],
        ),
    );
  }

  void _paintRings(Canvas canvas, Rect rect) {
    final Offset centre = _resolve(_ringAnchor, rect);
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: _ringAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.round;
    for (final double factor in _ringRadii) {
      final Path ring = Path()
        ..addOval(
          Rect.fromCircle(center: centre, radius: rect.width * factor),
        );
      canvas.drawPath(
        JDashedPathPainter.dashed(
          ring,
          dashLength: _ringDash,
          gapLength: _ringGap,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.direction != direction;
}

/// jArcPulse arcs and jTwinkle dots off ONE loop: eight primitive wrappers
/// would mean eight tickers and eight opacity layers per screen.
class _FieldDecorPainter extends CustomPainter {
  _FieldDecorPainter({
    required this.phase,
    required this.spec,
    required this.direction,
    required this.stagger,
  }) : super(repaint: phase);

  final Animation<double> phase;
  final _FieldSpec spec;
  final TextDirection direction;
  final bool stagger;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    if (spec.rings) {
      final Offset centre = _ringAnchor
          .resolve(direction)
          .alongSize(size);
      for (final _FieldArc arc in _arcs) {
        final double opacity = JeebMotion.arcPulseOpacity.transform(
          _phaseOf(arc.delay, JeebMotion.arcPulseDuration),
        );
        final double start = arc.start * math.pi / 180;
        final double sweep = arc.sweep * math.pi / 180;
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: size.width * arc.radius),
          direction == TextDirection.rtl ? math.pi - start - sweep : start,
          sweep,
          false,
          Paint()
            ..color = arc.ink.at(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _ringStroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (spec.twinkles) {
      for (final _FieldTwinkle dot in _twinkles) {
        final double t = _phaseOf(dot.delay, JeebMotion.twinkleDuration);
        canvas.drawCircle(
          dot.alignment.resolve(direction).alongSize(size),
          dot.radius * JeebMotion.twinkleScale.transform(t),
          Paint()
            ..color = Colors.white.withValues(
              alpha: JeebMotion.twinkleOpacity.transform(t),
            ),
        );
      }
    }
  }

  double _phaseOf(Duration delay, Duration period) => stagger
      ? (phase.value + delay.inMicroseconds / period.inMicroseconds) % 1.0
      : phase.value;

  @override
  bool shouldRepaint(_FieldDecorPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.spec != spec ||
      oldDelegate.direction != direction ||
      oldDelegate.stagger != stagger;
}
