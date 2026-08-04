import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';

/// The three realized states of a step. Derived from `currentIndex`, never
/// passed in — one source of truth means the two forms cannot disagree.
enum _JeebStepState { done, active, pending }

/// Which ink [JeebStepper.bars] fills its **passed** segments with.
///
/// The board tiles that draw the bar form genuinely disagree, so the fill is a
/// parameter rather than a per-screen repaint: R18 washes the passed run WHITE,
/// R3 (live tracking) runs it ORANGE so the fill reads as one continuous bar up
/// to and including the active segment.
///
/// The ink is resolved from the theme inside the kit — a raw [Color] here
/// would push a semantic colour literal back out into `lib/features`.
/// Bar form only: the node form's connectors are always periwinkle.
enum JeebStepperDoneInk {
  /// `colorScheme.secondary`. The default, and what every caller drew before
  /// this parameter existed.
  periwinkle,

  /// `jeebRoles.accent`, against the orange budget on the tiles that draw it.
  accent,

  /// R18's measured white wash. Deliberately OFF the 7/10/14 glass ladder —
  /// a stepper ink, not a new glass rung (wave-C ruling 11).
  washed,
}

/// The linear-progress widget (redesign-2026-08 §5 #11), in its **two realized
/// forms**.
///
///  * The unnamed constructor is screen 12's **node** stepper: Ø26 nodes with
///    labels beneath and 3px connectors between them. It carries the frozen
///    `tracking_step_*` Maestro identifiers, one Semantics node per step.
///  * [JeebStepper.bars] is screen 18's **bar** stepper: `flex:1` h5 segments
///    with no nodes and no kit-side labels (18 keeps its own `_StageLabel` row,
///    which owns the frozen `active_delivery_stage_*` identifiers).
///
/// **Both forms are a plain [Row].** No [Stack], no [Positioned], no
/// left/right: progress reads start→end and mirrors for free under RTL. This is
/// the single hardest RTL surface in the kit and the reason the form is
/// prescribed rather than left to the consumer.
///
/// Presentation-only: every value arrives through the constructor.
class JeebStepper extends StatelessWidget {
  /// Screen 12's node form.
  ///
  /// [labels] and [stepIdentifiers] are 1:1 and index-aligned; [currentIndex]
  /// is 0-based. Steps before it are `done`, the one at it is `active`, the
  /// rest `pending`.
  const JeebStepper({
    super.key,
    required this.currentIndex,
    required this.labels,
    required this.stepIdentifiers,
    this.pulseActive = false,
    this.identifier,
    this.semanticLabel,
  })  : segmentKeys = null,
        doneInk = JeebStepperDoneInk.periwinkle,
        _barCount = 0,
        _isBars = false;

  /// Screen 18's bar form (§5 #11 correction, `per-screen-revised/18` §8).
  ///
  /// The bars carry no semantics at all — they are wrapped in
  /// [ExcludeSemantics] — because 18's label row beneath already owns the
  /// frozen `active_delivery_stage_<name>` identifiers and the
  /// `'<Label>, <State>'` a11y strings. [segmentKeys] re-homes that screen's
  /// `ValueKey<String>('active_delivery_stage_<name>_<state>')`s onto the
  /// segments so its `find.byKey` family keeps passing unedited.
  ///
  /// [doneInk] selects the passed-segment fill; it defaults to periwinkle, so
  /// existing call sites are unaffected.
  const JeebStepper.bars({
    super.key,
    required int stepCount,
    required this.currentIndex,
    this.doneInk = JeebStepperDoneInk.periwinkle,
    this.segmentKeys,
    this.identifier,
    this.semanticLabel,
  })  : labels = const <String>[],
        stepIdentifiers = const <String>[],
        pulseActive = false,
        _barCount = stepCount,
        _isBars = true,
        assert(
          stepCount >= 2,
          'JeebStepper.bars: a stepper needs at least two segments.',
        );

  // ── Node form, measured from 12 `tpl 728-748` ────────────────────────────

  /// Ø26 — the node diameter in all three states.
  static const double nodeSize = 26;

  /// 14px white check glyph inside a `done` node.
  static const double checkSize = 14;

  /// Ø8 white core inside an `active` node.
  static const double activeCoreSize = 8;

  /// `2px glassBorderStrong` ring — the whole of a `pending` node.
  /// The board is `box-sizing: border-box`, and a Flutter [Border] paints
  /// inside the box, so Ø26 stays Ø26 (no correction needed here, unlike
  /// `JeebOutlinedCard`'s padding fold).
  static const double pendingRingWidth = 2;

  /// Gap between a node and its label.
  static const double nodeLabelGap = 5;

  /// Connector `height 3, r8` (the board draws r9 on a 3px bar — either way it
  /// is a stadium; 9 is the measured value).
  static const double connectorHeight = 3;

  /// Connector corner radius.
  static const double connectorRadius = JeebRadii.sm;

  /// The connector's `margin-top`, which centres it on the Ø26 node while the
  /// row stays [CrossAxisAlignment.start] (so labels of different heights do
  /// not shove the nodes around).
  static const double connectorTopInset = 12;

  // ── Bar form, measured from 18 `tpl 1047-1051` ───────────────────────────

  /// Segment height.
  static const double barHeight = 5;

  /// Segment corner radius — board `border-radius: 9px`.
  static const double barRadius = JeebRadii.sm;

  /// Gap between segments — board `gap: 6px`.
  static const double barGap = 6;

  /// The active segment's live glow — board `0 0 14px rgba(215,59,0,.7)`,
  /// which is [JeebShadows.glowDot] on the Midnight ladder.
  static const List<BoxShadow> barGlow = JeebShadows.glowDot;

  /// Retained for API stability: the retired spread-ring form of [barGlow].
  static const double barGlowSpread = 3;

  /// [JeebStepperDoneInk.washed] — board `rgba(255,255,255,.35)`, R18 `tpl
  /// 1085-1087`.
  static const Color washedInk = Color(0x59FFFFFF);

  // ── Pulse ────────────────────────────────────────────────────────────────

  /// One breath of the active node's glow.
  static const Duration pulsePeriod = Duration(milliseconds: 900);

  /// How many breaths a pulse plays before resting. **Bounded on purpose** —
  /// see [pulseActive].
  static const int pulseCycles = 3;

  /// How far the glow's spread grows at the peak of a breath, on top of
  /// `JeebShadows.glowRest`'s resting spread.
  static const double pulseAmplitude = 4;

  /// 0-based index of the active step.
  ///
  /// Values outside `0 ..< stepCount` are legal and degrade sensibly: `-1`
  /// renders everything `pending`, `stepCount` renders everything `done`.
  final int currentIndex;

  /// Step labels, node form only. Rendered in `jeebText.label`.
  final List<String> labels;

  /// Per-step Maestro identifiers, node form only, index-aligned with [labels].
  final List<String> stepIdentifiers;

  /// Breathe the active node's glow (node form only).
  ///
  /// **Bounded, not endless.** The pulse plays [pulseCycles] breaths whenever a
  /// step becomes active (including on first build) and then rests at exactly
  /// `JeebShadows.glowRest`. An endless ticker in a shared kit widget would
  /// deadlock every `pumpAndSettle` in the app — eight live-tracking test files
  /// alone use it — so the motion is bounded and the widget settles.
  /// Reduce-motion (`MediaQuery.disableAnimationsOf`) skips it entirely.
  final bool pulseActive;

  /// Keys for the bar form's segments, index-aligned with `stepCount`.
  final List<Key>? segmentKeys;

  /// Bar form only: the fill a **passed** segment carries. The active segment
  /// is always accent + [barGlow]; the node form ignores this.
  final JeebStepperDoneInk doneInk;

  /// Optional Maestro id for the stepper as a whole, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  ///
  /// Screen 12 owns `tracking_stepper` at its own call site, so it passes
  /// nothing here and the kit adds no node at all — the per-step nodes stay
  /// exactly one level below the consumer's wrapper.
  final String? identifier;

  /// Accessibility label for the wrapper node, when one is added.
  final String? semanticLabel;

  final int _barCount;
  final bool _isBars;

  /// `rgba(215,59,0,.18)`, read off the Midnight token rather than restated.
  static final Color _glowInk = JeebShadows.glowRest.first.color;

  /// Resting blur / spread of `JeebShadows.glowRest` (30 / 0).
  static final double _glowBlur = JeebShadows.glowRest.first.blurRadius;
  static final double _glowSpread = JeebShadows.glowRest.first.spreadRadius;

  /// Number of steps in either form.
  int get stepCount => _isBars ? _barCount : labels.length;

  @override
  Widget build(BuildContext context) {
    // These live in `build`, not the initializer list: `List.length` is not a
    // constant expression, and an assert that reads it would make every
    // `const JeebStepper(...)` call site a compile error — which is exactly
    // what `prefer_const_constructors` pushes consumers to write.
    assert(
      _isBars || labels.length == stepIdentifiers.length,
      'JeebStepper: labels and stepIdentifiers must be index-aligned 1:1.',
    );
    assert(
      stepCount >= 2,
      'JeebStepper: a stepper needs at least two steps.',
    );
    assert(
      segmentKeys == null || segmentKeys!.length == stepCount,
      'JeebStepper.bars: segmentKeys must be index-aligned with stepCount.',
    );
    final Widget row = _isBars ? _buildBars(context) : _buildNodes(context);
    if (identifier == null && semanticLabel == null) {
      return row;
    }
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      // Both flags are mandatory: without them this node swallows the per-step
      // ids underneath it.
      container: true,
      explicitChildNodes: true,
      child: row,
    );
  }

  Widget _buildNodes(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (var index = 0; index < labels.length; index++) {
      if (index > 0) {
        // Connector i joins step i-1 to step i, so it is "passed" exactly when
        // step i-1 is done.
        children.add(Expanded(child: _Connector(passed: index <= currentIndex)));
      }
      children.add(
        Expanded(
          child: _StepNode(
            identifier: stepIdentifiers[index],
            label: labels[index],
            state: _stateAt(index),
            pulse: pulseActive,
          ),
        ),
      );
    }
    // Plain Row: no Stack, no Positioned — RTL mirrors for free. Start-aligned
    // so a two-line label never drags its node down.
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildBars(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = context.jeebRoles.accent;
    final JeebSemanticColors semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final Color done = switch (doneInk) {
      JeebStepperDoneInk.periwinkle => theme.colorScheme.secondary,
      JeebStepperDoneInk.accent => accent,
      JeebStepperDoneInk.washed => washedInk,
    };
    final List<Widget> children = <Widget>[];
    for (var index = 0; index < _barCount; index++) {
      if (index > 0) {
        children.add(const SizedBox(width: barGap));
      }
      final _JeebStepState state = _stateAt(index);
      // Board: passed = doneInk, active = orange + glow, pending = glass.
      final Color fill = switch (state) {
        _JeebStepState.done => done,
        _JeebStepState.active => accent,
        _JeebStepState.pending => semantics.glassFillPressed,
      };
      children.add(
        Expanded(
          child: DecoratedBox(
            key: segmentKeys?[index],
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(barRadius),
              boxShadow: state == _JeebStepState.active ? barGlow : null,
            ),
            child: const SizedBox(height: barHeight),
          ),
        ),
      );
    }
    // 18's labels and a11y stay feature-side; the bars are pure decoration.
    return ExcludeSemantics(child: Row(children: children));
  }

  _JeebStepState _stateAt(int index) {
    if (index < currentIndex) return _JeebStepState.done;
    if (index == currentIndex) return _JeebStepState.active;
    return _JeebStepState.pending;
  }
}

/// The 3px rule between two nodes.
class _Connector extends StatelessWidget {
  const _Connector({required this.passed});

  final bool passed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final JeebSemanticColors semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: JeebStepper.connectorTopInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: passed
              ? theme.colorScheme.secondary
              : semantics.glassFillPressed,
          borderRadius: BorderRadius.circular(JeebStepper.connectorRadius),
        ),
        child: const SizedBox(height: JeebStepper.connectorHeight),
      ),
    );
  }
}

/// One Ø26 node plus its label, and the owner of one frozen `tracking_step_*`
/// identifier.
class _StepNode extends StatefulWidget {
  const _StepNode({
    required this.identifier,
    required this.label,
    required this.state,
    required this.pulse,
  });

  final String identifier;
  final String label;
  final _JeebStepState state;
  final bool pulse;

  @override
  State<_StepNode> createState() => _StepNodeState();
}

class _StepNodeState extends State<_StepNode>
    with SingleTickerProviderStateMixin {
  static const double _restEpsilon = 0.01;

  late final AnimationController _controller;

  bool get _wantsPulse =>
      widget.pulse && widget.state == _JeebStepState.active;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: JeebStepper.pulsePeriod * JeebStepper.pulseCycles,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First pulse fires here rather than in initState because reduce-motion is
    // a MediaQuery read. `value == 0` means "has not played yet", so a later
    // dependency change (theme, text scale) does not replay it.
    if (_wantsPulse && _controller.value == 0 && !_controller.isAnimating) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(_StepNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool becameActive = widget.state == _JeebStepState.active &&
        oldWidget.state != _JeebStepState.active;
    if (_wantsPulse && becameActive) {
      _startPulse();
    } else if (!_wantsPulse) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startPulse() {
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce-motion: rest at the static ring the board actually draws.
      _controller.value = 0;
      return;
    }
    _controller.forward(from: 0);
  }

  /// `sin(phase·π).abs()` gives [JeebStepper.pulseCycles] symmetric breaths
  /// across the controller's 0→1 sweep and lands back at 0, so the resting
  /// shadow is byte-identical to `JeebShadows.glowRest`.
  List<BoxShadow> _glow() {
    final double phase = _controller.value * JeebStepper.pulseCycles;
    final double swell =
        JeebStepper.pulseAmplitude * math.sin(phase * math.pi).abs();
    // `sin(3π)` is 4.9e-16, not 0, so snap the trough back onto the token —
    // otherwise the resting shadow is a hair off the Wave 0 const forever.
    if (swell <= _restEpsilon) {
      return JeebShadows.glowRest;
    }
    return <BoxShadow>[
      BoxShadow(
        color: JeebStepper._glowInk,
        blurRadius: JeebStepper._glowBlur,
        spreadRadius: JeebStepper._glowSpread + swell,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final JeebRoles roles = context.jeebRoles;
    final JeebSemanticColors semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final TextStyle base = context.jeebText.label;

    final TextStyle labelStyle = switch (widget.state) {
      // Board 10.5 periwinkle — `jeebText.label` untouched but for ink.
      _JeebStepState.done => base.copyWith(color: scheme.secondary),
      // Board: the active label is the only orange one, 10.5/w800.
      _JeebStepState.active =>
        base.copyWith(color: roles.accent, fontWeight: FontWeight.w800),
      // Board: 10.5/w600 periwinkle.
      _JeebStepState.pending => base.copyWith(
          color: semantics.mutedText,
          fontWeight: FontWeight.w600,
        ),
    };

    return Semantics(
      identifier: widget.identifier,
      // `value` + `selected` are the frozen contract read by
      // `tracking_lifecycle_bodies_test.dart` d/e — do not "simplify" them into
      // a label.
      value: widget.label,
      selected: widget.state == _JeebStepState.active,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _node(scheme, roles, semantics),
          const SizedBox(height: JeebStepper.nodeLabelGap),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ],
      ),
    );
  }

  Widget _node(
    ColorScheme scheme,
    JeebRoles roles,
    JeebSemanticColors semantics,
  ) {
    switch (widget.state) {
      case _JeebStepState.done:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: JeebStepper.nodeSize,
            child: Icon(
              Icons.check,
              size: JeebStepper.checkSize,
              color: scheme.onSecondary,
            ),
          ),
        );
      case _JeebStepState.active:
        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => DecoratedBox(
            decoration: BoxDecoration(
              color: roles.accent,
              shape: BoxShape.circle,
              boxShadow: _glow(),
            ),
            child: child,
          ),
          child: SizedBox.square(
            dimension: JeebStepper.nodeSize,
            child: Center(
              child: SizedBox.square(
                dimension: JeebStepper.activeCoreSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: roles.onAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      case _JeebStepState.pending:
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: semantics.glassBorderStrong,
              width: JeebStepper.pendingRingWidth,
            ),
          ),
          child: const SizedBox.square(dimension: JeebStepper.nodeSize),
        );
    }
  }
}
