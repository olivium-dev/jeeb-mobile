// Widget-level proof for the 7 wrapper primitives of §2.6. Each one is checked
// on three axes:
//
//   * **period** — one cycle takes exactly the duration the table gives, and the
//     rendered value at 0 / mid / full cycle is the keyframe, not an approximation;
//   * **rest frame** — under `MediaQuery.disableAnimations` the widget renders
//     the FIRST keyframe of its row, statically, and the tree settles;
//   * **stagger** — `delay` holds the rest frame first.
//
// `jDash` lives in `jeeb_motion_dash_test.dart`.
//
// Ticker seating: `pumpWidget` runs its frame before the controller's ticker has
// ticked, so every test seats it with a bare `tester.pump()` before advancing
// time (see `jeeb_motion_loop_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';

const Key _child = Key('motion-child');

Widget _host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

/// Current opacity of the single `FadeTransition` inside [primitive].
double _opacityOf(WidgetTester tester, Type primitive) {
  return tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(primitive),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;
}

/// Current uniform scale of the single `ScaleTransition` inside [primitive].
double _scaleOf(WidgetTester tester, Type primitive) {
  return tester
      .widget<ScaleTransition>(
        find.descendant(
          of: find.byType(primitive),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;
}

/// Current `scaleY` of the single `Transform` inside [primitive].
double _scaleYOf(WidgetTester tester, Type primitive) {
  return tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(primitive),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .entry(1, 1);
}

void main() {
  group('jFloat — translateY 0 → −7 → 0, 4s ease-in-out ∞', () {
    testWidgets('rises 7px at the half cycle and returns at the full one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const JFloat(child: SizedBox(key: _child, width: 20, height: 20))),
      );
      await tester.pump();

      final double rest = tester.getTopLeft(find.byKey(_child)).dy;
      await tester.pump(JeebMotion.floatDuration ~/ 2);
      expect(
        tester.getTopLeft(find.byKey(_child)).dy,
        closeTo(rest + JeebMotion.floatRise, 0.01),
      );
      await tester.pump(JeebMotion.floatDuration ~/ 2);
      expect(tester.getTopLeft(find.byKey(_child)).dy, closeTo(rest, 0.01));
    });

    testWidgets('paints without moving the layout slot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const JFloat(child: SizedBox(key: _child, width: 20, height: 20))),
      );
      await tester.pump();
      final Size size = tester.getSize(find.byType(JFloat));
      await tester.pump(JeebMotion.floatDuration ~/ 2);
      expect(tester.getSize(find.byType(JFloat)), size);
    });

    testWidgets('delay holds the rest frame', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const JFloat(
            delay: Duration(seconds: 1),
            child: SizedBox(key: _child, width: 20, height: 20),
          ),
        ),
      );
      await tester.pump();
      final double rest = tester.getTopLeft(find.byKey(_child)).dy;
      await tester.pump(JeebMotion.floatDuration ~/ 2);
      expect(
        tester.getTopLeft(find.byKey(_child)).dy,
        rest,
        reason: 'still inside the 1s delay',
      );
    });

    testWidgets('disableAnimations renders the rest frame statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JFloat(child: SizedBox(key: _child, width: 20, height: 20)),
          disableAnimations: true,
        ),
      );
      final double rest = tester.getTopLeft(find.byKey(_child)).dy;
      await tester.pump(JeebMotion.floatDuration ~/ 2);
      expect(tester.getTopLeft(find.byKey(_child)).dy, rest);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_child)).dy, rest);
    });
  });

  group('jTwinkle — opacity .2→1→.2 with scale .7→1.15→.7, 2.4s ∞', () {
    testWidgets('opacity and scale peak together at the half cycle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const JTwinkle(child: SizedBox(width: 8, height: 8))),
      );
      await tester.pump();

      expect(_opacityOf(tester, JTwinkle), JeebMotion.twinkleRestOpacity);
      expect(_scaleOf(tester, JTwinkle), JeebMotion.twinkleRestScale);

      await tester.pump(JeebMotion.twinkleDuration ~/ 2);
      expect(_opacityOf(tester, JTwinkle), closeTo(1, 0.001));
      expect(_scaleOf(tester, JTwinkle), closeTo(1.15, 0.001));

      await tester.pump(JeebMotion.twinkleDuration ~/ 2);
      expect(_opacityOf(tester, JTwinkle), closeTo(0.2, 0.001));
      expect(_scaleOf(tester, JTwinkle), closeTo(0.7, 0.001));
    });

    testWidgets('disableAnimations renders the rest frame statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JTwinkle(child: SizedBox(width: 8, height: 8)),
          disableAnimations: true,
        ),
      );
      await tester.pump(JeebMotion.twinkleDuration ~/ 2);
      expect(_opacityOf(tester, JTwinkle), JeebMotion.twinkleRestOpacity);
      expect(_scaleOf(tester, JTwinkle), JeebMotion.twinkleRestScale);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, JTwinkle), JeebMotion.twinkleRestOpacity);
    });
  });

  group('jBreathe — opacity .45→1→.45, ease-in-out ∞', () {
    testWidgets('peaks at the half cycle of the chosen period', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JBreathe(
            duration: JeebMotion.breatheDurationMin,
            child: SizedBox(width: 8, height: 8),
          ),
        ),
      );
      await tester.pump();

      expect(_opacityOf(tester, JBreathe), JeebMotion.breatheRestOpacity);
      await tester.pump(JeebMotion.breatheDurationMin ~/ 2);
      expect(_opacityOf(tester, JBreathe), closeTo(1, 0.001));
      await tester.pump(JeebMotion.breatheDurationMin ~/ 2);
      expect(_opacityOf(tester, JBreathe), closeTo(0.45, 0.001));
    });

    testWidgets('disableAnimations renders the rest frame statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JBreathe(child: SizedBox(width: 8, height: 8)),
          disableAnimations: true,
        ),
      );
      await tester.pump(JeebMotion.breatheDuration ~/ 2);
      expect(_opacityOf(tester, JBreathe), JeebMotion.breatheRestOpacity);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, JBreathe), JeebMotion.breatheRestOpacity);
    });
  });

  group('jWave — scaleY .5→1.15→.5, 1.3s ease-in-out ∞', () {
    testWidgets('scales vertically only, peaking at the half cycle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const JWaveBar(child: SizedBox(width: 4, height: 24))),
      );
      await tester.pump();

      expect(_scaleYOf(tester, JWaveBar), JeebMotion.waveRestScaleY);
      expect(
        tester
            .widget<Transform>(
              find.descendant(
                of: find.byType(JWaveBar),
                matching: find.byType(Transform),
              ),
            )
            .transform
            .entry(0, 0),
        1,
        reason: 'width must not move — bars keep their column',
      );

      await tester.pump(JeebMotion.waveDuration ~/ 2);
      expect(_scaleYOf(tester, JWaveBar), closeTo(1.15, 0.001));
      await tester.pump(JeebMotion.waveDuration ~/ 2);
      expect(_scaleYOf(tester, JWaveBar), closeTo(0.5, 0.001));
    });

    testWidgets('JWaveBars staggers each bar by one step', (
      WidgetTester tester,
    ) async {
      const Duration stagger = Duration(milliseconds: 100);
      await tester.pumpWidget(
        _host(
          const JWaveBars(
            stagger: stagger,
            bars: <Widget>[
              SizedBox(width: 4, height: 24),
              SizedBox(width: 4, height: 24),
              SizedBox(width: 4, height: 24),
            ],
          ),
        ),
      );
      await tester.pump();

      final List<JWaveBar> bars = tester
          .widgetList<JWaveBar>(find.byType(JWaveBar))
          .toList();
      expect(bars, hasLength(3));
      expect(bars[0].delay, Duration.zero);
      expect(bars[1].delay, stagger);
      expect(bars[2].delay, stagger * 2);

      // Bar 0 is running while bars 1 and 2 are still inside their delay.
      await tester.pump(const Duration(milliseconds: 50));
      final List<double> scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(JWaveBars),
              matching: find.byType(Transform),
            ),
          )
          .map((Transform t) => t.transform.entry(1, 1))
          .toList();
      expect(scales[0], greaterThan(JeebMotion.waveRestScaleY));
      expect(scales[1], JeebMotion.waveRestScaleY);
      expect(scales[2], JeebMotion.waveRestScaleY);
    });

    testWidgets('disableAnimations renders the rest frame statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JWaveBar(child: SizedBox(width: 4, height: 24)),
          disableAnimations: true,
        ),
      );
      await tester.pump(JeebMotion.waveDuration ~/ 2);
      expect(_scaleYOf(tester, JWaveBar), JeebMotion.waveRestScaleY);
      await tester.pumpAndSettle();
      expect(_scaleYOf(tester, JWaveBar), JeebMotion.waveRestScaleY);
    });
  });

  group('jHalo — scale .75→1.6 with opacity .8→0, 2.6s ease-out ∞', () {
    JHaloPainter painterOf(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(JHalo),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as JHaloPainter;

    testWidgets('runs one expansion per period', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const JHalo(
            color: Color(0xFFD73B00),
            child: SizedBox(width: 56, height: 56),
          ),
        ),
      );
      await tester.pump();

      // The ring is sized to the child's box (and overflows it as it expands);
      // a zero-size painter would make every other assertion here vacuous.
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(JHalo),
            matching: find.byType(CustomPaint),
          ),
        ),
        const Size(56, 56),
      );

      expect(painterOf(tester).progress.value, 0);
      await tester.pump(JeebMotion.haloDuration ~/ 2);
      expect(painterOf(tester).progress.value, closeTo(0.5, 0.001));
      // Full cycle: the ring has died and restarted, not reversed.
      await tester.pump(JeebMotion.haloDuration ~/ 2);
      expect(painterOf(tester).progress.value, closeTo(0, 0.001));
    });

    testWidgets('is fully transparent exactly when fully expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JHalo(
            color: Color(0xFFD73B00),
            child: SizedBox(width: 56, height: 56),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(JeebMotion.haloDuration - const Duration(milliseconds: 1));

      final double phase = painterOf(tester).progress.value;
      expect(
        JeebMotion.haloScale.transform(phase),
        closeTo(JeebMotion.haloEndScale, 0.01),
      );
      expect(JeebMotion.haloOpacity.transform(phase), closeTo(0, 0.01));
    });

    testWidgets('disableAnimations renders the rest frame statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JHalo(
            color: Color(0xFFD73B00),
            child: SizedBox(width: 56, height: 56),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump(JeebMotion.haloDuration ~/ 2);
      expect(painterOf(tester).progress.value, 0);
      await tester.pumpAndSettle();
      // Rest frame is a VISIBLE ring: scale .75 at opacity .8, not an empty box.
      expect(painterOf(tester).progress.value, 0);
      expect(JeebMotion.haloScale.transform(0), JeebMotion.haloStartScale);
      expect(JeebMotion.haloOpacity.transform(0), JeebMotion.haloStartOpacity);
    });
  });

  group('jArcPulse — opacity .15→1(@35%)→.15, 2.4s ∞', () {
    testWidgets('peaks at 35% of the cycle, not at the midpoint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const JArcPulse(child: SizedBox(width: 40, height: 40))),
      );
      await tester.pump();

      expect(_opacityOf(tester, JArcPulse), JeebMotion.arcPulseRestOpacity);

      await tester.pump(
        JeebMotion.arcPulseDuration * JeebMotion.arcPulsePeakAt,
      );
      expect(_opacityOf(tester, JArcPulse), closeTo(1, 0.001));

      // Half way through, the long decay leg has already pulled it back down.
      await tester.pump(
        JeebMotion.arcPulseDuration * (0.5 - JeebMotion.arcPulsePeakAt),
      );
      expect(_opacityOf(tester, JArcPulse), lessThan(1));

      await tester.pump(JeebMotion.arcPulseDuration ~/ 2);
      expect(
        _opacityOf(tester, JArcPulse),
        closeTo(JeebMotion.arcPulseRestOpacity, 0.001),
      );
    });

    testWidgets('disableAnimations renders the rest frame statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JArcPulse(child: SizedBox(width: 40, height: 40)),
          disableAnimations: true,
        ),
      );
      await tester.pump(JeebMotion.arcPulseDuration ~/ 2);
      expect(_opacityOf(tester, JArcPulse), JeebMotion.arcPulseRestOpacity);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, JArcPulse), JeebMotion.arcPulseRestOpacity);
    });
  });

  group('jBlink — opacity 1↔0 HARD CUT, 1.1s step-end ∞', () {
    testWidgets('opacity is only ever 0 or 1, switching at the half cycle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const JBlink(child: SizedBox(width: 2, height: 18))),
      );
      await tester.pump();

      // Sample the whole cycle at 20ms — 55 frames across 1.1s. A caret that
      // fades would land between 0 and 1 on most of them.
      const Duration step = Duration(milliseconds: 20);
      final List<double> samples = <double>[_opacityOf(tester, JBlink)];
      for (int i = 0; i < 110; i++) {
        await tester.pump(step);
        samples.add(_opacityOf(tester, JBlink));
      }
      for (final double opacity in samples) {
        expect(
          opacity == 0 || opacity == 1,
          isTrue,
          reason: 'jBlink must be a step, never a fade — saw $opacity',
        );
      }
      // Both states actually occur, and the cut happens once per half period.
      expect(samples, contains(1.0));
      expect(samples, contains(0.0));
      expect(samples.first, 1);
      expect(samples[27], 1, reason: '540ms — still lit');
      expect(samples[28], 0, reason: '560ms — cut');
      expect(samples[55], 1, reason: '1100ms — one full period, lit again');
      expect(samples[83], 0, reason: '1660ms — cut of the second cycle');
    });

    testWidgets('disableAnimations renders the rest frame statically (lit)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JBlink(child: SizedBox(width: 2, height: 18)),
          disableAnimations: true,
        ),
      );
      await tester.pump(JeebMotion.blinkDuration);
      expect(_opacityOf(tester, JBlink), 1);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, JBlink), 1);
    });
  });
}
