// Pins the §2.6 table itself — every duration, every keyframe value, and the
// two mappings that are easy to get subtly wrong:
//
//   * `jArcPulse` peaks at 35% of the cycle, not 50%. A plain sine or a
//     symmetric tween would pass a "it pulses" eyeball check and be wrong.
//   * `jBlink` is a HARD CUT: the tween must never emit a value between 0 and 1.
//
// Source of truth: docs/redesign-midnight/00-MASTER-PLAN.md §2.6.

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';

void main() {
  group('§2.6 timings', () {
    test('jFloat — 4s and 4.4s, staggered up to 1.2s', () {
      expect(JeebMotion.floatDuration, const Duration(seconds: 4));
      expect(JeebMotion.floatDurationSlow, const Duration(milliseconds: 4400));
      expect(JeebMotion.floatMaxDelay, const Duration(milliseconds: 1200));
      expect(JeebMotion.floatCurve, Curves.easeInOut);
    });

    test('jTwinkle — 2.4–3s, staggered .7s/1.3s', () {
      expect(JeebMotion.twinkleDuration, const Duration(milliseconds: 2400));
      expect(JeebMotion.twinkleDurationSlow, const Duration(seconds: 3));
      expect(JeebMotion.twinkleDelayA, const Duration(milliseconds: 700));
      expect(JeebMotion.twinkleDelayB, const Duration(milliseconds: 1300));
      expect(JeebMotion.twinkleCurve, Curves.easeInOut);
    });

    test('jBreathe — 1.6–3.6s range, default inside it', () {
      expect(JeebMotion.breatheDurationMin, const Duration(milliseconds: 1600));
      expect(JeebMotion.breatheDurationMax, const Duration(milliseconds: 3600));
      expect(
        JeebMotion.breatheDuration,
        greaterThanOrEqualTo(JeebMotion.breatheDurationMin),
      );
      expect(
        JeebMotion.breatheDuration,
        lessThanOrEqualTo(JeebMotion.breatheDurationMax),
      );
      expect(JeebMotion.breatheCurve, Curves.easeInOut);
    });

    test('jWave — 1.3s', () {
      expect(JeebMotion.waveDuration, const Duration(milliseconds: 1300));
      expect(JeebMotion.waveCurve, Curves.easeInOut);
    });

    test('jDash — 2s linear, −40px of travel', () {
      expect(JeebMotion.dashDuration, const Duration(seconds: 2));
      expect(JeebMotion.dashCurve, Curves.linear);
      expect(JeebMotion.dashTravel, -40);
    });

    test('jDash — the default dash period divides the travel (seamless loop)', () {
      const double period = JeebMotion.dashLength + JeebMotion.dashGap;
      expect(JeebMotion.dashTravel.abs() % period, 0);
    });

    test('jHalo — 2.6s ease-out', () {
      expect(JeebMotion.haloDuration, const Duration(milliseconds: 2600));
      expect(JeebMotion.haloCurve, Curves.easeOut);
    });

    test('jArcPulse — 2.4s, staggered .4s/.8s', () {
      expect(JeebMotion.arcPulseDuration, const Duration(milliseconds: 2400));
      expect(JeebMotion.arcPulseDelayA, const Duration(milliseconds: 400));
      expect(JeebMotion.arcPulseDelayB, const Duration(milliseconds: 800));
      expect(JeebMotion.arcPulseCurve, Curves.easeInOut);
    });

    test('jBlink — 1.1s', () {
      expect(JeebMotion.blinkDuration, const Duration(milliseconds: 1100));
    });
  });

  group('§2.6 keyframes', () {
    test('jFloat — translateY 0 → −7 → 0', () {
      expect(JeebMotion.floatOffset.transform(0), 0);
      expect(JeebMotion.floatOffset.transform(0.5), closeTo(-7, 1e-9));
      expect(JeebMotion.floatOffset.transform(1), closeTo(0, 1e-9));
      // Eased, not linear: an eighth of the cycle in (a quarter of the rising
      // leg) it has covered well under a quarter of the rise.
      expect(JeebMotion.floatOffset.transform(0.125), greaterThan(-1.75));
      expect(JeebMotion.floatOffset.transform(0.125), lessThan(0));
    });

    test('jTwinkle — opacity .2→1→.2 and scale .7→1.15→.7 in lockstep', () {
      expect(JeebMotion.twinkleOpacity.transform(0), 0.2);
      expect(JeebMotion.twinkleOpacity.transform(0.5), closeTo(1, 1e-9));
      expect(JeebMotion.twinkleOpacity.transform(1), closeTo(0.2, 1e-9));
      expect(JeebMotion.twinkleScale.transform(0), 0.7);
      expect(JeebMotion.twinkleScale.transform(0.5), closeTo(1.15, 1e-9));
      expect(JeebMotion.twinkleScale.transform(1), closeTo(0.7, 1e-9));
    });

    test('jBreathe — opacity .45→1→.45', () {
      expect(JeebMotion.breatheOpacity.transform(0), 0.45);
      expect(JeebMotion.breatheOpacity.transform(0.5), closeTo(1, 1e-9));
      expect(JeebMotion.breatheOpacity.transform(1), closeTo(0.45, 1e-9));
    });

    test('jWave — scaleY .5→1.15→.5', () {
      expect(JeebMotion.waveScaleY.transform(0), 0.5);
      expect(JeebMotion.waveScaleY.transform(0.5), closeTo(1.15, 1e-9));
      expect(JeebMotion.waveScaleY.transform(1), closeTo(0.5, 1e-9));
    });

    test('jDash — 0 → −40, strictly linear', () {
      expect(JeebMotion.dashOffset.transform(0), 0);
      expect(JeebMotion.dashOffset.transform(0.25), closeTo(-10, 1e-9));
      expect(JeebMotion.dashOffset.transform(0.5), closeTo(-20, 1e-9));
      expect(JeebMotion.dashOffset.transform(1), closeTo(-40, 1e-9));
    });

    test('jHalo — scale .75→1.6 while opacity .8→0', () {
      expect(JeebMotion.haloScale.transform(0), 0.75);
      expect(JeebMotion.haloOpacity.transform(0), 0.8);
      // The contract that keeps the restart invisible: fully expanded is fully
      // transparent.
      expect(JeebMotion.haloScale.transform(1), closeTo(1.6, 1e-9));
      expect(JeebMotion.haloOpacity.transform(1), closeTo(0, 1e-9));
      // Ease-out: most of the expansion is spent early.
      expect(JeebMotion.haloScale.transform(0.5), greaterThan(1.175));
    });

    test('jArcPulse — opacity .15 → 1 at exactly 35% → .15', () {
      expect(JeebMotion.arcPulseOpacity.transform(0), 0.15);
      expect(JeebMotion.arcPulseOpacity.transform(0.35), closeTo(1, 1e-9));
      expect(JeebMotion.arcPulseOpacity.transform(1), closeTo(0.15, 1e-9));
      // The peak is unique and lands at 35%, not at the midpoint — the whole
      // character of the primitive.
      expect(JeebMotion.arcPulseOpacity.transform(0.30), lessThan(1));
      expect(JeebMotion.arcPulseOpacity.transform(0.40), lessThan(1));
      expect(
        JeebMotion.arcPulseOpacity.transform(0.5),
        lessThan(JeebMotion.arcPulseOpacity.transform(0.35)),
      );
    });

    test('jBlink — HARD CUT: the tween emits only 0 or 1', () {
      for (int i = 0; i <= 1000; i++) {
        final double t = i / 1000;
        final double opacity = JeebMotion.blinkOpacity.transform(t);
        expect(
          opacity == 0 || opacity == 1,
          isTrue,
          reason: 'jBlink is step-end; t=$t interpolated to $opacity',
        );
      }
      expect(JeebMotion.blinkOpacity.transform(0), 1);
      expect(JeebMotion.blinkOpacity.transform(0.49), 1);
      expect(JeebMotion.blinkOpacity.transform(0.51), 0);
      expect(JeebMotion.blinkOpacity.transform(1), 0);
    });
  });

  group('stagger helpers', () {
    test('stagger spreads a group across the max delay', () {
      expect(JeebMotion.stagger(0, count: 4), Duration.zero);
      expect(JeebMotion.stagger(1, count: 4), const Duration(milliseconds: 400));
      expect(JeebMotion.stagger(2, count: 4), const Duration(milliseconds: 800));
      expect(JeebMotion.stagger(3, count: 4), JeebMotion.floatMaxDelay);
    });

    test('stagger of a lone element is zero', () {
      expect(JeebMotion.stagger(0, count: 1), Duration.zero);
    });

    test('spread interpolates a duration range and clamps', () {
      expect(
        JeebMotion.spread(
          JeebMotion.breatheDurationMin,
          JeebMotion.breatheDurationMax,
          0,
        ),
        JeebMotion.breatheDurationMin,
      );
      expect(
        JeebMotion.spread(
          JeebMotion.breatheDurationMin,
          JeebMotion.breatheDurationMax,
          0.5,
        ),
        const Duration(milliseconds: 2600),
      );
      expect(
        JeebMotion.spread(
          JeebMotion.breatheDurationMin,
          JeebMotion.breatheDurationMax,
          2,
        ),
        JeebMotion.breatheDurationMax,
      );
    });

    test('floatOffsetFor keeps the 0 → rise → 0 shape at another amplitude', () {
      final Animatable<double> tall = JeebMotion.floatOffsetFor(-14);
      expect(tall.transform(0), 0);
      expect(tall.transform(0.5), closeTo(-14, 1e-9));
      expect(tall.transform(1), closeTo(0, 1e-9));
    });
  });
}
