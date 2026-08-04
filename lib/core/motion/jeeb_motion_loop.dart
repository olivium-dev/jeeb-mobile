// The one looping harness every §2.6 primitive is built on.
//
// Screens must never own an `AnimationController` for Midnight motion. Three
// contracts live here so no call site can get them wrong:
//
//   1. **Reduce motion.** `MediaQuery.disableAnimationsOf` pins the controller
//      at [JMotionLoop.restPhase] and STOPS the ticker — no frames are scheduled
//      at all. The pin is absolute, never "wherever the cycle had reached", so a
//      still is deterministic whether motion was off at mount or switched off
//      mid-cycle. Because every §2.6 `Animatable` puts the row's FIRST keyframe
//      at 0, the default phase 0 is exactly "render the rest frame". Q-037 lets
//      an information-bearing element pin its LIT keyframe instead — see
//      `JMotionRest`.
//   2. **Delay = stagger.** `delay` reproduces CSS `animation-delay`: the FIRST
//      keyframe is held for the delay, then the loop starts. The timer is cancelled
//      on dispose and on any reduce-motion change, so nothing outlives the tree.
//   3. **The loop is infinite**, as the board's `∞` says. That is a deliberate
//      difference from `JeebLottieMark`, whose loops are bounded so
//      `pumpAndSettle` terminates. A screen mounting Midnight motion must be
//      tested with `tester.pump(<duration>)`; `pumpAndSettle` will time out
//      while a primitive is animating (it returns immediately under reduce
//      motion, which is the supported way to settle a tree that mounts them).

import 'dart:async';

import 'package:flutter/material.dart';

/// Signature for [JMotionLoop.builder].
///
/// [animation] runs 0→1 over one cycle, forever. `child` is passed straight
/// through from [JMotionLoop.child] so subtrees that do not depend on the
/// animation are built once, not once per frame.
typedef JMotionBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Widget? child,
    );

/// A repeating 0→1 animation with the Midnight reduce-motion and stagger
/// contracts baked in.
///
/// The 8 primitives (`JFloat`, `JTwinkle`, `JBreathe`, `JWaveBar`, `JDashOffset`,
/// `JHalo`, `JArcPulse`, `JBlink`) are thin wrappers over this. Use it directly
/// only for motion the 8 do not cover — a `CustomPainter` that needs the raw
/// phase, say — so that the new motion inherits the same contracts.
///
/// [builder] is called on BUILD, not per frame: it receives the `Animation` and
/// is expected to hand it to a `FadeTransition`/`ScaleTransition`/
/// `AnimatedBuilder`/`CustomPaint(repaint:)`, which repaint without rebuilding.
class JMotionLoop extends StatefulWidget {
  const JMotionLoop({
    super.key,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
    this.restPhase = 0,
    this.child,
  }) : assert(duration > Duration.zero, 'duration must be positive'),
       assert(delay >= Duration.zero, 'delay cannot be negative'),
       assert(
         restPhase >= 0 && restPhase <= 1,
         'restPhase must be a 0..1 cycle phase',
       );

  /// One full cycle of the primitive.
  final Duration duration;

  /// Held at phase 0 before the loop starts — CSS `animation-delay`. This is the
  /// board's pre-roll and is deliberately NOT [restPhase]: staggering is about
  /// the animated frame the element waits on, reduce motion about the still it
  /// ships instead.
  final Duration delay;

  /// The cycle phase the controller is pinned to under reduce motion.
  ///
  /// 0 — the row's first keyframe — for everything decorative. Pass a peak phase
  /// only for an element whose first keyframe would hide information a sighted
  /// user needs (Q-037); the primitives spell that as `JMotionRest.informative`
  /// rather than a raw number.
  final double restPhase;

  /// Builds the animated subtree. See [JMotionBuilder].
  final JMotionBuilder builder;

  /// Passed to [builder] untouched; use it for anything the animation does not
  /// affect.
  final Widget? child;

  @override
  State<JMotionLoop> createState() => _JMotionLoopState();
}

class _JMotionLoopState extends State<JMotionLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  Timer? _delayTimer;

  /// Null until the first dependency resolution. Tracked so an unrelated
  /// inherited-widget change (a theme swap, a keyboard inset) does not restart
  /// the loop mid-cycle.
  bool? _appliedReduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(JMotionLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.duration != widget.duration ||
        oldWidget.delay != widget.delay ||
        oldWidget.restPhase != widget.restPhase) {
      _sync(force: true);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _sync({bool force = false}) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!force && reduceMotion == _appliedReduceMotion) {
      return;
    }
    _appliedReduceMotion = reduceMotion;
    _delayTimer?.cancel();
    _delayTimer = null;
    if (reduceMotion) {
      // Stop first: assigning `value` on a running controller would leave the
      // ticker scheduling frames forever against a pinned value.
      _controller
        ..stop()
        ..value = widget.restPhase;
      return;
    }
    _controller.value = 0;
    if (widget.delay == Duration.zero) {
      _controller.repeat();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _controller.view, widget.child);
}
