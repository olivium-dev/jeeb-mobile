import 'package:flutter/foundation.dart' show listEquals;

import 'package:flutter/material.dart';

/// The create capsule's rotating placeholder: types one localized example out,
/// holds it, deletes it and moves to the next, forever.
///
/// Reduce motion renders [restLabel] and schedules no frames at all — the same
/// contract `JMotionLoop` holds for the §2.6 primitives. The loop is otherwise
/// infinite, so a widget test that leaves animations ON must advance with
/// `tester.pump(<duration>)`; `pumpAndSettle` terminates only under reduce
/// motion.
///
/// The caller owns semantics: the visible run rotates, so this widget must be
/// mounted inside the create surface's `ExcludeSemantics` and the stable label
/// left on the node above it.
class ClientHomeTypedHint extends StatefulWidget {
  const ClientHomeTypedHint({
    super.key,
    required this.examples,
    required this.restLabel,
    required this.style,
    required this.caretColor,
  });

  /// Per-character type-in tempo.
  static const Duration typeStep = Duration(milliseconds: 70);

  /// Per-character delete tempo — faster than typing, as a backspace reads.
  static const Duration deleteStep = Duration(milliseconds: 40);

  /// How long a finished example is held before it is deleted.
  static const Duration hold = Duration(milliseconds: 1800);

  /// Empty beat between one example and the next.
  static const Duration gap = Duration(milliseconds: 350);

  /// The caret glyph. A text span rather than a painted bar: it rides the
  /// paragraph's own bidi run, so it lands on the reading-end edge under ar.
  static const String caretGlyph = '|';

  /// The examples cycled through, in order. Never empty.
  final List<String> examples;

  /// The still label under reduce motion — the stable CTA wording.
  final String restLabel;

  /// Type style for the run; the caret inherits it and overrides colour only.
  final TextStyle style;

  /// Caret colour — the accent, the one glyph in the capsule that spends it.
  final Color caretColor;

  @override
  State<ClientHomeTypedHint> createState() => _ClientHomeTypedHintState();
}

enum _HintPhase { typing, holding, deleting, gap }

class _ClientHomeTypedHintState extends State<ClientHomeTypedHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClientHomeTypedHint.hold,
  );

  int _index = 0;

  /// Null until the first dependency resolution, so an unrelated inherited
  /// change does not restart the cycle mid-example.
  bool? _appliedReduceMotion;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ClientHomeTypedHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.examples, widget.examples)) {
      _index = 0;
      _sync(force: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _current => widget.examples[_index % widget.examples.length];

  void _sync({bool force = false}) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!force && reduceMotion == _appliedReduceMotion) return;
    _appliedReduceMotion = reduceMotion;
    if (reduceMotion) {
      // Stop first: assigning `value` on a running controller would leave the
      // ticker scheduling frames forever against a pinned value.
      _controller
        ..stop()
        ..value = 0;
      return;
    }
    _restart();
  }

  void _restart() {
    _controller
      ..duration = _cycle(_current)
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _index = (_index + 1) % widget.examples.length);
    _restart();
  }

  /// One example's full round: type · hold · delete · gap.
  Duration _cycle(String text) =>
      ClientHomeTypedHint.typeStep * text.length +
      ClientHomeTypedHint.hold +
      ClientHomeTypedHint.deleteStep * text.length +
      ClientHomeTypedHint.gap;

  /// Where the cycle has reached, as a visible prefix length and a phase.
  (String, _HintPhase) _frame() {
    final String text = _current;
    final Duration cycle = _cycle(text);
    final int elapsed = (_controller.value * cycle.inMicroseconds).round();
    final int typing =
        ClientHomeTypedHint.typeStep.inMicroseconds * text.length;
    final int held = typing + ClientHomeTypedHint.hold.inMicroseconds;
    final int deleting =
        held + ClientHomeTypedHint.deleteStep.inMicroseconds * text.length;

    if (elapsed < typing) {
      final int chars =
          (elapsed ~/ ClientHomeTypedHint.typeStep.inMicroseconds) + 1;
      return (_prefix(text, chars), _HintPhase.typing);
    }
    if (elapsed < held) return (text, _HintPhase.holding);
    if (elapsed < deleting) {
      final int gone =
          ((elapsed - held) ~/ ClientHomeTypedHint.deleteStep.inMicroseconds) +
          1;
      return (_prefix(text, text.length - gone), _HintPhase.deleting);
    }
    return ('', _HintPhase.gap);
  }

  /// Clamped code-unit prefix. The examples are BMP-only in both locales, so a
  /// prefix never splits a glyph.
  String _prefix(String text, int chars) =>
      text.substring(0, chars.clamp(0, text.length));

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        widget.restLabel,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    // The one perpetual tick left on the pinned capsule; unbounded it repaints
    // the whole capsule every frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          final (String visible, _HintPhase phase) = _frame();
          final bool caret =
              phase == _HintPhase.typing || phase == _HintPhase.deleting;
          return Text.rich(
            TextSpan(
              text: visible,
              children: <InlineSpan>[
                if (caret)
                  TextSpan(
                    text: ClientHomeTypedHint.caretGlyph,
                    style: widget.style.copyWith(color: widget.caretColor),
                  ),
              ],
            ),
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
    );
  }
}
