// The MIDNIGHT motion tokens — durations, curves, keyframe values and the
// ready-made `Animatable`s for the 8 primitives extracted from the board CSS
// (`docs/redesign-midnight/00-MASTER-PLAN.md` §2.6).
//
// This file is deliberately theme-free: it imports `package:flutter/animation.dart`
// and nothing else. Motion ships GEOMETRY and OPACITY only — every colour is the
// consumer's to choose, so nothing here may reach into `lib/core/theme`.
//
// Two mapping rules govern the whole sheet, and they are what make the Flutter
// output identical to the board rather than merely similar:
//
//   1. A CSS `animation-timing-function` applies BETWEEN EACH PAIR of adjacent
//      keyframes, not once across the whole cycle. So a 3-keyframe primitive
//      (`0% → 50% → 100%`) becomes a `TweenSequence` of two legs, each with its
//      own `CurveTween` — never one curve stretched over the cycle, and never a
//      sine.
//   2. Controller value 0 is ALWAYS the first keyframe of the row. That is what
//      lets `JMotionLoop` render the reduce-motion rest frame by simply pinning
//      the controller at 0 (see `jeeb_motion_loop.dart`).

import 'package:flutter/animation.dart';

/// Named constants and `Animatable`s for the 8 Midnight motion primitives.
///
/// Consume through the wrapper widgets (`JFloat`, `JTwinkle`, …) wherever the
/// motion is a whole-widget effect; reach for the raw `Animatable`s here only
/// when painting inside a `CustomPainter`, where the curve has to be sampled by
/// hand.
abstract final class JeebMotion {
  // ---------------------------------------------------------------- jFloat --
  // | `jFloat` | translateY 0 → −7px → 0 | 4s / 4.4s ease-in-out ∞
  // | (delays up to 1.2s) | floating illustrations, walkthrough art |

  /// The board's primary float period.
  static const Duration floatDuration = Duration(seconds: 4);

  /// The board's second float period. Pairing two periods across a group is how
  /// the board keeps floating art from marching in lockstep; combine it with a
  /// [stagger] delay for the full effect.
  static const Duration floatDurationSlow = Duration(milliseconds: 4400);

  /// Applied to EACH leg (0→−7 and −7→0), per mapping rule 1.
  static const Curve floatCurve = Curves.easeInOut;

  /// Peak vertical displacement, in logical pixels. Negative = upward, matching
  /// the CSS `translateY(-7px)`.
  static const double floatRise = -7;

  /// Upper bound of the board's float stagger. Feed [stagger] with this.
  static const Duration floatMaxDelay = Duration(milliseconds: 1200);

  // -------------------------------------------------------------- jTwinkle --
  // | `jTwinkle` | opacity .2→1→.2, scale .7→1.15→.7 | 2.4–3s ease-in-out ∞,
  // | staggered .7s/1.3s | star dots around illustrations |

  /// Fast end of the board's twinkle range — the default period.
  static const Duration twinkleDuration = Duration(milliseconds: 2400);

  /// Slow end of the board's twinkle range (3s). Mix it into a star field so no
  /// two neighbours share a period.
  static const Duration twinkleDurationSlow = Duration(seconds: 3);

  /// Applied to each of the two legs.
  static const Curve twinkleCurve = Curves.easeInOut;

  /// Twinkle rest opacity — also the reduce-motion still frame.
  static const double twinkleRestOpacity = 0.2;

  /// Twinkle peak opacity, reached at 50% of the cycle.
  static const double twinklePeakOpacity = 1;

  /// Twinkle rest scale — also the reduce-motion still frame.
  static const double twinkleRestScale = 0.7;

  /// Twinkle peak scale, reached at 50% of the cycle.
  static const double twinklePeakScale = 1.15;

  /// Where in the cycle the twinkle peak lands — the phase a UI-bearing twinkle
  /// rests on under reduce motion (Q-037). Symmetric, so exactly the midpoint.
  static const double twinklePeakAt = 0.5;

  /// First of the board's two twinkle stagger delays.
  static const Duration twinkleDelayA = Duration(milliseconds: 700);

  /// Second of the board's two twinkle stagger delays.
  static const Duration twinkleDelayB = Duration(milliseconds: 1300);

  // -------------------------------------------------------------- jBreathe --
  // | `jBreathe` | opacity .45→1→.45 | 1.6–3.6s ease-in-out ∞, staggered
  // | glows, live dots ("Broadcasting"), halos at rest |

  /// Fast end of the board's breathe range (an urgent live dot).
  static const Duration breatheDurationMin = Duration(milliseconds: 1600);

  /// Slow end of the board's breathe range (a resting glow).
  static const Duration breatheDurationMax = Duration(milliseconds: 3600);

  /// Default breathe period.
  ///
  /// **Derived**: §2.6 gives a 1.6–3.6s RANGE and no single value, because the
  /// board breathes different elements at different rates. This is the midpoint
  /// and is what a caller gets when it does not choose; pick deliberately with
  /// [spread] when several glows share a screen.
  static const Duration breatheDuration = Duration(milliseconds: 2600);

  /// Applied to each of the two legs.
  static const Curve breatheCurve = Curves.easeInOut;

  /// Breathe rest opacity — also the reduce-motion still frame.
  static const double breatheRestOpacity = 0.45;

  /// Breathe peak opacity, reached at 50% of the cycle.
  static const double breathePeakOpacity = 1;

  // ----------------------------------------------------------------- jWave --
  // | `jWave` | scaleY .5→1.15→.5 | 1.3s ease-in-out ∞ (per-bar stagger)
  // | **voice waveform bars** |

  /// The waveform bar period.
  static const Duration waveDuration = Duration(milliseconds: 1300);

  /// Applied to each of the two legs.
  static const Curve waveCurve = Curves.easeInOut;

  /// Bar rest height factor — also the reduce-motion still frame. Bars park at
  /// half height, which is why a reduce-motion waveform still reads as a
  /// waveform rather than as a flat line.
  static const double waveRestScaleY = 0.5;

  /// Bar peak height factor, reached at 50% of the cycle.
  static const double wavePeakScaleY = 1.15;

  /// Default step between adjacent bars in a row.
  ///
  /// **Derived**: §2.6 says "per-bar stagger" without a number. 120ms over the
  /// 1.3s period walks the crest across roughly 11 bars per cycle, which is the
  /// board's read on a ~9-bar waveform. Override per call site if the bar count
  /// differs a lot.
  static const Duration waveBarStagger = Duration(milliseconds: 120);

  // ----------------------------------------------------------------- jDash --
  // | `jDash` | stroke-dashoffset → −40 | 2s linear ∞ | dashed route/orbit
  // | lines (map path, rings) |

  /// The dash-travel period.
  static const Duration dashDuration = Duration(seconds: 2);

  /// Dash travel is uniform — the marching-ants effect stutters under any easing.
  static const Curve dashCurve = Curves.linear;

  /// Total dash-offset travel per cycle, in logical pixels. Negative = the
  /// dashes advance along the path direction, exactly as in SVG.
  static const double dashTravel = -40;

  /// Default dash length.
  ///
  /// **Derived**: §2.6 fixes the travel (−40) but not the dash pattern, which is
  /// per-path geometry. 5 + 5 is chosen so the 10px period divides 40 exactly —
  /// a pattern whose period does not divide the travel visibly JUMPS at the loop
  /// point. Any override should keep `(dashLength + gapLength)` a divisor of
  /// `dashTravel.abs()`.
  static const double dashLength = 5;

  /// Default gap length. See [dashLength] for why 5 + 5.
  static const double dashGap = 5;

  // ----------------------------------------------------------------- jHalo --
  // | `jHalo` | scale .75→1.6, opacity .8→0 | 2.6s ease-out ∞
  // | **mic halo pulse** |

  /// The halo pulse period.
  static const Duration haloDuration = Duration(milliseconds: 2600);

  /// One leg only: the halo never returns, it expands away and restarts.
  static const Curve haloCurve = Curves.easeOut;

  /// Radius factor the ring starts at — also the reduce-motion still frame,
  /// which is therefore a visible ring hugging the child, not an empty box.
  static const double haloStartScale = 0.75;

  /// Radius factor the ring dies at.
  static const double haloEndScale = 1.6;

  /// Opacity the ring starts at.
  static const double haloStartOpacity = 0.8;

  /// Opacity the ring dies at. Zero at full scale is what keeps the restart
  /// invisible.
  static const double haloEndOpacity = 0;

  // ------------------------------------------------------------- jArcPulse --
  // | `jArcPulse` | opacity .15→1(@35%)→.15 | 2.4s ease-in-out ∞, staggered
  // | .4s/.8s | orbit-ring arcs behind heroes |

  /// The arc pulse period.
  static const Duration arcPulseDuration = Duration(milliseconds: 2400);

  /// Applied to each of the two legs.
  static const Curve arcPulseCurve = Curves.easeInOut;

  /// Arc rest opacity — also the reduce-motion still frame.
  static const double arcPulseRestOpacity = 0.15;

  /// Arc peak opacity.
  static const double arcPulsePeakOpacity = 1;

  /// Where in the cycle the peak lands. The 35/65 asymmetry is the whole
  /// character of this primitive — a quick swell and a long decay — so it is a
  /// `TweenSequence` with 35/65 weights, never a symmetric curve.
  static const double arcPulsePeakAt = 0.35;

  /// First of the board's two arc stagger delays.
  static const Duration arcPulseDelayA = Duration(milliseconds: 400);

  /// Second of the board's two arc stagger delays.
  static const Duration arcPulseDelayB = Duration(milliseconds: 800);

  // ---------------------------------------------------------------- jBlink --
  // | `jBlink` | opacity 1↔0 hard cut | 1.1s step-end ∞ | live-transcript caret |

  /// The caret blink period — one full on+off cycle.
  static const Duration blinkDuration = Duration(milliseconds: 1100);

  /// Fraction of the cycle the caret is lit. `step-end` means the switch is
  /// instantaneous: opacity is only ever exactly 1 or exactly 0, never between.
  static const double blinkOnFraction = 0.5;

  // ------------------------------------------------------------- Animatables --

  /// jFloat vertical offset in logical pixels: `0 → floatRise → 0`, each leg
  /// eased in-out.
  static final Animatable<double> floatOffset = floatOffsetFor(floatRise);

  /// jTwinkle opacity: `.2 → 1 → .2`, each leg eased in-out.
  static final Animatable<double> twinkleOpacity = _symmetric(
    twinkleRestOpacity,
    twinklePeakOpacity,
    twinkleCurve,
  );

  /// jTwinkle scale: `.7 → 1.15 → .7`, each leg eased in-out.
  static final Animatable<double> twinkleScale = _symmetric(
    twinkleRestScale,
    twinklePeakScale,
    twinkleCurve,
  );

  /// jBreathe opacity: `.45 → 1 → .45`, each leg eased in-out.
  static final Animatable<double> breatheOpacity = _symmetric(
    breatheRestOpacity,
    breathePeakOpacity,
    breatheCurve,
  );

  /// jWave vertical scale: `.5 → 1.15 → .5`, each leg eased in-out.
  static final Animatable<double> waveScaleY = _symmetric(
    waveRestScaleY,
    wavePeakScaleY,
    waveCurve,
  );

  /// jDash offset: `0 → −40`, linear, restarting each cycle.
  static final Animatable<double> dashOffset = dashOffsetFor(dashTravel);

  /// jHalo radius factor: `.75 → 1.6`, eased out.
  static final Animatable<double> haloScale = Tween<double>(
    begin: haloStartScale,
    end: haloEndScale,
  ).chain(CurveTween(curve: haloCurve));

  /// jHalo opacity: `.8 → 0`, eased out — the same curve drives both, as one
  /// CSS animation on one element.
  static final Animatable<double> haloOpacity = Tween<double>(
    begin: haloStartOpacity,
    end: haloEndOpacity,
  ).chain(CurveTween(curve: haloCurve));

  /// jArcPulse opacity: `.15 → 1` over the first 35% of the cycle, then
  /// `1 → .15` over the remaining 65%, each leg eased in-out.
  static final Animatable<double> arcPulseOpacity = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: arcPulseRestOpacity,
          end: arcPulsePeakOpacity,
        ).chain(CurveTween(curve: arcPulseCurve)),
        weight: arcPulsePeakAt * 100,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: arcPulsePeakOpacity,
          end: arcPulseRestOpacity,
        ).chain(CurveTween(curve: arcPulseCurve)),
        weight: (1 - arcPulsePeakAt) * 100,
      ),
    ],
  );

  /// jBlink opacity: hard cut between 1 and 0 at the half-cycle.
  ///
  /// Two `ConstantTween`s, so the output is only ever 1 or 0 — this is the
  /// Flutter spelling of CSS `step-end` and the reason a caret reads as a caret
  /// instead of a pulsing smudge.
  static final Animatable<double> blinkOpacity = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1),
        weight: blinkOnFraction * 100,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: (1 - blinkOnFraction) * 100,
      ),
    ],
  );

  // ------------------------------------------------------------- Factories --

  /// jFloat with a non-default amplitude. Use [floatOffset] unless a surface
  /// genuinely needs a different rise.
  static Animatable<double> floatOffsetFor(double rise) =>
      _symmetric(0, rise, floatCurve);

  /// jDash with a non-default travel. Keep `travel.abs()` an exact multiple of
  /// the dash period or the loop point will jump — see [dashLength].
  static Animatable<double> dashOffsetFor(double travel) =>
      Tween<double>(begin: 0, end: travel);

  // ---------------------------------------------------------------- Helpers --

  /// Even stagger for a group: the delay for element [index] of [count],
  /// spread across `[Duration.zero, max]`.
  ///
  /// A single element gets no delay; the last element of a group gets [max].
  static Duration stagger(
    int index, {
    required int count,
    Duration max = floatMaxDelay,
  }) {
    assert(index >= 0 && index < count, 'index must be inside 0..count-1');
    if (count <= 1) {
      return Duration.zero;
    }
    return max * (index / (count - 1));
  }

  /// Linear interpolation between two periods, for the primitives §2.6 gives as
  /// a range (`jBreathe` 1.6–3.6s, `jTwinkle` 2.4–3s). `t` is clamped to 0..1.
  static Duration spread(Duration min, Duration max, double t) {
    final double clamped = t.clamp(0, 1).toDouble();
    return Duration(
      microseconds:
          (min.inMicroseconds +
                  (max.inMicroseconds - min.inMicroseconds) * clamped)
              .round(),
    );
  }

  /// `a → b → a`, each leg carrying [curve] — the shape of every 3-keyframe row
  /// in the §2.6 table.
  static Animatable<double> _symmetric(double a, double b, Curve curve) {
    return TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: a, end: b).chain(CurveTween(curve: curve)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: b, end: a).chain(CurveTween(curve: curve)),
        weight: 50,
      ),
    ]);
  }
}
