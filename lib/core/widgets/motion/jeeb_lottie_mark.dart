import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Player for the hand-authored Lottie compositions in `assets/animations/`
/// (authoring contract: `docs/redesign-2026-08/08-MOTION-SPEC.md`).
///
/// `Lottie.asset` on its own is not safe to drop into this app. Three things
/// have to be added around it, and they are the whole reason this widget exists:
///
/// **1 — It is always explicitly sized.** The compositions are authored at ~2×
/// their intended display size (spec §4) so strokes stay crisp; an unsized
/// `Lottie.asset` inside a `Column`/`ListView` would claim the raw canvas.
/// [width]/[height] are required and the mark is boxed to them.
///
/// **2 — Reduce motion is honoured.** When `MediaQuery.disableAnimationsOf` is
/// true the controller is pinned at 0 and the composition renders as its static
/// first frame. Nothing ticks, so nothing costs a frame — this is the
/// accessibility contract, not a nicety.
///
/// **3 — Loops are BOUNDED.** [cycles] plays run, then the mark rests on the
/// final frame. Every looping composition in the set is authored seamless
/// (frame `op` ≡ frame 0), so resting is visually identical to the loop's
/// starting state rather than a freeze mid-gesture.
///
/// The bound is not cosmetic. An unbounded `repeat: true` schedules frames
/// forever, which makes `WidgetTester.pumpAndSettle` time out on every test
/// that mounts the screen — measured, not assumed. The frozen kit already
/// settled this trade-off the same way (`JeebStepper`'s active-node glow is a
/// bounded 3-breath pulse "so `pumpAndSettle` stays safe either way"), so this
/// follows the house pattern rather than inventing a second one. See
/// `docs/redesign-2026-08/apply-reports/w3-motion-tracking.md` for the
/// measurement and for the open question of lifting the bound.
///
/// RTL: pass [mirrorInRtl] for the compositions the validation report flags as
/// directional (`courier-in-transit`, `loading-dots`, `onboarding-say-it`). The
/// other seven must NOT be mirrored and must leave it false.
///
/// The mark is decorative: it carries no semantics of its own, so the copy
/// beside it stays the only thing a screen reader announces.
class JeebLottieMark extends StatefulWidget {
  const JeebLottieMark({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    this.cycles = defaultCycles,
    this.mirrorInRtl = false,
  }) : assert(cycles > 0, 'cycles must be >= 1');

  /// How many times a looping mark plays before it rests.
  ///
  /// Six plays is ~24 s on the 4 s sonar canvases — long enough that the mark
  /// is still breathing through the moment it describes, short enough that a
  /// `pumpAndSettle` advances well inside its own 10-minute ceiling.
  static const int defaultCycles = 6;

  /// Asset key, e.g. `assets/animations/broadcasting.json`. Registered in
  /// `pubspec.yaml` (the whole `assets/animations/` directory).
  final String asset;

  final double width;
  final double height;

  /// Number of plays before the mark rests on its final frame.
  final int cycles;

  /// True only for the three compositions whose motion has a horizontal
  /// direction. Radial and vertical-motion files stay false — mirroring them
  /// is a defect, not a neutral no-op.
  final bool mirrorInRtl;

  @override
  State<JeebLottieMark> createState() => _JeebLottieMarkState();
}

class _JeebLottieMarkState extends State<JeebLottieMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Plays completed so far. Compared against `widget.cycles` to decide whether
  /// to re-arm.
  int _plays = 0;

  /// Set once the first play is armed, so a rebuild (theme, text scale, a
  /// countdown tick) cannot restart the mark from the top.
  bool _armed = false;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion is a MediaQuery read, so the decision to play cannot be
    // made in initState. Re-checked here so a user who turns the setting OFF
    // while the screen is up gets the motion.
    _armIfReady();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _plays++;
    if (!mounted || _plays >= widget.cycles || _reduceMotion) return;
    _controller.forward(from: 0);
  }

  /// Called from `onLoaded` (the first moment the composition's duration is
  /// known) and from `didChangeDependencies`.
  void _armIfReady() {
    if (_armed || _controller.duration == null) return;
    if (_reduceMotion) {
      // Rest on frame 0 — the static mark the composition opens with.
      _controller.value = 0;
      return;
    }
    _armed = true;
    _controller.forward(from: 0);
  }

  void _onLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    _armIfReady();
  }

  @override
  Widget build(BuildContext context) {
    Widget mark = Lottie.asset(
      widget.asset,
      controller: _controller,
      onLoaded: _onLoaded,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
    );
    if (widget.mirrorInRtl && Directionality.of(context) == TextDirection.rtl) {
      mark = Transform.flip(flipX: true, child: mark);
    }
    return ExcludeSemantics(
      child: SizedBox(width: widget.width, height: widget.height, child: mark),
    );
  }
}
