// `JMotionLoop` carries the three contracts every §2.6 primitive inherits, so
// they are pinned once here rather than eight times:
//
//   1. the loop is infinite and its period is the declared duration;
//   2. `delay` holds the rest frame (controller 0) and only then starts — the
//      board's stagger;
//   3. `MediaQuery.disableAnimations` pins the rest frame AND schedules no
//      frames at all, which is what makes `pumpAndSettle` terminate.
//
// Ticker seating note: `pumpWidget` runs its frame BEFORE the controller's
// ticker has ticked once, so every test seats the ticker with a bare
// `tester.pump()` first. Without it every subsequent elapsed duration is off by
// one frame and the period assertions drift.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';

const Duration _period = Duration(seconds: 2);

void main() {
  /// Mounts a loop and returns a getter for its current 0→1 phase.
  Future<double Function()> pumpLoop(
    WidgetTester tester, {
    bool disableAnimations = false,
    Duration delay = Duration.zero,
    Duration duration = _period,
    double textScale = 1,
    double restPhase = 0,
  }) async {
    Animation<double>? captured;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: JMotionLoop(
            duration: duration,
            delay: delay,
            restPhase: restPhase,
            builder: (BuildContext context, Animation<double> animation, _) {
              captured = animation;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return () => captured!.value;
  }

  testWidgets('loops forever at the declared period', (
    WidgetTester tester,
  ) async {
    final double Function() phase = await pumpLoop(tester);

    expect(phase(), 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase(), closeTo(0.25, 0.001));
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase(), closeTo(0.5, 0.001));
    // Third cycle: still running, still in phase — the ∞ of the board.
    await tester.pump(_period * 2);
    expect(phase(), closeTo(0.5, 0.001));
    // Half a period further wraps back through the top of the cycle.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(phase(), closeTo(0, 0.001));
  });

  testWidgets('delay holds the rest frame, then the loop starts', (
    WidgetTester tester,
  ) async {
    final double Function() phase = await pumpLoop(
      tester,
      delay: const Duration(milliseconds: 800),
    );

    expect(phase(), 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(phase(), 0, reason: 'still inside the delay');
    // Cross the delay, then a quarter period past it.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase(), closeTo(0.25, 0.001));
  });

  testWidgets('disableAnimations pins phase 0 and schedules no frames', (
    WidgetTester tester,
  ) async {
    final double Function() phase = await pumpLoop(
      tester,
      disableAnimations: true,
    );

    expect(phase(), 0);
    await tester.pump(_period);
    expect(phase(), 0);
    // Nothing is ticking, so the tree settles — this is the only way a screen
    // that mounts Midnight motion can be `pumpAndSettle`d.
    await tester.pumpAndSettle();
    expect(phase(), 0);
  });

  testWidgets('disableAnimations arriving mid-loop parks on the rest frame', (
    WidgetTester tester,
  ) async {
    Animation<double>? captured;
    Widget host({required bool disableAnimations}) => MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: JMotionLoop(
          duration: _period,
          builder: (BuildContext context, Animation<double> animation, _) {
            captured = animation;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(host(disableAnimations: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(captured!.value, closeTo(0.25, 0.001));

    await tester.pumpWidget(host(disableAnimations: true));
    expect(captured!.value, 0);
    await tester.pumpAndSettle();
    expect(captured!.value, 0);
  });

  testWidgets('an unrelated MediaQuery change does not restart the loop', (
    WidgetTester tester,
  ) async {
    Animation<double>? captured;
    Widget host({required double textScale}) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: JMotionLoop(
          duration: _period,
          builder: (BuildContext context, Animation<double> animation, _) {
            captured = animation;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(host(textScale: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(captured!.value, closeTo(0.25, 0.001));

    await tester.pumpWidget(host(textScale: 2));
    expect(
      captured!.value,
      closeTo(0.25, 0.001),
      reason: 'a text-scale change must not rewind the animation',
    );
  });

  group('restPhase — the Q-037 seam', () {
    testWidgets('pins the still at the chosen phase, not at 0', (
      WidgetTester tester,
    ) async {
      final double Function() phase = await pumpLoop(
        tester,
        disableAnimations: true,
        restPhase: 0.35,
      );

      expect(phase(), 0.35);
      await tester.pump(_period);
      expect(phase(), 0.35);
      await tester.pumpAndSettle();
      expect(phase(), 0.35, reason: 'pinned AND not ticking');
    });

    testWidgets('a mid-cycle switch lands on restPhase, not where it froze', (
      WidgetTester tester,
    ) async {
      Animation<double>? captured;
      Widget host({required bool disableAnimations}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: JMotionLoop(
            duration: _period,
            restPhase: 0.35,
            builder: (BuildContext context, Animation<double> animation, _) {
              captured = animation;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(host(disableAnimations: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      expect(captured!.value, closeTo(0.7, 0.001));

      await tester.pumpWidget(host(disableAnimations: true));
      expect(captured!.value, 0.35);
      await tester.pumpAndSettle();
      expect(captured!.value, 0.35);
    });

    testWidgets('leaves the running loop and the stagger pre-roll on 0', (
      WidgetTester tester,
    ) async {
      final double Function() phase = await pumpLoop(
        tester,
        restPhase: 0.35,
        delay: const Duration(milliseconds: 800),
      );

      expect(
        phase(),
        0,
        reason: 'the stagger holds the FIRST keyframe, always',
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(phase(), 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        phase(),
        closeTo(0.25, 0.001),
        reason: 'the cycle still starts at 0',
      );
    });

    testWidgets('changing restPhase re-pins an already-still loop', (
      WidgetTester tester,
    ) async {
      Animation<double>? captured;
      Widget host({required double restPhase}) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: JMotionLoop(
            duration: _period,
            restPhase: restPhase,
            builder: (BuildContext context, Animation<double> animation, _) {
              captured = animation;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(host(restPhase: 0));
      expect(captured!.value, 0);
      await tester.pumpWidget(host(restPhase: 0.5));
      expect(captured!.value, 0.5);
    });

    test('a phase outside 0..1 is rejected at construction', () {
      Widget builder(BuildContext context, Animation<double> a, Widget? c) =>
          const SizedBox.shrink();
      expect(
        () => JMotionLoop(duration: _period, restPhase: 1.5, builder: builder),
        throwsAssertionError,
      );
      expect(
        () => JMotionLoop(duration: _period, restPhase: -0.1, builder: builder),
        throwsAssertionError,
      );
    });
  });

  testWidgets('disposing while the stagger delay is pending leaks no timer', (
    WidgetTester tester,
  ) async {
    await pumpLoop(tester, delay: const Duration(seconds: 30));
    // Tearing the tree down mid-delay: the test framework fails the test if the
    // timer outlives it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
