// The 7 whole-widget primitives of §2.6 (`jDash` lives in `jeeb_motion_dash.dart`
// because it is a painter, not a wrapper).
//
// Every one is a `StatelessWidget` over `JMotionLoop`, so a screen never owns a
// controller, and every one honours reduce motion by parking on a fixed keyframe
// of its row — the FIRST, unless the element opts into `JMotionRest.informative`
// (Q-037). Colour is never a parameter of the motion itself —
// `JHalo` takes a ring colour because it does the painting, and that is the only
// exception; everything else animates the child the caller already coloured.

import 'package:flutter/material.dart';

import 'jeeb_motion_loop.dart';
import 'jeeb_motion_tokens.dart';

/// Which keyframe of its row a primitive freezes on under reduce motion.
///
/// **Q-037, ratified at M5.** Every §2.6 row starts on its DIM keyframe, so
/// pinning phase 0 leaves `jTwinkle` at opacity .2 and `jArcPulse` at .15 — fine
/// for a sparkle, but W2's *verified badge* wears `jTwinkle`, and a badge that
/// fades to .2 in every still has had its meaning switched off along with its
/// motion. Reduce motion may remove movement; it may not remove information.
///
/// So the choice is per ELEMENT, not per primitive, and it is deliberately not a
/// default: decoration keeps resting dark (board-faithful, and the stills stay
/// quiet), while anything a sighted user reads opts in to [informative].
///
/// Both values pin a REAL keyframe of the row — reduce motion picks which
/// keyframe, never a value between two.
enum JMotionRest {
  /// The row's first keyframe: dim and small. Sparkles, star fields, orbit arcs.
  decorative,

  /// The row's peak keyframe: fully lit. Badges, status marks — anything whose
  /// absence from a still would cost the user a fact.
  informative,
}

/// **jFloat** — `translateY 0 → −7px → 0`, 4s / 4.4s ease-in-out ∞, delays up
/// to 1.2s. Floating illustrations, walkthrough art.
///
/// Paint-only: the child keeps its layout slot, so a floating illustration never
/// shoves its neighbours around. Rest frame (reduce motion) = offset 0, i.e. the
/// child exactly where layout put it.
///
/// Stagger a group with `JeebMotion.stagger(i, count: n)` and alternate
/// [JeebMotion.floatDuration] / [JeebMotion.floatDurationSlow].
class JFloat extends StatelessWidget {
  const JFloat({
    super.key,
    required this.child,
    this.duration = JeebMotion.floatDuration,
    this.delay = Duration.zero,
    this.rise = JeebMotion.floatRise,
  });

  /// The thing that floats.
  final Widget child;

  /// One full up-and-back cycle.
  final Duration duration;

  /// Stagger — the child rests at offset 0 until it elapses.
  final Duration delay;

  /// Peak displacement in logical pixels; negative is upward.
  final double rise;

  @override
  Widget build(BuildContext context) {
    final Animatable<double> offset = rise == JeebMotion.floatRise
        ? JeebMotion.floatOffset
        : JeebMotion.floatOffsetFor(rise);
    return JMotionLoop(
      duration: duration,
      delay: delay,
      child: child,
      builder: (BuildContext context, Animation<double> animation, Widget? c) {
        return AnimatedBuilder(
          animation: animation,
          child: c,
          builder: (BuildContext context, Widget? c) => Transform.translate(
            offset: Offset(0, offset.evaluate(animation)),
            child: c,
          ),
        );
      },
    );
  }
}

/// **jTwinkle** — `opacity .2→1→.2` with `scale .7→1.15→.7`, 2.4–3s ease-in-out
/// ∞, staggered .7s/1.3s. Star dots around illustrations.
///
/// Rest frame (reduce motion) = opacity .2 at scale .7: a dim, small star, which
/// is the still state the board's first keyframe describes — stars stay visible,
/// they just stop breathing. A twinkle carrying MEANING rather than sparkle
/// passes `rest: JMotionRest.informative` and rests lit instead; see
/// [JMotionRest].
///
/// Scatter a field with [JeebMotion.twinkleDelayA] / [JeebMotion.twinkleDelayB]
/// and mix [JeebMotion.twinkleDuration] with [JeebMotion.twinkleDurationSlow].
class JTwinkle extends StatelessWidget {
  const JTwinkle({
    super.key,
    required this.child,
    this.duration = JeebMotion.twinkleDuration,
    this.delay = Duration.zero,
    this.rest = JMotionRest.decorative,
  });

  /// The star dot.
  final Widget child;

  /// One full twinkle cycle; the board runs 2.4s–3s.
  final Duration duration;

  /// Stagger — the star holds the first keyframe until it elapses.
  final Duration delay;

  /// Which keyframe the still shows when animations are off. Q-037: raise it to
  /// [JMotionRest.informative] for a badge, never for a sparkle.
  final JMotionRest rest;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    restPhase: rest == JMotionRest.informative ? JeebMotion.twinklePeakAt : 0,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        FadeTransition(
          opacity: animation.drive(JeebMotion.twinkleOpacity),
          child: ScaleTransition(
            scale: animation.drive(JeebMotion.twinkleScale),
            child: c,
          ),
        ),
  );
}

/// **jBreathe** — `opacity .45→1→.45`, 1.6–3.6s ease-in-out ∞, staggered.
/// Glows, live dots ("Broadcasting"), halos at rest.
///
/// Rest frame (reduce motion) = opacity .45. A "Broadcasting" dot therefore
/// still reads as lit when animations are off.
///
/// The period is a RANGE on the board; [JeebMotion.breatheDuration] is the
/// midpoint default. Pick per element with
/// `JeebMotion.spread(JeebMotion.breatheDurationMin, JeebMotion.breatheDurationMax, t)`.
class JBreathe extends StatelessWidget {
  const JBreathe({
    super.key,
    required this.child,
    this.duration = JeebMotion.breatheDuration,
    this.delay = Duration.zero,
  });

  /// The glow, dot or halo that breathes.
  final Widget child;

  /// One full breath.
  final Duration duration;

  /// Stagger — the child holds .45 opacity until it elapses.
  final Duration delay;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        FadeTransition(
          opacity: animation.drive(JeebMotion.breatheOpacity),
          child: c,
        ),
  );
}

/// **jWave** — `scaleY .5→1.15→.5`, 1.3s ease-in-out ∞ with a per-bar stagger.
/// One bar of the voice waveform.
///
/// Scales vertically ONLY; the bar's width and layout slot never move, so a row
/// of bars stays on its baseline grid. Rest frame (reduce motion) = scaleY .5,
/// a half-height bar — a reduce-motion waveform is a still waveform, not a flat
/// line.
///
/// Use [JWaveBars] for a whole row unless the bars need individual control.
class JWaveBar extends StatelessWidget {
  const JWaveBar({
    super.key,
    required this.child,
    this.duration = JeebMotion.waveDuration,
    this.delay = Duration.zero,
    this.alignment = Alignment.center,
  });

  /// The bar — typically a `SizedBox`/`DecoratedBox` the caller has coloured.
  final Widget child;

  /// One full rise-and-fall.
  final Duration duration;

  /// This bar's phase offset within the row.
  final Duration delay;

  /// What stays put as the bar grows. Centre matches the board's default
  /// `transform-origin`; pass `Alignment.bottomCenter` for bars that grow off a
  /// floor.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        AnimatedBuilder(
          animation: animation,
          child: c,
          builder: (BuildContext context, Widget? c) => Transform.scale(
            scaleY: JeebMotion.waveScaleY.evaluate(animation),
            alignment: alignment,
            child: c,
          ),
        ),
  );
}

/// A row of [JWaveBar]s with the crest walking across it — the voice waveform.
///
/// Bar `i` is delayed by `delay + stagger * i`, which is the board's per-bar
/// stagger written once instead of at every call site.
class JWaveBars extends StatelessWidget {
  const JWaveBars({
    super.key,
    required this.bars,
    this.duration = JeebMotion.waveDuration,
    this.stagger = JeebMotion.waveBarStagger,
    this.delay = Duration.zero,
    this.alignment = Alignment.center,
    this.spacing = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// The bars, already sized and coloured by the caller.
  final List<Widget> bars;

  /// One full rise-and-fall, shared by every bar.
  final Duration duration;

  /// Phase step between adjacent bars.
  final Duration stagger;

  /// Delay applied to the whole row before the per-bar stagger.
  final Duration delay;

  /// Passed to each [JWaveBar.alignment].
  final Alignment alignment;

  /// Gap between bars.
  final double spacing;

  /// How bars line up across the row.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: crossAxisAlignment,
    spacing: spacing,
    children: <Widget>[
      for (int i = 0; i < bars.length; i++)
        JWaveBar(
          duration: duration,
          delay: delay + stagger * i,
          alignment: alignment,
          child: bars[i],
        ),
    ],
  );
}

/// **jHalo** — a ring expanding `scale .75 → 1.6` while fading `opacity .8 → 0`,
/// 2.6s ease-out ∞. The mic halo pulse.
///
/// Paints BEHIND [child] and deliberately overflows its box: at scale 1.6 the
/// ring is 60% wider than the child, so an ancestor that clips (a `ClipRect`, a
/// `ListView` edge) will cut the pulse. Give it room.
///
/// Rest frame (reduce motion) = a still ring at scale .75, opacity .8 — the
/// pulse stops, the ring stays.
///
/// [color] is the one colour this module takes, because it is the one primitive
/// that paints rather than wraps.
class JHalo extends StatelessWidget {
  const JHalo({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 2,
    this.filled = false,
    this.ringCount = 1,
    this.duration = JeebMotion.haloDuration,
    this.delay = Duration.zero,
  }) : assert(ringCount >= 1, 'ringCount must be at least 1');

  /// What the halo pulses around — usually the mic button.
  final Widget child;

  /// Ring colour at full strength; the primitive multiplies its own opacity in.
  final Color color;

  /// Ring thickness. Ignored when [filled].
  final double strokeWidth;

  /// Paint a filled disc instead of a ring — the softer "bloom" read.
  final bool filled;

  /// Concentric pulses evenly spread across the cycle. 1 is the board's mic
  /// halo; 2–3 reads as a sonar.
  final int ringCount;

  /// One full expansion.
  final Duration duration;

  /// Stagger — the ring holds its start frame until it elapses.
  final Duration delay;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: JHaloPainter(
                    progress: animation,
                    color: color,
                    strokeWidth: strokeWidth,
                    filled: filled,
                    ringCount: ringCount,
                  ),
                ),
              ),
            ),
            c!,
          ],
        ),
  );
}

/// Paints the [JHalo] rings. Public so a screen already running a
/// `CustomPainter` can fold the halo into its own canvas instead of stacking
/// another layer.
///
/// Repaints off [progress]; it does not rebuild anything.
class JHaloPainter extends CustomPainter {
  JHaloPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 2,
    this.filled = false,
    this.ringCount = 1,
  }) : super(repaint: progress);

  /// The 0→1 cycle phase, straight from [JMotionLoop].
  final Animation<double> progress;

  /// Ring colour at full strength.
  final Color color;

  /// Ring thickness. Ignored when [filled].
  final double strokeWidth;

  /// Filled disc instead of a ring.
  final bool filled;

  /// Concentric pulses, evenly phase-shifted.
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double baseRadius = size.shortestSide / 2;
    if (baseRadius <= 0) {
      return;
    }
    for (int i = 0; i < ringCount; i++) {
      final double phase = (progress.value + i / ringCount) % 1.0;
      final double opacity = JeebMotion.haloOpacity.transform(phase);
      if (opacity <= 0) {
        continue;
      }
      final Paint paint = Paint()
        ..color = color.withValues(alpha: color.a * opacity)
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(
        center,
        baseRadius * JeebMotion.haloScale.transform(phase),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(JHaloPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.filled != filled ||
      oldDelegate.ringCount != ringCount;
}

/// **jArcPulse** — `opacity .15 → 1 (at 35% of the cycle) → .15`, 2.4s
/// ease-in-out ∞, staggered .4s/.8s. The orbit-ring arcs behind heroes.
///
/// The 35% peak is the character of this primitive: a quick swell, a long decay.
/// It is a two-leg `TweenSequence` weighted 35/65 — a symmetric curve would peak
/// at 50% and read as a generic pulse.
///
/// Rest frame (reduce motion) = opacity .15, the faint arc the board draws at
/// rest. Every arc on the board is decoration; [JMotionRest.informative] exists
/// here only so the Q-037 rule holds for BOTH sub-.2 primitives rather than
/// arbitrarily one.
///
/// Stagger sibling arcs with [JeebMotion.arcPulseDelayA] /
/// [JeebMotion.arcPulseDelayB].
class JArcPulse extends StatelessWidget {
  const JArcPulse({
    super.key,
    required this.child,
    this.duration = JeebMotion.arcPulseDuration,
    this.delay = Duration.zero,
    this.rest = JMotionRest.decorative,
  });

  /// The arc — a painted stroke, an image, whatever the caller drew.
  final Widget child;

  /// One full swell-and-decay.
  final Duration duration;

  /// This arc's phase offset.
  final Duration delay;

  /// Which keyframe the still shows when animations are off. See [JMotionRest].
  final JMotionRest rest;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    restPhase: rest == JMotionRest.informative ? JeebMotion.arcPulsePeakAt : 0,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        FadeTransition(
          opacity: animation.drive(JeebMotion.arcPulseOpacity),
          child: c,
        ),
  );
}

/// **jBlink** — `opacity 1 ↔ 0`, HARD CUT, 1.1s step-end ∞. The live-transcript
/// caret.
///
/// Opacity is only ever exactly 1 or exactly 0: the cut is two `ConstantTween`s,
/// the Flutter spelling of CSS `step-end`. Any interpolation here turns a caret
/// into a throbbing smudge, so this is asserted in the tests.
///
/// Rest frame (reduce motion) = opacity 1 — the caret stays visible rather than
/// vanishing, since the first keyframe is the lit one.
class JBlink extends StatelessWidget {
  const JBlink({
    super.key,
    required this.child,
    this.duration = JeebMotion.blinkDuration,
    this.delay = Duration.zero,
  });

  /// The caret.
  final Widget child;

  /// One on+off cycle.
  final Duration duration;

  /// Phase offset. Rarely useful — a caret is usually alone.
  final Duration delay;

  @override
  Widget build(BuildContext context) => JMotionLoop(
    duration: duration,
    delay: delay,
    child: child,
    builder: (BuildContext context, Animation<double> animation, Widget? c) =>
        FadeTransition(
          opacity: animation.drive(JeebMotion.blinkOpacity),
          child: c,
        ),
  );
}
